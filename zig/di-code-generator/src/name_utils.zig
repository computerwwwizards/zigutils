const std = @import("std");

/// Common naming conventions for code generation
pub const NamingCase = enum {
    camelCase,
    PascalCase,
    snake_case,
    kebab_case,
    SCREAMING_SNAKE_CASE,
};

/// Convert a string to camelCase
pub fn toCamelCase(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return allocator.dupe(u8, "");

    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    var capitalize_next = false;
    var is_first = true;

    for (input) |c| {
        if (c == '_' or c == '-' or c == ' ') {
            capitalize_next = true;
            continue;
        }

        if (capitalize_next) {
            try result.append(allocator, std.ascii.toUpper(c));
            capitalize_next = false;
        } else if (is_first) {
            try result.append(allocator, std.ascii.toLower(c));
            is_first = false;
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Convert a string to PascalCase
pub fn toPascalCase(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return allocator.dupe(u8, "");

    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    var capitalize_next = true;

    for (input) |c| {
        if (c == '_' or c == '-' or c == ' ') {
            capitalize_next = true;
            continue;
        }

        if (capitalize_next) {
            try result.append(allocator, std.ascii.toUpper(c));
            capitalize_next = false;
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Convert a string to snake_case
pub fn toSnakeCase(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return allocator.dupe(u8, "");

    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    for (input, 0..) |c, i| {
        if (c == '-' or c == ' ') {
            try result.append(allocator, '_');
        } else if (std.ascii.isUpper(c)) {
            if (i > 0 and result.items.len > 0 and result.items[result.items.len - 1] != '_') {
                try result.append(allocator, '_');
            }
            try result.append(allocator, std.ascii.toLower(c));
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Convert a string to kebab-case
pub fn toKebabCase(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return allocator.dupe(u8, "");

    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    for (input, 0..) |c, i| {
        if (c == '_' or c == ' ') {
            try result.append(allocator, '-');
        } else if (std.ascii.isUpper(c)) {
            if (i > 0 and result.items.len > 0 and result.items[result.items.len - 1] != '-') {
                try result.append(allocator, '-');
            }
            try result.append(allocator, std.ascii.toLower(c));
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Parameterize a name with a pattern (e.g., "register{Name}" + "ServiceA" -> "registerServiceA")
pub fn parameterizeName(
    allocator: std.mem.Allocator,
    pattern: []const u8,
    name: []const u8,
    case: NamingCase,
) ![]u8 {
    const converted_name = switch (case) {
        .camelCase => try toCamelCase(allocator, name),
        .PascalCase => try toPascalCase(allocator, name),
        .snake_case => try toSnakeCase(allocator, name),
        .kebab_case => try toKebabCase(allocator, name),
        .SCREAMING_SNAKE_CASE => blk: {
            const snake = try toSnakeCase(allocator, name);
            defer allocator.free(snake);
            var upper = try allocator.alloc(u8, snake.len);
            for (snake, 0..) |c, i| {
                upper[i] = std.ascii.toUpper(c);
            }
            break :blk upper;
        },
    };
    defer allocator.free(converted_name);

    var params = std.StringHashMap([]const u8).init(allocator);
    defer params.deinit();
    try params.put("Name", converted_name);
    try params.put("name", converted_name);

    const interpolation = @import("interpolation.zig");
    const parts = try interpolation.parseTemplate(allocator, pattern);
    defer allocator.free(parts);

    return interpolation.applyParams(allocator, parts, params);
}

/// Concatenate names with common patterns
pub fn concatNames(
    allocator: std.mem.Allocator,
    parts: []const []const u8,
    separator: []const u8,
) ![]u8 {
    const interpolation = @import("interpolation.zig");
    return interpolation.concat(allocator, separator, parts);
}

// Tests
test "toCamelCase" {
    const allocator = std.testing.allocator;

    {
        const result = try toCamelCase(allocator, "hello_world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("helloWorld", result);
    }

    {
        const result = try toCamelCase(allocator, "hello-world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("helloWorld", result);
    }

    {
        const result = try toCamelCase(allocator, "HelloWorld");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("helloWorld", result);
    }
}

test "toPascalCase" {
    const allocator = std.testing.allocator;

    {
        const result = try toPascalCase(allocator, "hello_world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("HelloWorld", result);
    }

    {
        const result = try toPascalCase(allocator, "hello-world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("HelloWorld", result);
    }
}

test "toSnakeCase" {
    const allocator = std.testing.allocator;

    {
        const result = try toSnakeCase(allocator, "helloWorld");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("hello_world", result);
    }

    {
        const result = try toSnakeCase(allocator, "HelloWorld");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("hello_world", result);
    }

    {
        const result = try toSnakeCase(allocator, "hello-world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("hello_world", result);
    }
}

test "toKebabCase" {
    const allocator = std.testing.allocator;

    {
        const result = try toKebabCase(allocator, "helloWorld");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("hello-world", result);
    }

    {
        const result = try toKebabCase(allocator, "hello_world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("hello-world", result);
    }
}

test "parameterizeName with PascalCase" {
    const allocator = std.testing.allocator;

    const result = try parameterizeName(allocator, "register{Name}", "service_a", .PascalCase);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("registerServiceA", result);
}

test "parameterizeName with camelCase" {
    const allocator = std.testing.allocator;

    const result = try parameterizeName(allocator, "I{Name}", "service_provider", .PascalCase);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("IServiceProvider", result);
}

test "concatNames" {
    const allocator = std.testing.allocator;

    const parts = [_][]const u8{ "register", "Service", "A" };
    const result = try concatNames(allocator, &parts, "");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("registerServiceA", result);
}
