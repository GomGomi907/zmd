import argparse
import ctypes as c
from ctypes import wintypes as w
import pathlib
import shutil
import subprocess
import tempfile
import time


user32 = c.WinDLL("user32", use_last_error=True)
kernel32 = c.WinDLL("kernel32", use_last_error=True)
DESKTOP_ALL_ACCESS = 0x01FF
WAIT_OBJECT_0 = 0
WAIT_TIMEOUT = 258
STILL_ACTIVE = 259


class StartupInfo(c.Structure):
    _fields_ = [
        ("cb", w.DWORD), ("reserved", w.LPWSTR), ("desktop", w.LPWSTR),
        ("title", w.LPWSTR), ("x", w.DWORD), ("y", w.DWORD),
        ("x_size", w.DWORD), ("y_size", w.DWORD),
        ("x_count_chars", w.DWORD), ("y_count_chars", w.DWORD),
        ("fill_attribute", w.DWORD), ("flags", w.DWORD),
        ("show_window", w.WORD), ("reserved2_size", w.WORD),
        ("reserved2", c.POINTER(c.c_ubyte)), ("stdin", w.HANDLE),
        ("stdout", w.HANDLE), ("stderr", w.HANDLE),
    ]


class ProcessInfo(c.Structure):
    _fields_ = [
        ("process", w.HANDLE), ("thread", w.HANDLE),
        ("process_id", w.DWORD), ("thread_id", w.DWORD),
    ]


user32.CreateDesktopW.argtypes = [w.LPCWSTR, w.LPCWSTR, c.c_void_p, w.DWORD, w.DWORD, c.c_void_p]
user32.CreateDesktopW.restype = w.HANDLE
user32.CloseDesktop.argtypes = [w.HANDLE]
user32.CloseDesktop.restype = w.BOOL
user32.EnumDesktopWindows.argtypes = [w.HANDLE, c.c_void_p, w.LPARAM]
user32.EnumDesktopWindows.restype = w.BOOL
user32.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
user32.GetWindowThreadProcessId.restype = w.DWORD
user32.GetClassNameW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
user32.GetClassNameW.restype = c.c_int
kernel32.CreateProcessW.argtypes = [
    w.LPCWSTR, w.LPWSTR, c.c_void_p, c.c_void_p, w.BOOL, w.DWORD,
    c.c_void_p, w.LPCWSTR, c.POINTER(StartupInfo), c.POINTER(ProcessInfo),
]
kernel32.CreateProcessW.restype = w.BOOL
kernel32.CloseHandle.argtypes = [w.HANDLE]
kernel32.CloseHandle.restype = w.BOOL
kernel32.WaitForSingleObject.argtypes = [w.HANDLE, w.DWORD]
kernel32.WaitForSingleObject.restype = w.DWORD
kernel32.GetExitCodeProcess.argtypes = [w.HANDLE, c.POINTER(w.DWORD)]
kernel32.GetExitCodeProcess.restype = w.BOOL
kernel32.TerminateProcess.argtypes = [w.HANDLE, w.UINT]
kernel32.TerminateProcess.restype = w.BOOL


class Process:
    def __init__(self, info: ProcessInfo):
        self.handle = info.process
        self.pid = int(info.process_id)
        kernel32.CloseHandle(info.thread)

    def wait(self, milliseconds: int) -> bool:
        return kernel32.WaitForSingleObject(self.handle, milliseconds) == WAIT_OBJECT_0

    def exit_code(self) -> int:
        code = w.DWORD()
        if not kernel32.GetExitCodeProcess(self.handle, c.byref(code)):
            raise c.WinError(c.get_last_error())
        return int(code.value)

    def terminate(self) -> None:
        if self.exit_code() == STILL_ACTIVE:
            kernel32.TerminateProcess(self.handle, 99)
            self.wait(5000)

    def close(self) -> None:
        if self.handle:
            kernel32.CloseHandle(self.handle)
            self.handle = None


def spawn(executable: pathlib.Path, args: list[str], desktop_name: str, cwd: pathlib.Path) -> Process:
    startup = StartupInfo()
    startup.cb = c.sizeof(startup)
    startup.desktop = desktop_name
    info = ProcessInfo()
    command = c.create_unicode_buffer(subprocess.list2cmdline([str(executable), *args]))
    if not kernel32.CreateProcessW(
        str(executable), command, None, None, False, 0, None, str(cwd),
        c.byref(startup), c.byref(info),
    ):
        raise c.WinError(c.get_last_error())
    return Process(info)


