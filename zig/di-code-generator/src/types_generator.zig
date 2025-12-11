const std = @import("std");
const common = @import("common.zig");
const interpolation = @import("interpolation.zig");

const ServiceDef = common.ServiceDef;

/// Options for types.ts generation
pub const TypesGeneratorOptions = struct {
    /// Package path for dependency injection library
    /// Defaults to "@computerwwwizards/dependency-injection"
    di_package_path: []const u8 = "@computerwwwizards/dependency-injection",
};

/// Generates a types.ts file containing ServicesList interface and ContainerCtx type alias
///
/// Arguments:
///   - allocator: Memory allocator for string building
///   - output_path: File path where types.ts will be written
///   - services: Slice of ServiceDef structs defining all services
///   - options: Optional generation options (uses defaults if null)
///
/// Returns:
///   - void: Writes file to disk or returns error
pub fn generateTypesFile(
    allocator: std.mem.Allocator,
    output_path: []const u8,
    services: []const ServiceDef,
    options: ?TypesGeneratorOptions,
) !void {
    _ = services; // Services are added via module augmentation in registerServiceX.ts files
    const opts = options orelse TypesGeneratorOptions{};

    // Build the complete template with interpolation
    var content: std.ArrayList(u8) = .{};
    defer content.deinit(allocator);

    var writer = content.writer(allocator);

    // Import line
    try writer.print(
        "import type {{ PreProcessDependencyContainerWithUse }} from '{s}'\n\n",
        .{opts.di_package_path},
    );

    // ServicesList interface (empty - services added via module augmentation)
    try writer.writeAll("export interface ServicesList {}\n\n");

    // ContainerCtx type alias
    try writer.writeAll("export type ContainerCtx = PreProcessDependencyContainerWithUse<ServicesList>\n");

    // Write to file
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    try file.writeAll(content.items);
}

test "generateTypesFile single service" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const services = [_]ServiceDef{
        .{
            .name = "userService",
            .interface = "IUserService",
        },
    };

    const temp_dir = std.fs.cwd();
    const temp_file = "test_types_single.ts";
    defer temp_dir.deleteFile(temp_file) catch {};

    try generateTypesFile(allocator, temp_file, &services, null);

    const file = try temp_dir.openFile(temp_file, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024);
    defer allocator.free(content);

    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "PreProcessDependencyContainerWithUse"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "ServicesList"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "export interface ServicesList {}"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "ContainerCtx"));
}

test "generateTypesFile multiple services" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const services = [_]ServiceDef{
        .{ .name = "userService", .interface = "IUserService" },
        .{ .name = "authProvider", .interface = "IAuthProvider" },
        .{ .name = "apiClient", .interface = "IApiClient" },
    };

    const temp_dir = std.fs.cwd();
    const temp_file = "test_types_multiple.ts";
    defer temp_dir.deleteFile(temp_file) catch {};

    try generateTypesFile(allocator, temp_file, &services, null);

    const file = try temp_dir.openFile(temp_file, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 2048);
    defer allocator.free(content);

    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "PreProcessDependencyContainerWithUse"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "export interface ServicesList {}"));
    // Services are added via module augmentation in registerServiceX.ts, not in types.ts
}

test "generateTypesFile custom di_package_path" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const services = [_]ServiceDef{
        .{ .name = "svc", .interface = "ISvc" },
    };

    const opts = TypesGeneratorOptions{
        .di_package_path = "@custom/di-library",
    };

    const temp_dir = std.fs.cwd();
    const temp_file = "test_types_custom.ts";
    defer temp_dir.deleteFile(temp_file) catch {};

    try generateTypesFile(allocator, temp_file, &services, opts);

    const file = try temp_dir.openFile(temp_file, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024);
    defer allocator.free(content);

    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "@custom/di-library"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, content, 1, "@computerwwwizards/dependency-injection"));
}
