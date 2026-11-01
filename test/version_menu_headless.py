"""Verify zmd's version menu on an isolated, non-interactive Windows desktop."""

from __future__ import annotations

import argparse
import ctypes as c
from ctypes import wintypes as w
import pathlib
import subprocess
import tempfile
import time


WM_CLOSE = 0x0010
WM_SYSCOMMAND = 0x0112
MF_BYPOSITION = 0x0400
ABOUT_SYSTEM_COMMAND = 0x1FE0
STILL_ACTIVE = 259
WAIT_OBJECT_0 = 0
WAIT_TIMEOUT = 258

user32 = c.WinDLL("user32", use_last_error=True)
kernel32 = c.WinDLL("kernel32", use_last_error=True)


class StartupInfo(c.Structure):
    _fields_ = [
        ("cb", w.DWORD),
        ("reserved", w.LPWSTR),
        ("desktop", w.LPWSTR),
        ("title", w.LPWSTR),
        ("x", w.DWORD),
        ("y", w.DWORD),
        ("xsize", w.DWORD),
        ("ysize", w.DWORD),
        ("xchars", w.DWORD),
        ("ychars", w.DWORD),
        ("fill", w.DWORD),
        ("flags", w.DWORD),
        ("show", w.WORD),
        ("reserved2", w.WORD),
        ("reservedptr", w.LPBYTE),
        ("stdin", w.HANDLE),
        ("stdout", w.HANDLE),
        ("stderr", w.HANDLE),
    ]


class ProcessInfo(c.Structure):
    _fields_ = [
        ("process", w.HANDLE),
        ("thread", w.HANDLE),
        ("pid", w.DWORD),
        ("tid", w.DWORD),
    ]


window_callback = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)

user32.CreateDesktopW.argtypes = [
    w.LPCWSTR,
    w.LPCWSTR,
    w.LPVOID,
    w.DWORD,
    w.DWORD,
    w.LPVOID,
]
user32.CreateDesktopW.restype = w.HANDLE
user32.CloseDesktop.argtypes = [w.HANDLE]
user32.EnumDesktopWindows.argtypes = [w.HANDLE, window_callback, w.LPARAM]
user32.EnumChildWindows.argtypes = [w.HWND, window_callback, w.LPARAM]
user32.GetWindowTextW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
user32.GetClassNameW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
user32.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
user32.IsWindowVisible.argtypes = [w.HWND]
user32.GetSystemMenu.argtypes = [w.HWND, w.BOOL]
user32.GetSystemMenu.restype = w.HMENU
user32.GetMenuItemCount.argtypes = [w.HMENU]
user32.GetMenuStringW.argtypes = [w.HMENU, w.UINT, w.LPWSTR, c.c_int, w.UINT]
user32.GetMenuItemID.argtypes = [w.HMENU, c.c_int]
user32.GetMenuItemID.restype = w.UINT
user32.PostMessageW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]

kernel32.CreateProcessW.argtypes = [
    w.LPCWSTR,
    w.LPWSTR,
    w.LPVOID,
    w.LPVOID,
    w.BOOL,
    w.DWORD,
    w.LPVOID,
    w.LPCWSTR,
    c.POINTER(StartupInfo),
    c.POINTER(ProcessInfo),
]
kernel32.GetExitCodeProcess.argtypes = [w.HANDLE, c.POINTER(w.DWORD)]
kernel32.TerminateProcess.argtypes = [w.HANDLE, w.UINT]
kernel32.WaitForSingleObject.argtypes = [w.HANDLE, w.DWORD]
kernel32.WaitForSingleObject.restype = w.DWORD
kernel32.CloseHandle.argtypes = [w.HANDLE]


def window_details(hwnd: int) -> dict[str, object]:
    title = c.create_unicode_buffer(512)
    class_name = c.create_unicode_buffer(256)
    user32.GetWindowTextW(hwnd, title, len(title))
    user32.GetClassNameW(hwnd, class_name, len(class_name))
    pid = w.DWORD()
    user32.GetWindowThreadProcessId(hwnd, c.byref(pid))
    return {
        "hwnd": hwnd,
        "title": title.value,
        "class": class_name.value,
        "pid": pid.value,
        "visible": bool(user32.IsWindowVisible(hwnd)),
    }


def desktop_windows(desktop: int) -> list[dict[str, object]]:
    found: list[dict[str, object]] = []

    @window_callback
    def collect(hwnd: int, _: int) -> bool:
        found.append(window_details(hwnd))
        return True

    c.set_last_error(0)
    if not user32.EnumDesktopWindows(desktop, collect, 0) and c.get_last_error():
        raise c.WinError(c.get_last_error())
    return found


def child_texts(hwnd: int) -> list[str]:
    texts: list[str] = []

    @window_callback
    def collect(child: int, _: int) -> bool:
        text = window_details(child)["title"]
        if text:
            texts.append(str(text))
        return True

    user32.EnumChildWindows(hwnd, collect, 0)
    return texts


