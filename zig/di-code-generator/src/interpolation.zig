const std = @import("std");

/// Represents a part of an interpolated string - either literal text or a parameter
pub const InterpolationPart = union(enum) {
    literal: []const u8,
    param: []const u8,

    pub fn format(
        self: InterpolationPart,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .literal => |text| try writer.writeAll(text),
            .param => |name| try writer.print("{{{s}}}", .{name}),
        }
    }
};

/// Parse a template string into interpolation parts
/// Template format: "Hello {name}, welcome to {place}"
pub fn parseTemplate(allocator: std.mem.Allocator, template: []const u8) ![]InterpolationPart {
    var parts: std.ArrayList(InterpolationPart) = .{};
    errdefer parts.deinit(allocator);

    var i: usize = 0;
    var start: usize = 0;

    while (i < template.len) {
        if (template[i] == '{') {
            // Add literal part before the parameter
            if (i > start) {
                try parts.append(allocator, .{ .literal = template[start..i] });
            }

            // Find closing brace
            const param_start = i + 1;
            i += 1;
            while (i < template.len and template[i] != '}') : (i += 1) {}

            if (i >= template.len) {
                return error.UnclosedParameter;
            }

            // Add parameter part
            try parts.append(allocator, .{ .param = template[param_start..i] });
            i += 1;
            start = i;
        } else {
            i += 1;
        }
    }

    // Add remaining literal
    if (start < template.len) {
        try parts.append(allocator, .{ .literal = template[start..] });
    }

    return parts.toOwnedSlice(allocator);
}

/// Apply parameters to interpolation parts
pub fn applyParams(
    allocator: std.mem.Allocator,
    parts: []const InterpolationPart,
    params: std.StringHashMap([]const u8),
) ![]u8 {
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    for (parts) |part| {
        switch (part) {
            .literal => |text| try result.appendSlice(allocator, text),
            .param => |name| {
                const value = params.get(name) orelse return error.MissingParameter;
                try result.appendSlice(allocator, value);
            },
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Concatenate multiple strings with a separator
pub fn concat(allocator: std.mem.Allocator, separator: []const u8, strings: []const []const u8) ![]u8 {
    if (strings.len == 0) return allocator.dupe(u8, "");
    if (strings.len == 1) return allocator.dupe(u8, strings[0]);

    var total_len: usize = 0;
    for (strings) |s| {
        total_len += s.len;
    }
    total_len += separator.len * (strings.len - 1);

    var result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    for (strings, 0..) |s, idx| {
        @memcpy(result[pos .. pos + s.len], s);
        pos += s.len;
        if (idx < strings.len - 1) {
            @memcpy(result[pos .. pos + separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}

// Tests
test "parse simple template" {
    const allocator = std.testing.allocator;

    const template = "Hello {name}!";
    const parts = try parseTemplate(allocator, template);
    defer allocator.free(parts);

    try std.testing.expectEqual(@as(usize, 3), parts.len);
    try std.testing.expectEqualStrings("Hello ", parts[0].literal);
    try std.testing.expectEqualStrings("name", parts[1].param);
    try std.testing.expectEqualStrings("!", parts[2].literal);
}

test "parse template with multiple params" {
    const allocator = std.testing.allocator;

    const template = "{greeting} {name}, welcome to {place}";
    const parts = try parseTemplate(allocator, template);
    defer allocator.free(parts);

    try std.testing.expectEqual(@as(usize, 5), parts.len);
    try std.testing.expectEqualStrings("greeting", parts[0].param);
    try std.testing.expectEqualStrings(" ", parts[1].literal);
    try std.testing.expectEqualStrings("name", parts[2].param);
    try std.testing.expectEqualStrings(", welcome to ", parts[3].literal);
    try std.testing.expectEqualStrings("place", parts[4].param);
}

test "apply params" {
    const allocator = std.testing.allocator;

    const template = "Hello {name}!";
    const parts = try parseTemplate(allocator, template);
    defer allocator.free(parts);

    var params = std.StringHashMap([]const u8).init(allocator);
    defer params.deinit();
    try params.put("name", "World");

    const result = try applyParams(allocator, parts, params);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World!", result);
}

test "concat strings" {
    const allocator = std.testing.allocator;

    const strings = [_][]const u8{ "a", "b", "c" };
    const result = try concat(allocator, ", ", &strings);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("a, b, c", result);
}

test "concat empty array" {
    const allocator = std.testing.allocator;

    const strings = [_][]const u8{};
    const result = try concat(allocator, ", ", &strings);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "concat single string" {
    const allocator = std.testing.allocator;

    const strings = [_][]const u8{"single"};
    const result = try concat(allocator, ", ", &strings);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("single", result);
}
