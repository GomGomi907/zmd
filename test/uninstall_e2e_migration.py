"""Exercise legacy byte-only update adoption after a real document window is visible."""

from __future__ import annotations

import argparse
import ctypes as c
import contextlib
import os
import pathlib
import shutil
import subprocess
import tempfile
import time
import uuid
import winreg

import version_menu_headless as desktop_api


UNINSTALL_PATH = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\zmd"
WAIT_OBJECT_0 = 0
WAIT_TIMEOUT = 258


class NativeProcess:
    def __init__(self, info: desktop_api.ProcessInfo) -> None:
        self.handle = info.process
        self.pid = int(info.pid)

    def wait(self, timeout: float) -> int:
        result = desktop_api.kernel32.WaitForSingleObject(self.handle, int(timeout * 1000))
        if result == WAIT_TIMEOUT:
            raise subprocess.TimeoutExpired(str(self.pid), timeout)
        if result != WAIT_OBJECT_0:
            raise c.WinError(c.get_last_error())
        exit_code = desktop_api.w.DWORD()
        if not desktop_api.kernel32.GetExitCodeProcess(self.handle, c.byref(exit_code)):
            raise c.WinError(c.get_last_error())
        return int(exit_code.value)

    def running(self) -> bool:
        return desktop_api.process_alive(self.handle)

    def terminate(self) -> None:
        desktop_api.stop_process(self.handle)

    def close(self) -> None:
        desktop_api.kernel32.CloseHandle(self.handle)


@contextlib.contextmanager
def inherited_test_environment(environment: dict[str, str]):
    names = ("LOCALAPPDATA", "TEMP", "ZMD_TEST_REGISTRY_PREFIX")
    previous = {name: os.environ.get(name) for name in names}
    try:
        for name in names:
            os.environ[name] = environment[name]
        yield
    finally:
        for name, value in previous.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


def delete_registry_tree(root: int, path: str) -> None:
    try:
        with winreg.OpenKey(root, path, 0, winreg.KEY_READ | winreg.KEY_WRITE) as key:
            children: list[str] = []
            index = 0
            while True:
                try:
                    children.append(winreg.EnumKey(key, index))
                    index += 1
                except OSError:
                    break
        for child in children:
            delete_registry_tree(root, path + "\\" + child)
        winreg.DeleteKey(root, path)
    except FileNotFoundError:
        return


def query_registration(prefix: str) -> tuple[str, str] | None:
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, prefix + "\\" + UNINSTALL_PATH) as key:
            version = str(winreg.QueryValueEx(key, "DisplayVersion")[0])
            command = str(winreg.QueryValueEx(key, "UninstallString")[0])
            return version, command
    except FileNotFoundError:
        return None


def test_environment(local_app_data: pathlib.Path, registry_prefix: str) -> dict[str, str]:
    environment = os.environ.copy()
    environment["LOCALAPPDATA"] = str(local_app_data)
    environment["TEMP"] = str(local_app_data / "Temp")
    environment["ZMD_TEST_REGISTRY_PREFIX"] = registry_prefix
    pathlib.Path(environment["TEMP"]).mkdir(parents=True, exist_ok=True)
    return environment


def launch_document(
    executable: pathlib.Path,
    document: pathlib.Path,
    environment: dict[str, str],
    desktop: int,
    desktop_name: str,
) -> tuple[NativeProcess, dict[str, object]]:
    process = launch_native(executable, [str(document)], environment, document.parent, desktop_name)
    viewer = desktop_api.wait_for_window(
        desktop,
        lambda item: item["pid"] == process.pid and item["class"] == "zmd_window" and item["visible"],
        15,
    )
    if viewer is None:
        exit_detail = "still running"
        if process.running():
            process.terminate()
        else:
            exit_detail = f"exit code {process.wait(0)}"
        process.close()
        raise RuntimeError(
            f"zmd document window did not become visible ({exit_detail}): {desktop_api.desktop_windows(desktop)}"
        )
    return process, viewer


def launch_native(
    executable: pathlib.Path,
    arguments: list[str],
    environment: dict[str, str],
    current_directory: pathlib.Path,
    desktop_name: str,
) -> NativeProcess:
    startup = desktop_api.StartupInfo()
    startup.cb = c.sizeof(startup)
    startup.desktop = desktop_name
    info = desktop_api.ProcessInfo()
    command = c.create_unicode_buffer(subprocess.list2cmdline([str(executable), *arguments]))
    with inherited_test_environment(environment):
        if not desktop_api.kernel32.CreateProcessW(
            str(executable), command, None, None, False, 0, None,
            str(current_directory), c.byref(startup), c.byref(info),
        ):
            raise c.WinError(c.get_last_error())
    desktop_api.kernel32.CloseHandle(info.thread)
    return NativeProcess(info)


def close_document(process: NativeProcess, viewer: dict[str, object]) -> None:
    desktop_api.user32.PostMessageW(int(viewer["hwnd"]), desktop_api.WM_CLOSE, 0, 0)
    try:
        process.wait(timeout=8)
    except subprocess.TimeoutExpired:
        process.terminate()
        raise


