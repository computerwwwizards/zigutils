const std = @import("std");

/// Represents a service definition for code generation
pub const ServiceDef = struct {
    /// The service name in camelCase (e.g., "userService", "authProvider")
    name: []const u8,
    /// The interface name in PascalCase (e.g., "IUserService", "IAuthProvider")
    interface: []const u8,
};

test "ServiceDef creation" {
    const service = ServiceDef{
        .name = "userService",
        .interface = "IUserService",
    };
    try std.testing.expectEqualStrings("userService", service.name);
    try std.testing.expectEqualStrings("IUserService", service.interface);
}