def process_alive(process: int) -> bool:
    code = w.DWORD()
    if not kernel32.GetExitCodeProcess(process, c.byref(code)):
        raise c.WinError(c.get_last_error())
    return code.value == STILL_ACTIVE


def stop_process(process: int, timeout_ms: int = 5000) -> None:
    if process_alive(process) and not kernel32.TerminateProcess(process, 1):
        raise c.WinError(c.get_last_error())
    wait_result = kernel32.WaitForSingleObject(process, timeout_ms)
    if wait_result == WAIT_OBJECT_0:
        return
    if wait_result == WAIT_TIMEOUT:
        raise TimeoutError("timed out waiting for zmd to exit")
    raise c.WinError(c.get_last_error())


def wait_for_window(desktop: int, predicate, timeout: float):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        match = next((item for item in desktop_windows(desktop) if predicate(item)), None)
        if match is not None:
            return match
        time.sleep(0.05)
    return None


def menu_entries(hwnd: int) -> list[tuple[int, str]]:
    menu = user32.GetSystemMenu(hwnd, False)
    if not menu:
        raise c.WinError(c.get_last_error())
    count = user32.GetMenuItemCount(menu)
    if count < 0:
        raise c.WinError(c.get_last_error())
    entries: list[tuple[int, str]] = []
    for position in range(count):
        label = c.create_unicode_buffer(256)
        user32.GetMenuStringW(menu, position, label, len(label), MF_BYPOSITION)
        entries.append((user32.GetMenuItemID(menu, position), label.value))
    return entries


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("exe", type=pathlib.Path)
    parser.add_argument("expected_version")
    args = parser.parse_args()
    executable = args.exe.resolve(strict=True)

    with tempfile.TemporaryDirectory(prefix="zmd-version-menu-") as temp_dir:
        root = pathlib.Path(temp_dir)
        document = root / "version-menu.md"
        document.write_text("# Version menu headless check\n", encoding="utf-8")
        desktop_name = f"zmd-version-menu-{time.time_ns()}"
        desktop = user32.CreateDesktopW(desktop_name, None, None, 0, 0x01FF, None)
        if not desktop:
            raise c.WinError(c.get_last_error())

        startup = StartupInfo()
        startup.cb = c.sizeof(startup)
        startup.desktop = desktop_name
        process = ProcessInfo()
        command = c.create_unicode_buffer(
            subprocess.list2cmdline([str(executable), str(document)])
        )
        try:
            if not kernel32.CreateProcessW(
                str(executable),
                command,
                None,
                None,
                False,
                0,
                None,
                str(root),
                c.byref(startup),
                c.byref(process),
            ):
                raise c.WinError(c.get_last_error())

            try:
                viewer = wait_for_window(
                    desktop,
                    lambda item: item["pid"] == process.pid
                    and item["class"] == "zmd_window",
                    15,
                )
                if viewer is None:
                    raise RuntimeError(f"zmd window did not open: {desktop_windows(desktop)}")

                entries = menu_entries(int(viewer["hwnd"]))
                about_entry = (ABOUT_SYSTEM_COMMAND, "About zmd...")
                if about_entry not in entries:
                    raise RuntimeError(f"missing {about_entry!r} in system menu: {entries!r}")

                if not user32.PostMessageW(
                    int(viewer["hwnd"]), WM_SYSCOMMAND, ABOUT_SYSTEM_COMMAND, 0
                ):
                    raise c.WinError(c.get_last_error())
                dialog = wait_for_window(
                    desktop,
                    lambda item: item["pid"] == process.pid
                    and item["class"] == "#32770"
                    and item["title"] == "About zmd",
                    10,
                )
                if dialog is None:
                    raise RuntimeError("About zmd dialog did not open")

                expected_text = f"zmd {args.expected_version}"
                texts = child_texts(int(dialog["hwnd"]))
                if expected_text not in texts:
                    raise RuntimeError(
                        f"expected {expected_text!r} in About dialog children: {texts!r}"
                    )
                print(
                    f"SUCCESS: system menu opened About zmd with {expected_text!r}",
                    flush=True,
                )

                user32.PostMessageW(int(dialog["hwnd"]), WM_CLOSE, 0, 0)
                user32.PostMessageW(int(viewer["hwnd"]), WM_CLOSE, 0, 0)
                deadline = time.monotonic() + 5
                while process_alive(process.process) and time.monotonic() < deadline:
                    time.sleep(0.05)
            finally:
                try:
                    if process.process:
                        stop_process(process.process)
                finally:
                    if process.thread:
                        kernel32.CloseHandle(process.thread)
                    if process.process:
                        kernel32.CloseHandle(process.process)
        finally:
            user32.CloseDesktop(desktop)


if __name__ == "__main__":
    main()
