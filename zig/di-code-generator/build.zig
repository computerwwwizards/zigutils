const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("di-code-generator", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "di-code-generator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "di-code-generator", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Test organization: separate test executables by concern
    const test_step = b.step("test", "Run all tests");

    // String interpolation tests
    const interpolation_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/interpolation.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_interpolation_tests = b.addRunArtifact(interpolation_tests);
    test_step.dependOn(&run_interpolation_tests.step);

    // Name utilities tests
    const name_utils_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/name_utils.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_name_utils_tests = b.addRunArtifact(name_utils_tests);
    test_step.dependOn(&run_name_utils_tests.step);

    // Module tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    test_step.dependOn(&run_mod_tests.step);
}
