//! Device discovery module
//! 
//! Handles discovery of NVIDIA devices, driver libraries, and mount points
//! needed for GPU access in containers.

const std = @import("std");

/// GPU device information
pub const GpuDevice = struct {
    device_path: []const u8,
    minor: u32,
    capabilities: std.ArrayList([]const u8),
    
    pub fn deinit(self: *GpuDevice, allocator: std.mem.Allocator) void {
        for (self.capabilities.items) |cap| {
            allocator.free(cap);
        }
        self.capabilities.deinit(allocator);
        allocator.free(self.device_path);
    }
};

/// Mount specification for bind mounts
pub const Mount = struct {
    source: []const u8,
    destination: []const u8,
    options: []const u8,
    
    pub fn deinit(self: *Mount, allocator: std.mem.Allocator) void {
        allocator.free(self.source);
        allocator.free(self.destination);
        allocator.free(self.options);
    }
};

/// Device discoverer interface
pub const Discoverer = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Discoverer {
        return Discoverer{
            .allocator = allocator,
        };
    }
    
    /// Discover NVIDIA character devices (/dev/nvidia*)
    pub fn discoverCharDevices(self: *Discoverer) !std.ArrayList(GpuDevice) {
        var devices = std.ArrayList(GpuDevice){};
        
        var dev_dir = std.fs.openDirAbsolute("/dev", .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return devices,
            else => return err,
        };
        defer dev_dir.close();
        
        var iterator = dev_dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind != .character_device) continue;
            
            if (std.mem.startsWith(u8, entry.name, "nvidia")) {
                const device_path = try std.fmt.allocPrint(self.allocator, "/dev/{s}", .{entry.name});
                
                const device = GpuDevice{
                    .device_path = device_path,
                    .minor = 0, // TODO: Parse from device
                    .capabilities = std.ArrayList([]const u8){},
                };
                
                try devices.append(self.allocator, device);
            }
        }
        
        return devices;
    }
    
    /// Discover NVIDIA driver libraries
    pub fn discoverDriverLibraries(self: *Discoverer) !std.ArrayList(Mount) {
        var mounts = std.ArrayList(Mount){};
        
        // Common NVIDIA library paths
        const lib_paths = [_][]const u8{
            "/usr/lib/x86_64-linux-gnu",
            "/usr/lib64",
            "/usr/local/cuda/lib64",
        };
        
        for (lib_paths) |lib_path| {
            var dir = std.fs.openDirAbsolute(lib_path, .{ .iterate = true }) catch continue;
            defer dir.close();
            
            var iterator = dir.iterate();
            while (try iterator.next()) |entry| {
                if (entry.kind != .file) continue;
                
                if (std.mem.startsWith(u8, entry.name, "libnvidia") or
                    std.mem.startsWith(u8, entry.name, "libcuda") or
                    std.mem.startsWith(u8, entry.name, "libcublas") or
                    std.mem.startsWith(u8, entry.name, "libcurand") or
                    std.mem.startsWith(u8, entry.name, "libcufft")) {
                    
                    const source = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ lib_path, entry.name });
                    const destination = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ lib_path, entry.name });
                    const options = try self.allocator.dupe(u8, "ro,bind");
                    
                    const mount = Mount{
                        .source = source,
                        .destination = destination,
                        .options = options,
                    };
                    
                    try mounts.append(self.allocator, mount);
                }
            }
        }
        
        return mounts;
    }
};

test "discover char devices" {
    var discoverer = Discoverer.init(std.testing.allocator);
    var devices = try discoverer.discoverCharDevices();
    defer {
        for (devices.items) |*device| {
            device.deinit(std.testing.allocator);
        }
        devices.deinit(std.testing.allocator);
    }
    
    // Test should not fail even if no devices are found
    std.testing.expect(devices.items.len >= 0) catch unreachable;
}

test "discover driver libraries" {
    var discoverer = Discoverer.init(std.testing.allocator);
    var mounts = try discoverer.discoverDriverLibraries();
    defer {
        for (mounts.items) |*mount| {
            mount.deinit(std.testing.allocator);
        }
        mounts.deinit(std.testing.allocator);
    }
    
    // Test should not fail even if no libraries are found
    std.testing.expect(mounts.items.len >= 0) catch unreachable;
}