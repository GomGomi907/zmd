const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const windows_console = b.option(bool, "windows-console", "Build Windows as a console app for CLI smoke tests") orelse false;
    const windows_gui = target.result.os.tag == .windows and !windows_console;

    const options = b.addOptions();
    options.addOption(bool, "windows_gui", windows_gui);

    const zmd_mod = b.addModule("zmd", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zmd",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zmd", .module = zmd_mod },
            },
        }),
    });
    exe.root_module.addOptions("build_options", options);
    if (windows_gui) {
        exe.subsystem = .windows;
    }
    if (target.result.os.tag == .windows) {
        exe.root_module.linkSystemLibrary("user32", .{});
        exe.root_module.linkSystemLibrary("gdi32", .{});
        exe.root_module.linkSystemLibrary("advapi32", .{});
        exe.root_module.linkSystemLibrary("shell32", .{});
        exe.root_module.addWin32ResourceFile(.{
            .file = b.path("assets/windows/zmd.rc"),
            .include_paths = &.{b.path("assets/windows")},
        });
    }

    const install_exe = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&install_exe.step);

    var setup_install_step: ?*std.Build.Step = null;
    if (target.result.os.tag == .windows) {
        const setup = b.addExecutable(.{
            .name = "zmd-setup",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zmd", .module = zmd_mod },
                },
            }),
        });
        setup.root_module.addOptions("build_options", options);
        setup.subsystem = .windows;
        setup.root_module.linkSystemLibrary("user32", .{});
        setup.root_module.linkSystemLibrary("gdi32", .{});
        setup.root_module.linkSystemLibrary("advapi32", .{});
        setup.root_module.linkSystemLibrary("shell32", .{});
        setup.root_module.addWin32ResourceFile(.{
            .file = b.path("assets/windows/zmd.rc"),
            .include_paths = &.{b.path("assets/windows")},
        });
        const install_setup = b.addInstallArtifact(setup, .{});
        b.getInstallStep().dependOn(&install_setup.step);
        setup_install_step = &install_setup.step;
    }

    const run_step = b.step("run", "Run zmd");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    run_step.dependOn(&run_cmd.step);

    const mod_tests = b.addTest(.{ .root_module = zmd_mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const installer_step = b.step("installer", "Build the Windows installer executable");
    if (setup_install_step) |install_step| {
        installer_step.dependOn(install_step);
    } else {
        installer_step.dependOn(b.getInstallStep());
    }
}
