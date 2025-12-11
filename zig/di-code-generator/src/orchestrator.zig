const std = @import("std");
const common = @import("common.zig");
const types_generator = @import("types_generator.zig");
const register_service_generator = @import("register_service_generator.zig");

const ServiceDef = common.ServiceDef;

/// Configuration for code generation
pub const GeneratorConfig = struct {
    /// Output directory for generated files
    output_dir: []const u8,
    /// List of services to generate
    services: []const ServiceDef,
    /// Options for types file generation
    types_options: ?types_generator.TypesGeneratorOptions = null,
    /// Options for register service files
    register_options: ?register_service_generator.RegisterServiceGeneratorOptions = null,
};

/// Context for a single service generation task
const ServiceGenerationTask = struct {
    service: ServiceDef,
    output_path: []const u8,
    options: ?register_service_generator.RegisterServiceGeneratorOptions,
    allocator: std.mem.Allocator,
};

/// Thread entry point for service file generation
fn generateServiceFileTask(ctx: *const ServiceGenerationTask) !void {
    try register_service_generator.generateRegisterServiceFile(
        ctx.allocator,
        ctx.output_path,
        ctx.service,
        ctx.options,
    );
}

/// Orchestrates the code generation process
/// 
/// For each service, creates a subdirectory and generates:
/// 1. types.ts (in service subdirectory)
/// 2. registerServiceX.ts (in service subdirectory)
/// 
/// Files are generated in parallel for efficiency.
/// 
/// Arguments:
///   - allocator: Memory allocator for file operations and thread management
///   - config: GeneratorConfig with services and output directory
///
/// Returns:
///   - void: All files written to service subdirectories or error
pub fn generateAll(
    allocator: std.mem.Allocator,
    config: GeneratorConfig,
) !void {
    // Create root output directory if it doesn't exist
    var root_dir = try std.fs.cwd().makeOpenPath(config.output_dir, .{});
    defer root_dir.close();

    if (config.services.len == 0) {
        std.debug.print("No services to generate\n", .{});
        return;
    }

    // Prepare tasks for all services
    var tasks = try allocator.alloc(ServiceGenerationTask, config.services.len);
    defer allocator.free(tasks);

    for (config.services, 0..) |service, i| {
        // Create service subdirectory path
        const service_dir = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{ config.output_dir, service.name },
        );

        // Create the service subdirectory
        _ = try std.fs.cwd().makeOpenPath(service_dir, .{});

        // Path to types.ts in service directory
        const types_path = try std.fmt.allocPrint(
            allocator,
            "{s}/types.ts",
            .{service_dir},
        );

        // Generate types.ts for this service
        try types_generator.generateTypesFile(
            allocator,
            types_path,
            config.services,
            config.types_options,
        );

        // Path to registerServiceX.ts
        const register_path = try std.fmt.allocPrint(
            allocator,
            "{s}/register{s}.ts",
            .{ service_dir, service.name },
        );

        tasks[i] = ServiceGenerationTask{
            .service = service,
            .output_path = register_path,
            .options = config.register_options,
            .allocator = allocator,
        };

        std.debug.print("✓ Generated {s}/types.ts\n", .{service.name});
        allocator.free(types_path);
        allocator.free(service_dir);
    }

    // Clean up register paths after generation
    defer {
        for (tasks) |task| {
            allocator.free(task.output_path);
        }
    }

    // Use threads for parallel execution of register file generation
    var threads = try allocator.alloc(std.Thread, config.services.len);
    defer allocator.free(threads);

    // Spawn threads for each service
    for (0..config.services.len) |i| {
        threads[i] = try std.Thread.spawn(
            .{},
            generateServiceFileTask,
            .{&tasks[i]},
        );
    }

    // Wait for all threads to complete
    for (threads) |thread| {
        thread.join();
    }

    // Report completion
    for (config.services) |service| {
        std.debug.print("✓ Generated {s}/register{s}.ts\n", .{ service.name, service.name });
    }
}

test "orchestrator with single service" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const services = [_]ServiceDef{
        .{ .name = "userService", .interface = "IUserService" },
    };

    const config = GeneratorConfig{
        .output_dir = "test_output_single",
        .services = &services,
    };

    try generateAll(allocator, config);

    // Verify files were created
    const types_file = try std.fs.cwd().openFile("test_output_single/types.ts", .{});
    defer types_file.close();

    const register_file = try std.fs.cwd().openFile("test_output_single/registeruserService.ts", .{});
    defer register_file.close();

    // Cleanup
    try std.fs.cwd().deleteFile("test_output_single/types.ts");
    try std.fs.cwd().deleteFile("test_output_single/registeruserService.ts");
    try std.fs.cwd().deleteDir("test_output_single");
}

test "orchestrator with multiple services" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const services = [_]ServiceDef{
        .{ .name = "userService", .interface = "IUserService" },
        .{ .name = "authProvider", .interface = "IAuthProvider" },
        .{ .name = "apiClient", .interface = "IApiClient" },
    };

    const config = GeneratorConfig{
        .output_dir = "test_output_multi",
        .services = &services,
    };

    try generateAll(allocator, config);

    // Verify files were created
    const types_file = try std.fs.cwd().openFile("test_output_multi/types.ts", .{});
    defer types_file.close();

    // Cleanup
    try std.fs.cwd().deleteFile("test_output_multi/types.ts");
    try std.fs.cwd().deleteFile("test_output_multi/registeruserService.ts");
    try std.fs.cwd().deleteFile("test_output_multi/registerauthProvider.ts");
    try std.fs.cwd().deleteFile("test_output_multi/registerapiClient.ts");
    try std.fs.cwd().deleteDir("test_output_multi");
}
