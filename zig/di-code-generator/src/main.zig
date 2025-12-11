const std = @import("std");
const di_gen = @import("di-code-generator");

const HELP_TEXT =
    \\DI Code Generator v0.1.0
    \\Code generator for @computerwwwizards/dependency-injection
    \\
    \\USAGE:
    \\  di-code-gen [OPTIONS]
    \\
    \\OPTIONS:
    \\  --config <PATH>   Path to JSON configuration file
    \\                    Auto-discovers: di.config.json, config.json, .di.config.json
    \\  --output <DIR>    Output directory for generated files (overrides config)
    \\  --help, -h        Show this help message
    \\
    \\CONFIGURATION:
    \\  Create a config.json (or di.config.json) in your project root:
    \\
    \\  {
    \\    "output": "./src/di",
    \\    "services": [
    \\      {
    \\        "name": "userService",
    \\        "interface": "IUserService"
    \\      },
    \\      {
    \\        "name": "authProvider",
    \\        "interface": "IAuthProvider"
    \\      }
    \\    ]
    \\  }
    \\
    \\EXAMPLES:
    \\
    \\  Auto-discover config.json in current directory:
    \\    $ di-code-gen
    \\
    \\  Specify config file explicitly:
    \\    $ di-code-gen --config ./services.config.json
    \\
    \\  Override output directory:
    \\    $ di-code-gen --config config.json --output ./src/di
    \\
    \\  Custom output with auto-discovered config:
    \\    $ di-code-gen --output ./generated
    \\
    \\GENERATED STRUCTURE:
    \\  For each service, creates a directory with:
    \\    - types.ts                (ServicesList interface)
    \\    - registerServiceName.ts  (registration + mock functions)
    \\
    \\  Example output:
    \\    src/di/
    \\      userService/
    \\        types.ts
    \\        registerUserService.ts
    \\      authProvider/
    \\        types.ts
    \\        registerAuthProvider.ts
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Check for help flag
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print("{s}\n", .{HELP_TEXT});
            return;
        }
    }

    // Parse CLI arguments (all optional)
    const cli_args = di_gen.cli.parseArgs(allocator, args) catch |err| {
        std.debug.print("Error parsing arguments: {}\n", .{err});
        std.debug.print("Usage: di-code-gen [--config <path>] [--output <dir>] [--service <name>[:<interface>] ...]\n", .{});
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

    // Merge config and CLI services: CLI takes precedence
    var final_services: []const di_gen.common.ServiceDef = &[_]di_gen.common.ServiceDef{};
    if (cli_args.services.len > 0) {
        final_services = cli_args.services;
    } else if (config_loaded) {
        final_services = config.services;
    }

    // Determine output directory: CLI takes precedence
    const output_dir = cli_args.output_dir orelse (if (config_loaded) config.output else ".");

    defer if (config_loaded) {
        allocator.free(config.output);
        for (config.services) |service| {
            allocator.free(service.name);
            allocator.free(service.interface);
        }
        allocator.free(config.services);
    };

    // Also free CLI services if they were created
    defer if (cli_args.services.len > 0) {
        for (cli_args.services) |service| {
            allocator.free(service.name);
            allocator.free(service.interface);
        }
        allocator.free(cli_args.services);
    };

    std.debug.print("DI Code Generator\n", .{});
    std.debug.print("=================\n\n", .{});
    if (config_path) |path| {
        std.debug.print("Config: {s}\n", .{path});
    }
    std.debug.print("Output: {s}\n", .{output_dir});
    std.debug.print("Services: {}\n\n", .{final_services.len});

    if (final_services.len == 0) {
        std.debug.print("Warning: No services to generate\n", .{});
        return;
    }

    // Run the orchestrator
    const gen_config = di_gen.orchestrator.GeneratorConfig{
        .output_dir = output_dir,
        .services = final_services,
    };

    try di_gen.orchestrator.generateAll(allocator, gen_config);

    std.debug.print("\n✓ Code generation completed successfully!\n", .{});
}
