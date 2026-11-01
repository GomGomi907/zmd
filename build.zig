const std = @import("std");

const app_version = "0.3.3";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const windows_console = b.option(bool, "windows-console", "Build Windows as a console app for CLI smoke tests") orelse false;
    const windows_gui = target.result.os.tag == .windows and !windows_console;

    const executable_options = b.addOptions();
    executable_options.addOption(bool, "windows_gui", windows_gui);
    executable_options.addOption(?[]const u8, "test_registry_prefix", null);

    const library_options = b.addOptions();
    library_options.addOption([]const u8, "version", app_version);

    const semantic_version = std.SemanticVersion.parse(app_version) catch @panic("invalid app version");
    const generated_resources = b.addWriteFiles();
    _ = generated_resources.add("zmd_version.h", b.fmt(
        \\#define ZMD_FILE_VERSION {d},{d},{d},0
        \\#define ZMD_FILE_VERSION_STRING "{s}"
        \\#define ZMD_PRODUCT_VERSION {d},{d},{d},0
        \\#define ZMD_PRODUCT_VERSION_STRING "{s}"
        \\
    , .{
        semantic_version.major,
        semantic_version.minor,
        semantic_version.patch,
        app_version,
        semantic_version.major,
        semantic_version.minor,
        semantic_version.patch,
        app_version,
    }));

    const zmd_mod = b.addModule("zmd", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zmd_mod.addOptions("build_options", library_options);

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
    exe.root_module.addOptions("build_options", executable_options);
    if (windows_gui) {
        exe.subsystem = .windows;
    }
    if (target.result.os.tag == .windows) {
        exe.root_module.linkSystemLibrary("user32", .{});
        exe.root_module.linkSystemLibrary("gdi32", .{});
        exe.root_module.linkSystemLibrary("dwmapi", .{});
        exe.root_module.linkSystemLibrary("advapi32", .{});
        exe.root_module.linkSystemLibrary("shell32", .{});
        exe.root_module.linkSystemLibrary("winhttp", .{});
        exe.root_module.linkSystemLibrary("version", .{});
        exe.root_module.addWin32ResourceFile(.{
            .file = b.path("assets/windows/zmd.rc"),
            .include_paths = &.{ b.path("assets/windows"), generated_resources.getDirectory() },
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
        setup.root_module.addOptions("build_options", executable_options);
        setup.subsystem = .windows;
        setup.root_module.linkSystemLibrary("user32", .{});
        setup.root_module.linkSystemLibrary("gdi32", .{});
        setup.root_module.linkSystemLibrary("dwmapi", .{});
        setup.root_module.linkSystemLibrary("advapi32", .{});
        setup.root_module.linkSystemLibrary("shell32", .{});
        setup.root_module.linkSystemLibrary("winhttp", .{});
        setup.root_module.linkSystemLibrary("version", .{});
        setup.root_module.addWin32ResourceFile(.{
            .file = b.path("assets/windows/zmd.rc"),
            .include_paths = &.{ b.path("assets/windows"), generated_resources.getDirectory() },
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

    const image_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/image.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zmd", .module = zmd_mod },
            },
        }),
    });
    const run_image_tests = b.addRunArtifact(image_tests);

    var run_ui_tests: ?*std.Build.Step.Run = null;
    var run_updater_tests: ?*std.Build.Step.Run = null;
    var run_updater_win32_tests: ?*std.Build.Step.Run = null;
    var run_uninstall_e2e_tests: ?*std.Build.Step.Run = null;
    var run_uninstall_process_test: ?*std.Build.Step.Run = null;
    var run_uninstall_windows_tests: ?*std.Build.Step = null;
    if (target.result.os.tag == .windows) {
        const ui_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/ui_win32.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zmd", .module = zmd_mod },
                },
            }),
        });
        ui_tests.root_module.addOptions("build_options", executable_options);
        ui_tests.root_module.linkSystemLibrary("user32", .{});
        ui_tests.root_module.linkSystemLibrary("gdi32", .{});
        ui_tests.root_module.linkSystemLibrary("dwmapi", .{});
        ui_tests.root_module.linkSystemLibrary("advapi32", .{});
        ui_tests.root_module.linkSystemLibrary("winhttp", .{});
        ui_tests.root_module.linkSystemLibrary("shell32", .{});
        ui_tests.root_module.linkSystemLibrary("version", .{});
        run_ui_tests = b.addRunArtifact(ui_tests);
        const updater_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/updater.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        run_updater_tests = b.addRunArtifact(updater_tests);
        const updater_win32_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/updater_win32.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        updater_win32_tests.root_module.linkSystemLibrary("winhttp", .{});
        updater_win32_tests.root_module.linkSystemLibrary("advapi32", .{});
        run_updater_win32_tests = b.addRunArtifact(updater_win32_tests);
        const setup_test_module = b.createModule(.{
            .root_source_file = b.path("src/setup.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zmd", .module = zmd_mod }},
        });
        setup_test_module.addOptions("build_options", executable_options);
        const uninstall_e2e_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("test/uninstall_e2e.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "setup", .module = setup_test_module },
                    .{ .name = "zmd", .module = zmd_mod },
                },
            }),
        });
        uninstall_e2e_tests.root_module.linkSystemLibrary("user32", .{});
        uninstall_e2e_tests.root_module.linkSystemLibrary("advapi32", .{});
        uninstall_e2e_tests.root_module.linkSystemLibrary("shell32", .{});
        uninstall_e2e_tests.root_module.linkSystemLibrary("winhttp", .{});
        uninstall_e2e_tests.root_module.linkSystemLibrary("version", .{});
        run_uninstall_e2e_tests = b.addRunArtifact(uninstall_e2e_tests);
        const uninstall_fixture = b.addExecutable(.{
            .name = "zmd-uninstall-e2e-fixture",
            .root_module = b.createModule(.{
                .root_source_file = b.path("test/uninstall_e2e_fixture.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "setup", .module = setup_test_module }},
            }),
        });
        uninstall_fixture.root_module.linkSystemLibrary("user32", .{});
        uninstall_fixture.root_module.linkSystemLibrary("advapi32", .{});
        uninstall_fixture.root_module.linkSystemLibrary("shell32", .{});
        uninstall_fixture.root_module.linkSystemLibrary("winhttp", .{});
        uninstall_fixture.root_module.linkSystemLibrary("version", .{});
        const hold_fixture = b.addExecutable(.{
            .name = "zmd-uninstall-hold",
            .root_module = b.createModule(.{
                .root_source_file = b.path("test/install_hold_target.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        const uninstall_process = b.addSystemCommand(&.{ "pwsh", "-NoProfile", "-File" });
        uninstall_process.addFileArg(b.path("test/uninstall_e2e_process.ps1"));
        uninstall_process.addArg("-FixtureExe");
        uninstall_process.addArtifactArg(uninstall_fixture);
        uninstall_process.addArg("-HoldExe");
        uninstall_process.addArtifactArg(hold_fixture);
        run_uninstall_process_test = uninstall_process;

        const migration_prefix = "Software\\zmd-uninstall-e2e-migration";
        const migration_options = b.addOptions();
        migration_options.addOption(bool, "windows_gui", true);
        migration_options.addOption(?[]const u8, "test_registry_prefix", migration_prefix);
        const migration_candidate = b.addExecutable(.{
            .name = "zmd-uninstall-migration-candidate",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "zmd", .module = zmd_mod }},
            }),
        });
        migration_candidate.root_module.addOptions("build_options", migration_options);
        migration_candidate.subsystem = .windows;
        migration_candidate.root_module.linkSystemLibrary("user32", .{});
        migration_candidate.root_module.linkSystemLibrary("gdi32", .{});
        migration_candidate.root_module.linkSystemLibrary("dwmapi", .{});
        migration_candidate.root_module.linkSystemLibrary("advapi32", .{});
        migration_candidate.root_module.linkSystemLibrary("shell32", .{});
        migration_candidate.root_module.linkSystemLibrary("winhttp", .{});
        migration_candidate.root_module.linkSystemLibrary("version", .{});
        migration_candidate.root_module.addWin32ResourceFile(.{
            .file = b.path("assets/windows/zmd.rc"),
            .include_paths = &.{ b.path("assets/windows"), generated_resources.getDirectory() },
        });
        const replace_module = b.createModule(.{
            .root_source_file = b.path("src/updater_win32.zig"),
            .target = target,
            .optimize = optimize,
        });
        const replace_probe = b.addExecutable(.{
            .name = "zmd-uninstall-replace-probe",
            .root_module = b.createModule(.{
                .root_source_file = b.path("test/uninstall_e2e_replace.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "updater_win32", .module = replace_module }},
            }),
        });
        replace_probe.root_module.linkSystemLibrary("winhttp", .{});
        replace_probe.root_module.linkSystemLibrary("advapi32", .{});
        const migration_test = b.addSystemCommand(&.{ "python", "test/uninstall_e2e_migration.py" });
        migration_test.addArtifactArg(migration_candidate);
        migration_test.addArtifactArg(replace_probe);
        migration_test.addArg(app_version);
        migration_test.addArg(migration_prefix);
        uninstall_process.step.dependOn(&migration_test.step);

        const uninstall_windows_module = b.createModule(.{
            .root_source_file = b.path("src/uninstall_windows_win32.zig"),
            .target = target,
            .optimize = optimize,
        });
        const uninstall_windows_unit_tests = b.addTest(.{ .root_module = uninstall_windows_module });
        uninstall_windows_unit_tests.root_module.linkSystemLibrary("user32", .{});
        const run_uninstall_windows_unit_tests = b.addRunArtifact(uninstall_windows_unit_tests);
        const uninstall_windows_fixture = b.addExecutable(.{
            .name = "zmd-uninstall-windows-fixture",
            .root_module = b.createModule(.{
                .root_source_file = b.path("test/uninstall_windows_fixture.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "uninstall_windows", .module = uninstall_windows_module }},
            }),
        });
        uninstall_windows_fixture.root_module.linkSystemLibrary("user32", .{});
        const uninstall_windows_process = b.addSystemCommand(&.{ "python", "test/uninstall_windows_headless.py" });
        uninstall_windows_process.addArtifactArg(uninstall_windows_fixture);
        uninstall_windows_process.step.dependOn(&run_uninstall_windows_unit_tests.step);
        run_uninstall_windows_tests = &uninstall_windows_process.step;
    }

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_image_tests.step);
    if (run_ui_tests) |run| test_step.dependOn(&run.step);
    if (run_updater_tests) |run| test_step.dependOn(&run.step);
    if (run_updater_win32_tests) |run| test_step.dependOn(&run.step);
    if (run_uninstall_e2e_tests) |run| test_step.dependOn(&run.step);
    if (run_uninstall_process_test) |run| test_step.dependOn(&run.step);
    if (run_uninstall_windows_tests) |run| test_step.dependOn(run);

    const installer_step = b.step("installer", "Build the Windows installer executable");
    if (setup_install_step) |install_step| {
        installer_step.dependOn(install_step);
    } else {
        installer_step.dependOn(b.getInstallStep());
    }
}
