extern "kernel32" fn Sleep(milliseconds: u32) callconv(.winapi) void;

pub fn main() void {
    Sleep(120_000);
}
