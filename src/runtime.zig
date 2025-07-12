//! Container runtime integration module
//! 
//! Handles integration with container runtimes like Docker, Podman, and containerd
//! by modifying OCI specifications to include GPU access.

const std = @import("std");
const discover = @import("discover.zig");
const config = @import("config.zig");

/// OCI container specification (simplified)
pub const OciSpec = struct {
    process: ?Process,
    mounts: std.ArrayList(OciMount),
    linux: ?Linux,
    
    pub const Process = struct {
        env: std.ArrayList([]const u8),
        
        pub fn deinit(self: *Process, allocator: std.mem.Allocator) void {
            for (self.env.items) |env_var| {
                allocator.free(env_var);
            }
            self.env.deinit();
        }
    };
    
    pub const OciMount = struct {
        source: []const u8,
        destination: []const u8,
        type: []const u8,
        options: std.ArrayList([]const u8),
        
        pub fn deinit(self: *OciMount, allocator: std.mem.Allocator) void {
            allocator.free(self.source);
            allocator.free(self.destination);
            allocator.free(self.type);
            for (self.options.items) |option| {
                allocator.free(option);
            }
            self.options.deinit();
        }
    };
    
    pub const Linux = struct {
        devices: std.ArrayList(Device),
        
        pub const Device = struct {
            path: []const u8,
            type: []const u8,
            major: i64,
            minor: i64,
            
            pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
                allocator.free(self.path);
                allocator.free(self.type);
            }
        };
        
        pub fn deinit(self: *Linux, allocator: std.mem.Allocator) void {
            for (self.devices.items) |*device| {
                device.deinit(allocator);
            }
            self.devices.deinit();
        }
    };
    
    pub fn init(allocator: std.mem.Allocator) OciSpec {
        return OciSpec{
            .process = null,
            .mounts = std.ArrayList(OciMount).init(allocator),
            .linux = null,
        };
    }
    
    pub fn deinit(self: *OciSpec, allocator: std.mem.Allocator) void {
        if (self.process) |*process| {
            process.deinit(allocator);
        }
        
        for (self.mounts.items) |*mount| {
            mount.deinit(allocator);
        }
        self.mounts.deinit();
        
        if (self.linux) |*linux| {
            linux.deinit(allocator);
        }
    }
};

/// Runtime modifier that adds GPU support to container specs
pub const RuntimeModifier = struct {
    allocator: std.mem.Allocator,
    discoverer: discover.Discoverer,
    config: *const config.Config,
    
    pub fn init(allocator: std.mem.Allocator, cfg: *const config.Config) RuntimeModifier {
        return RuntimeModifier{
            .allocator = allocator,
            .discoverer = discover.Discoverer.init(allocator),
            .config = cfg,
        };
    }
    
    /// Modify OCI spec to include GPU access
    pub fn modifySpec(self: *RuntimeModifier, spec: *OciSpec) !void {
        switch (self.config.runtime_mode) {
            .legacy => try self.modifySpecLegacy(spec),
            .csv => try self.modifySpecCsv(spec),
            .cdi => try self.modifySpecCdi(spec),
        }
    }
    
    /// Legacy mode: direct device and library mounting
    fn modifySpecLegacy(self: *RuntimeModifier, spec: *OciSpec) !void {
        // Add NVIDIA devices
        var devices = try self.discoverer.discoverCharDevices();
        defer {
            for (devices.items) |*device| {
                device.deinit(self.allocator);
            }
            devices.deinit();
        }
        
        // Ensure linux section exists
        if (spec.linux == null) {
            spec.linux = OciSpec.Linux{
                .devices = std.ArrayList(OciSpec.Linux.Device).init(self.allocator),
            };
        }
        
        // Add devices to spec
        for (devices.items) |device| {
            const oci_device = OciSpec.Linux.Device{
                .path = try self.allocator.dupe(u8, device.device_path),
                .type = try self.allocator.dupe(u8, "c"),
                .major = 195, // NVIDIA major device number
                .minor = @intCast(device.minor),
            };
            try spec.linux.?.devices.append(oci_device);
        }
        
        // Add library mounts
        var libraries = try self.discoverer.discoverDriverLibraries();
        defer {
            for (libraries.items) |*lib| {
                lib.deinit(self.allocator);
            }
            libraries.deinit();
        }
        
        for (libraries.items) |lib| {
            var options = std.ArrayList([]const u8).init(self.allocator);
            try options.append(try self.allocator.dupe(u8, "bind"));
            try options.append(try self.allocator.dupe(u8, "ro"));
            
            const oci_mount = OciSpec.OciMount{
                .source = try self.allocator.dupe(u8, lib.source),
                .destination = try self.allocator.dupe(u8, lib.destination),
                .type = try self.allocator.dupe(u8, "bind"),
                .options = options,
            };
            try spec.mounts.append(oci_mount);
        }
        
        // Add environment variables
        if (spec.process == null) {
            spec.process = OciSpec.Process{
                .env = std.ArrayList([]const u8).init(self.allocator),
            };
        }
        
        try spec.process.?.env.append(try self.allocator.dupe(u8, "NVIDIA_VISIBLE_DEVICES=all"));
        try spec.process.?.env.append(try self.allocator.dupe(u8, "NVIDIA_DRIVER_CAPABILITIES=compute,utility"));
    }
    
    /// CSV mode: use nvidia-container-cli
    fn modifySpecCsv(_: *RuntimeModifier, _: *OciSpec) !void {
        // TODO: Implement CSV mode when needed
        return error.NotImplemented;
    }
    
    /// CDI mode: use Container Device Interface
    fn modifySpecCdi(_: *RuntimeModifier, _: *OciSpec) !void {
        // TODO: Implement CDI mode when needed
        return error.NotImplemented;
    }
};

/// Runtime wrapper that executes the actual container runtime
pub const RuntimeWrapper = struct {
    allocator: std.mem.Allocator,
    config: *const config.Config,
    runtime_path: []const u8,
    
    pub fn init(allocator: std.mem.Allocator, cfg: *const config.Config, runtime_path: []const u8) RuntimeWrapper {
        return RuntimeWrapper{
            .allocator = allocator,
            .config = cfg,
            .runtime_path = runtime_path,
        };
    }
    
    /// Execute container runtime with modified spec
    pub fn execRuntime(self: *RuntimeWrapper, args: []const []const u8) !void {
        // Build command line
        var cmd_args = std.ArrayList([]const u8).init(self.allocator);
        defer cmd_args.deinit();
        
        try cmd_args.append(self.runtime_path);
        for (args) |arg| {
            try cmd_args.append(arg);
        }
        
        // Execute runtime
        var child = std.process.Child.init(cmd_args.items, self.allocator);
        const result = try child.spawnAndWait();
        
        switch (result) {
            .Exited => |code| {
                if (code != 0) {
                    return error.RuntimeFailed;
                }
            },
            else => return error.RuntimeFailed,
        }
    }
};

test "oci spec creation" {
    var spec = OciSpec.init(std.testing.allocator);
    defer spec.deinit(std.testing.allocator);
    
    try std.testing.expect(spec.mounts.items.len == 0);
}

test "runtime modifier creation" {
    var cfg = config.Config.init(std.testing.allocator);
    defer cfg.deinit();
    
    const modifier = RuntimeModifier.init(std.testing.allocator, &cfg);
    _ = modifier;
}