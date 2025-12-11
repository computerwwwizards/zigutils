const std = @import("std");
const di_gen = @import("di-code-generator");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse CLI arguments (all optional)
    const cli_args = di_gen.cli.parseArgs(allocator, args) catch |err| {
        std.debug.print("Error parsing arguments: {}\n", .{err});
        std.debug.print("Usage: di-code-gen [--config <path>] [--output <dir>]\n", .{});
        return err;
    };
    // Note: defer freeing cli_args is skipped to avoid segfault during cleanup
    // The process exits immediately after, so cleanup isn't critical

    // Determine config path: CLI takes precedence, then look for default, then none
    const config_path = cli_args.config_path orelse di_gen.cli.findDefaultConfig(allocator);
    defer if (config_path) |path| allocator.free(path);

    var config: di_gen.cli.JsonConfig = undefined;
    var config_loaded = false;

    // Try to load config if path is available
    if (config_path) |path| {
        if (di_gen.cli.loadConfig(allocator, path)) |loaded_config| {
            config = loaded_config;
            config_loaded = true;
            std.debug.print("✓ Loaded config from: {s}\n", .{path});
        } else |err| {
            std.debug.print("Warning: Could not load config file '{s}': {}\n", .{ path, err });
            std.debug.print("Continuing without config file\n", .{});
        }
    }

    // If no config loaded and no CLI output dir, use current directory as default
    // Don't error - just continue with empty services
    const output_dir = cli_args.output_dir orelse (if (config_loaded) config.output else ".");
    const services = if (config_loaded) config.services else &[_]di_gen.common.ServiceDef{};

    defer if (config_loaded) {
        allocator.free(config.output);
        for (config.services) |service| {
            allocator.free(service.name);
            allocator.free(service.interface);
        }
        allocator.free(config.services);
    };

    std.debug.print("DI Code Generator\n", .{});
    std.debug.print("=================\n\n", .{});
    if (config_path) |path| {
        std.debug.print("Config: {s}\n", .{path});
    }
    std.debug.print("Output: {s}\n", .{output_dir});
    std.debug.print("Services: {}\n\n", .{services.len});

    if (services.len == 0) {
        std.debug.print("Warning: No services to generate\n", .{});
        return;
    }

    // Run the orchestrator
    const gen_config = di_gen.orchestrator.GeneratorConfig{
        .output_dir = output_dir,
        .services = services,
    };

    try di_gen.orchestrator.generateAll(allocator, gen_config);

    std.debug.print("\n✓ Code generation completed successfully!\n", .{});
}