def zmd_window_pids(desktop: w.HANDLE) -> set[int]:
    found: set[int] = set()
    callback_type = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)

    def inspect(hwnd: w.HWND, _param: int) -> bool:
        name = c.create_unicode_buffer(64)
        if user32.GetClassNameW(hwnd, name, len(name)) and name.value == "zmd_window":
            pid = w.DWORD()
            user32.GetWindowThreadProcessId(hwnd, c.byref(pid))
            found.add(int(pid.value))
        return True

    callback = callback_type(inspect)
    if not user32.EnumDesktopWindows(desktop, callback, 0):
        error = c.get_last_error()
        if error:
            raise c.WinError(error)
    return found


def wait_for_windows(desktop: w.HANDLE, expected: set[int], timeout: float = 10.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if expected.issubset(zmd_window_pids(desktop)):
            return
        time.sleep(0.05)
    raise RuntimeError(f"windows did not appear: expected={expected}, found={zmd_window_pids(desktop)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("fixture", type=pathlib.Path)
    args = parser.parse_args()
    fixture = args.fixture.resolve(strict=True)
    desktop_name = f"zmd-uninstall-windows-{time.time_ns()}"
    desktop = user32.CreateDesktopW(desktop_name, None, None, 0, DESKTOP_ALL_ACCESS, None)
    if not desktop:
        raise c.WinError(c.get_last_error())

    processes: list[Process] = []
    root: pathlib.Path | None = None
    try:
        root = pathlib.Path(tempfile.mkdtemp(prefix="zmd-uninstall-windows-"))
        installed = root / "한글 사용자" / "Programs" / "zmd" / "zmd.exe"
        portable = root / "portable" / "zmd.exe"
        installed.parent.mkdir(parents=True)
        portable.parent.mkdir(parents=True)
        shutil.copy2(fixture, installed)
        shutil.copy2(fixture, portable)

        empty_closer = spawn(fixture, ["close", str(installed), "5000"], desktop_name, root)
        processes.append(empty_closer)
        if not empty_closer.wait(10000) or empty_closer.exit_code() != 0:
            raise RuntimeError(f"empty desktop close failed: exit={empty_closer.exit_code()}")

        first = spawn(installed, ["cooperative"], desktop_name, root)
        second = spawn(installed, ["cooperative"], desktop_name, root)
        portable_process = spawn(portable, ["cooperative"], desktop_name, root)
        processes.extend([first, second, portable_process])
        wait_for_windows(desktop, {first.pid, second.pid, portable_process.pid})

        closer = spawn(fixture, ["close", str(installed), "5000"], desktop_name, root)
        processes.append(closer)
        if not closer.wait(10000) or closer.exit_code() != 0:
            raise RuntimeError(f"cooperative close failed: exit={closer.exit_code()}")
        if not first.wait(2000) or not second.wait(2000):
            raise RuntimeError("installed cooperative processes remained open")
        if portable_process.wait(200):
            raise RuntimeError("portable process was closed with installed windows")

        portable_closer = spawn(fixture, ["close", str(portable), "5000"], desktop_name, root)
        processes.append(portable_closer)
        if not portable_closer.wait(10000) or portable_closer.exit_code() != 0:
            raise RuntimeError("portable fixture cleanup failed")

        stubborn = spawn(installed, ["noncooperative"], desktop_name, root)
        processes.append(stubborn)
        wait_for_windows(desktop, {stubborn.pid})
        failed_closer = spawn(fixture, ["close", str(installed), "400"], desktop_name, root)
        processes.append(failed_closer)
        if not failed_closer.wait(5000):
            raise RuntimeError("noncooperative close did not return")
        if failed_closer.exit_code() == 0:
            raise RuntimeError("noncooperative close unexpectedly succeeded")
        if stubborn.wait(200):
            raise RuntimeError("noncooperative target was forcibly terminated")

        print("Empty desktop succeeded; cooperative close targeted two installed processes, preserved portable and nonresponsive processes, and returned failure without force.")
    finally:
        for process in processes:
            process.terminate()
        for process in processes:
            process.close()
        user32.CloseDesktop(desktop)
        if root is not None and root.exists():
            shutil.rmtree(root)


if __name__ == "__main__":
    main()
