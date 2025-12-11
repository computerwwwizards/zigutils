const std = @import("std");
const common = @import("common.zig");
const name_utils = @import("name_utils.zig");

const ServiceDef = common.ServiceDef;

/// Parsed command line arguments
pub const CliArgs = struct {
    /// Path to JSON configuration file (optional, can be null)
    config_path: ?[]const u8 = null,
    /// Output directory for generated files
    output_dir: ?[]const u8 = null,
    /// Services defined via CLI (optional, can be empty)
    services: []ServiceDef = &[_]ServiceDef{},
};

/// Parse command line arguments
///
/// Expected format:
///   di-code-gen [--config <path>] [--output <dir>] [--service <name>[:<interface>] ...]
///
/// Service format:
///   --service userService           (interface auto-inferred as IUserService)
///   --service user_service:IUser    (custom interface)
///
/// Arguments are optional. If no config is provided, looks for default config in cwd.
///
/// Arguments:
///   - allocator: Memory allocator for storing argument strings
///   - args: Raw command line arguments (argv)
///
/// Returns:
///   - CliArgs with parsed configuration and services
pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !CliArgs {
    var parsed = CliArgs{};
    var service_list = try std.ArrayList(ServiceDef).initCapacity(allocator, 0);
    defer service_list.deinit(allocator);

    var i: usize = 1; // Skip program name
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--config")) {
            i += 1;
            if (i >= args.len) {
                return error.MissingConfigPath;
            }
            parsed.config_path = try allocator.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, args[i], "--output")) {
            i += 1;
            if (i >= args.len) {
                return error.MissingOutputPath;
            }
            parsed.output_dir = try allocator.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, args[i], "--service")) {
            i += 1;
            if (i >= args.len) {
                return error.MissingServiceName;
            }
            const service_spec = args[i];
            
            // Parse serviceName or serviceName:InterfaceName
            var name: []const u8 = undefined;
            var interface: []const u8 = undefined;
            
            if (std.mem.indexOfScalar(u8, service_spec, ':')) |colon_idx| {
                // Custom interface provided
                name = try allocator.dupe(u8, service_spec[0..colon_idx]);
                interface = try allocator.dupe(u8, service_spec[colon_idx + 1 ..]);
            } else {
                // Auto-infer interface: serviceName -> IServiceName (PascalCase)
                name = try allocator.dupe(u8, service_spec);
                const pascal = try name_utils.toPascalCase(allocator, service_spec);
                defer allocator.free(pascal);
                interface = try std.fmt.allocPrint(allocator, "I{s}", .{pascal});
            }
            
            try service_list.append(allocator, ServiceDef{
                .name = name,
                .interface = interface,
            });
        }
    }

    if (service_list.items.len > 0) {
        parsed.services = try allocator.dupe(ServiceDef, service_list.items);
    }

    return parsed;
}

/// Configuration loaded from JSON file
pub const JsonConfig = struct {
    output: []const u8,
    services: []const ServiceDef,
};

/// Find default configuration file in current directory
/// Returns null if no default config found
pub fn findDefaultConfig(allocator: std.mem.Allocator) ?[]const u8 {
    const default_names = [_][]const u8{ "di.config.json", "config.json", ".di.config.json" };

    for (default_names) |name| {
        if (std.fs.cwd().openFile(name, .{})) |file| {
            file.close();
            // File exists, return duplicated path
            return allocator.dupe(u8, name) catch null;
        } else |_| {
            continue;
        }
    }

    return null;
}

/// Load services from JSON configuration file
pub fn loadConfig(allocator: std.mem.Allocator, config_path: []const u8) !JsonConfig {
    const file = try std.fs.cwd().openFile(config_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var json = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer json.deinit();

    const root = json.value.object;

    // Parse output directory
    const output_value = root.get("output") orelse return error.MissingOutputField;
    const output = switch (output_value) {
        .string => |str| try allocator.dupe(u8, str),
        else => return error.InvalidOutputField,
    };

    // Parse services array
    const services_value = root.get("services") orelse return error.MissingServicesField;
    const services_array = switch (services_value) {
        .array => |arr| arr,
        else => return error.InvalidServicesField,
    };

    var services = try allocator.alloc(ServiceDef, services_array.items.len);

    for (services_array.items, 0..) |item, i| {
        const service_obj = switch (item) {
            .object => |obj| obj,
            else => return error.InvalidServiceEntry,
        };

        const name_value = service_obj.get("name") orelse return error.MissingServiceName;
        const interface_value = service_obj.get("interface") orelse return error.MissingServiceInterface;

        const name = switch (name_value) {
            .string => |str| try allocator.dupe(u8, str),
            else => return error.InvalidServiceName,
        };

        const interface = switch (interface_value) {
            .string => |str| try allocator.dupe(u8, str),
            else => return error.InvalidServiceInterface,
        };

        services[i] = ServiceDef{
            .name = name,
            .interface = interface,
        };
    }

    return JsonConfig{
        .output = output,
        .services = services,
    };
}

test "parseArgs basic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = [_][]const u8{
        "di-code-gen",
        "--config",
        "config.json",
    };

    const parsed = try parseArgs(allocator, &args);
    try std.testing.expectEqualStrings("config.json", parsed.config_path);
    try std.testing.expect(parsed.output_dir == null);

    allocator.free(parsed.config_path);
}

test "parseArgs with output" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = [_][]const u8{
        "di-code-gen",
        "--config",
        "config.json",
        "--output",
        "./src/di",
    };

    const parsed = try parseArgs(allocator, &args);
    try std.testing.expectEqualStrings("config.json", parsed.config_path);
    try std.testing.expectEqualStrings("./src/di", parsed.output_dir.?);

    allocator.free(parsed.config_path);
    allocator.free(parsed.output_dir.?);
}
