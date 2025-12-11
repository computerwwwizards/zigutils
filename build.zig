const std = @import("std");

pub fn build(b: *std.Build) void {
    const fs = std.fs.cwd();

    var dir = fs.openDir("zig", .{ .iterate = true }) catch return;
    defer dir.close();

    const all_step = b.step("all", "Build all Zig subprojects");
    b.default_step.dependOn(all_step);

    var it = dir.iterate();
    while (true) {
        const entry = it.next() catch break;
        if (entry == null) break;
        const e = entry.?;
        if (e.kind != .directory) continue;

        const sub_dir = std.fmt.allocPrint(b.allocator, "zig/{s}", .{e.name}) catch continue;
        const build_file_path = std.fmt.allocPrint(b.allocator, "{s}/build.zig", .{sub_dir}) catch continue;

        const build_file = fs.openFile(build_file_path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => continue,
        };
        build_file.close();

        const cmd = b.addSystemCommand(&.{
            "zig", "build",
        });
        cmd.cwd = .{ .cwd_relative = sub_dir };

        const sub_step = b.step(e.name, "Build subproject");
        sub_step.dependOn(&cmd.step);
        all_step.dependOn(sub_step);
    }
}