def wait_for_absent(path: pathlib.Path, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not path.exists():
            return True
        time.sleep(0.05)
    return not path.exists()


def remove_tree_when_unlocked(path: pathlib.Path, timeout: float = 5.0) -> None:
    deadline = time.monotonic() + timeout
    while True:
        try:
            shutil.rmtree(path)
            return
        except FileNotFoundError:
            return
        except PermissionError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.05)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=pathlib.Path)
    parser.add_argument("replace_probe", type=pathlib.Path)
    parser.add_argument("expected_version")
    parser.add_argument("registry_prefix")
    args = parser.parse_args()
    candidate = args.candidate.resolve(strict=True)
    replace_probe = args.replace_probe.resolve(strict=True)
    if not args.registry_prefix.startswith(r"Software\zmd-uninstall-e2e-"):
        raise RuntimeError("refusing to use a non-test registry prefix")
    actual_prefix = args.registry_prefix + "-" + uuid.uuid4().hex

    desktop_name = f"zmd-uninstall-migration-{time.time_ns()}"
    desktop = desktop_api.user32.CreateDesktopW(desktop_name, None, None, 0, 0x01FF, None)
    if not desktop:
        raise OSError("could not create isolated desktop")
    processes: list[NativeProcess] = []

    try:
        temp_dir = tempfile.mkdtemp(prefix="zmd-uninstall-migration-")
        try:
            root = pathlib.Path(temp_dir)
            local_app_data = root / "한글 사용자 with space"
            installed = local_app_data / "Programs" / "zmd" / "zmd.exe"
            installed.parent.mkdir(parents=True)
            environment = test_environment(local_app_data, actual_prefix)
            installed.write_bytes(b"legacy zmd bytes before byte-only update")
            subprocess.run([str(replace_probe), str(candidate), str(installed)], check=True)
            if installed.read_bytes() != candidate.read_bytes():
                raise RuntimeError("legacy byte-only replacement did not install the candidate")
            document = root / "migration.md"
            second_document = root / "두 번째 문서.md"
            document.write_text("# Migration registration check\n", encoding="utf-8")
            second_document.write_text("# Preserve this second document\n", encoding="utf-8")

            process, viewer = launch_document(installed, document, environment, desktop, desktop_name)
            processes.append(process)
            second_process, _ = launch_document(installed, second_document, environment, desktop, desktop_name)
            processes.append(second_process)
            deadline = time.monotonic() + 10
            registration = None
            while time.monotonic() < deadline:
                registration = query_registration(actual_prefix)
                if registration is not None:
                    break
                time.sleep(0.05)
            if registration is None:
                raise RuntimeError("installed app was not registered after the document became visible")
            expected_command = f'"{installed}" --uninstall'
            if registration != (args.expected_version, expected_command):
                raise RuntimeError(f"unexpected installed registration: {registration!r}")

            uninstall_launcher = launch_native(
                installed, ["--uninstall"], environment, installed.parent, desktop_name
            )
            processes.append(uninstall_launcher)
            uninstall_exit = uninstall_launcher.wait(timeout=10)
            if uninstall_exit != 0:
                raise RuntimeError(f"uninstall launcher failed with exit code {uninstall_exit}")
            for viewer_process in (process, second_process):
                viewer_process.wait(timeout=20)
            if not wait_for_absent(installed, 10):
                raise RuntimeError("installed executable remained after successful uninstall")
            if query_registration(actual_prefix) is not None:
                raise RuntimeError("uninstall registration remained after successful uninstall")
            if document.read_text(encoding="utf-8") != "# Migration registration check\n":
                raise RuntimeError("first user document changed during uninstall")
            if second_document.read_text(encoding="utf-8") != "# Preserve this second document\n":
                raise RuntimeError("second user document changed during uninstall")

            portable = root / "portable zmd.exe"
            shutil.copy2(candidate, portable)
            process, viewer = launch_document(portable, document, environment, desktop, desktop_name)
            processes.append(process)
            time.sleep(1.0)
            if query_registration(actual_prefix) is not None:
                raise RuntimeError("portable execution created an installed-app registration")
            close_document(process, viewer)

            setup_executable = root / "zmd-setup.exe"
            shutil.copy2(candidate, setup_executable)
            setup_result = subprocess.run(
                [str(setup_executable), "--quiet"], env=environment, timeout=15, check=False
            )
            if setup_result.returncode != 0:
                raise RuntimeError(f"setup failed with exit code {setup_result.returncode}")
            if installed.read_bytes() != candidate.read_bytes():
                raise RuntimeError("setup did not install the candidate at the canonical path")
            setup_registration = query_registration(actual_prefix)
            if setup_registration != (args.expected_version, expected_command):
                raise RuntimeError(f"unexpected setup registration: {setup_registration!r}")
            setup_uninstall = launch_native(
                installed, ["--uninstall"], environment, installed.parent, desktop_name
            )
            processes.append(setup_uninstall)
            setup_uninstall_exit = setup_uninstall.wait(timeout=10)
            if setup_uninstall_exit != 0:
                raise RuntimeError(f"setup uninstall launcher failed with exit code {setup_uninstall_exit}")
            if not wait_for_absent(installed, 10):
                dialog_details: list[tuple[str, list[str]]] = []
                for item in desktop_api.desktop_windows(desktop):
                    if item["class"] == "#32770":
                        dialog_details.append(
                            (str(item["title"]), desktop_api.child_texts(int(item["hwnd"])))
                        )
                        desktop_api.user32.PostMessageW(
                            int(item["hwnd"]), desktop_api.WM_CLOSE, 0, 0
                        )
                time.sleep(1.0)
                raise RuntimeError(
                    f"setup-installed executable remained after uninstall; dialogs={dialog_details!r}"
                )
            if query_registration(actual_prefix) is not None:
                raise RuntimeError("setup registration remained after uninstall")
            print(
                "Legacy byte-only update was adopted after display; two installed windows closed during "
                "uninstall; documents were preserved; portable execution stayed unregistered; normal setup "
                "and removal succeeded."
            )
        finally:
            for process in processes:
                if process.running():
                    process.terminate()
                process.close()
            processes.clear()
            remove_tree_when_unlocked(pathlib.Path(temp_dir))
    finally:
        delete_registry_tree(winreg.HKEY_CURRENT_USER, actual_prefix)
        desktop_api.user32.CloseDesktop(desktop)


if __name__ == "__main__":
    main()
