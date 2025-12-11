const std = @import("std");
const common = @import("common.zig");
const name_utils = @import("name_utils.zig");

const ServiceDef = common.ServiceDef;

/// Options for registerServiceX.ts generation
pub const RegisterServiceGeneratorOptions = struct {
    /// Package path for dependency injection library
    /// Defaults to "@computerwwwizards/dependency-injection"
    di_package_path: []const u8 = "@computerwwwizards/dependency-injection",
    /// Relative path to types module
    /// Defaults to "./types"
    types_module_path: []const u8 = "./types",
};

/// Generates a registerServiceX.ts file for a single service
///
/// Arguments:
///   - allocator: Memory allocator for string building
///   - output_path: File path where registerServiceX.ts will be written
///   - service: ServiceDef struct defining the service
///   - options: Optional generation options (uses defaults if null)
///
/// Returns:
///   - void: Writes file to disk or returns error
pub fn generateRegisterServiceFile(
    allocator: std.mem.Allocator,
    output_path: []const u8,
    service: ServiceDef,
    options: ?RegisterServiceGeneratorOptions,
) !void {
    const opts = options orelse RegisterServiceGeneratorOptions{};

    // Convert service name to PascalCase for function names
    const pascal_case_name = try name_utils.toPascalCase(allocator, service.name);
    defer allocator.free(pascal_case_name);

    // Build the complete file content
    var content: std.ArrayList(u8) = .{};
    defer content.deinit(allocator);
    var writer = content.writer(allocator);

    // Import statements
    try writer.print(
        "import type {{ PreProcessDependencyContainerWithUse }} from '{s}'\n",
        .{opts.di_package_path},
    );
    try writer.print(
        "import {{ type ContainerCtx }} from '{s}'\n\n",
        .{opts.types_module_path},
    );

    // Service interface (stub)
    try writer.print(
        "export interface {s} {{\n",
        .{service.interface},
    );
    try writer.writeAll("  // TODO: Define service interface\n");
    try writer.writeAll("}\n\n");

    // Module augmentation
    try writer.print(
        "declare module '{s}' {{\n",
        .{opts.types_module_path},
    );
    try writer.writeAll("  interface ServicesList {\n");
    try writer.print(
        "    {s}: {s}\n",
        .{ service.name, service.interface },
    );
    try writer.writeAll("  }\n");
    try writer.writeAll("}\n\n");

    // Default register function
    try writer.print(
        "export default function register{s}(\n",
        .{pascal_case_name},
    );
    try writer.writeAll("  container: ContainerCtx\n");
    try writer.writeAll(") {\n");
    try writer.print(
        "  container.bind('{s}', {{\n",
        .{service.name},
    );
    try writer.writeAll("    // TODO: Implement service registration\n");
    try writer.writeAll("  })\n");
    try writer.writeAll("}\n\n");

    // Mock function
    try writer.writeAll("export function mock(\n");
    try writer.writeAll("  container: ContainerCtx\n");
    try writer.writeAll(") {\n");
    try writer.print(
        "  container.bind('{s}', {{\n",
        .{service.name},
    );
    try writer.writeAll("    // TODO: Implement mock service registration\n");
    try writer.writeAll("  })\n");
    try writer.writeAll("}\n\n");

    // Attach mock to main function
    try writer.print(
        "register{s}.mock = mock\n",
        .{pascal_case_name},
    );

    // Write to file
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    try file.writeAll(content.items);
}

test "generateRegisterServiceFile single service" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const service = ServiceDef{
        .name = "userService",
        .interface = "IUserService",
    };

    const temp_dir = std.fs.cwd();
    const temp_file = "test_register_single.ts";
    defer temp_dir.deleteFile(temp_file) catch {};

    try generateRegisterServiceFile(allocator, temp_file, service, null);

    const file = try temp_dir.openFile(temp_file, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 2048);
    defer allocator.free(content);

    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "PreProcessDependencyContainerWithUse"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "ContainerCtx"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "export interface IUserService"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "export default function registerUserService"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "export function mock"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "registerUserService.mock = mock"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "declare module './types'"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "userService: IUserService"));
}

test "generateRegisterServiceFile with snake_case name" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const service = ServiceDef{
        .name = "auth_provider",
        .interface = "IAuthProvider",
    };

    const temp_dir = std.fs.cwd();
    const temp_file = "test_register_snake.ts";
    defer temp_dir.deleteFile(temp_file) catch {};

    try generateRegisterServiceFile(allocator, temp_file, service, null);

    const file = try temp_dir.openFile(temp_file, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 2048);
    defer allocator.free(content);

    // Should convert auth_provider to AuthProvider for function name
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "registerAuthProvider"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "auth_provider"));
}

test "generateRegisterServiceFile custom options" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const service = ServiceDef{
        .name = "dbService",
        .interface = "IDbService",
    };

    const opts = RegisterServiceGeneratorOptions{
        .di_package_path = "@my/di",
        .types_module_path = "../shared/types",
    };

    const temp_dir = std.fs.cwd();
    const temp_file = "test_register_custom.ts";
    defer temp_dir.deleteFile(temp_file) catch {};

    try generateRegisterServiceFile(allocator, temp_file, service, opts);

    const file = try temp_dir.openFile(temp_file, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 2048);
    defer allocator.free(content);

    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "@my/di"));
    try std.testing.expect(std.mem.containsAtLeast(u8, content, 1, "../shared/types"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, content, 1, "@computerwwwizards/dependency-injection"));
}
