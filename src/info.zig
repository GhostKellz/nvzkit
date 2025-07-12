//! System information module
//! 
//! Gathers information about NVIDIA drivers, GPUs, and system configuration.

const std = @import("std");
const discover = @import("discover.zig");

/// System information about NVIDIA setup
pub const SystemInfo = struct {
    driver_version: ?[]const u8,
    cuda_version: ?[]const u8,
    gpu_count: u32,
    devices: std.ArrayList(discover.GpuDevice),
    libraries: std.ArrayList(discover.Mount),
    
    pub fn deinit(self: *SystemInfo, allocator: std.mem.Allocator) void {
        if (self.driver_version) |version| {
            allocator.free(version);
        }
        if (self.cuda_version) |version| {
            allocator.free(version);
        }
        
        for (self.devices.items) |*device| {
            device.deinit(allocator);
        }
        self.devices.deinit();
        
        for (self.libraries.items) |*lib| {
            lib.deinit(allocator);
        }
        self.libraries.deinit();
    }
};

/// Information gatherer
pub const InfoGatherer = struct {
    allocator: std.mem.Allocator,
    discoverer: discover.Discoverer,
    
    pub fn init(allocator: std.mem.Allocator) InfoGatherer {
        return InfoGatherer{
            .allocator = allocator,
            .discoverer = discover.Discoverer.init(allocator),
        };
    }
    
    /// Gather comprehensive system information
    pub fn gatherSystemInfo(self: *InfoGatherer) !SystemInfo {
        var info = SystemInfo{
            .driver_version = null,
            .cuda_version = null,
            .gpu_count = 0,
            .devices = try self.discoverer.discoverCharDevices(),
            .libraries = try self.discoverer.discoverDriverLibraries(),
        };
        
        info.gpu_count = @intCast(info.devices.items.len);
        
        // Try to get driver version from nvidia-smi
        info.driver_version = self.getDriverVersion() catch null;
        
        // Try to get CUDA version from nvcc
        info.cuda_version = self.getCudaVersion() catch null;
        
        return info;
    }
    
    /// Get NVIDIA driver version
    fn getDriverVersion(self: *InfoGatherer) ![]const u8 {
        var child = std.process.Child.init(&[_][]const u8{ "nvidia-smi", "--query-gpu=driver_version", "--format=csv,noheader" }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;
        
        try child.spawn();
        const stdout = try child.stdout.?.readToEndAlloc(self.allocator, 1024);
        defer self.allocator.free(stdout);
        
        _ = try child.wait();
        
        // Remove trailing newline
        const trimmed = std.mem.trim(u8, stdout, " \n\r\t");
        return self.allocator.dupe(u8, trimmed);
    }
    
    /// Get CUDA version
    fn getCudaVersion(self: *InfoGatherer) ![]const u8 {
        var child = std.process.Child.init(&[_][]const u8{ "nvcc", "--version" }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;
        
        try child.spawn();
        const stdout = try child.stdout.?.readToEndAlloc(self.allocator, 1024);
        defer self.allocator.free(stdout);
        
        _ = try child.wait();
        
        // Parse version from nvcc output
        if (std.mem.indexOf(u8, stdout, "release ")) |pos| {
            const version_start = pos + 8;
            if (std.mem.indexOf(u8, stdout[version_start..], ",")) |end| {
                const version = stdout[version_start..version_start + end];
                return self.allocator.dupe(u8, version);
            }
        }
        
        return error.VersionNotFound;
    }
    
    /// Print system information to stdout
    pub fn printSystemInfo(self: *InfoGatherer) !void {
        var info = try self.gatherSystemInfo();
        defer info.deinit(self.allocator);
        
        const stdout = std.io.getStdOut().writer();
        
        try stdout.print("=== NVIDIA Container Toolkit Information ===\n", .{});
        try stdout.print("Driver Version: {s}\n", .{info.driver_version orelse "Unknown"});
        try stdout.print("CUDA Version: {s}\n", .{info.cuda_version orelse "Unknown"});
        try stdout.print("GPU Count: {d}\n", .{info.gpu_count});
        
        if (info.devices.items.len > 0) {
            try stdout.print("\nGPU Devices:\n", .{});
            for (info.devices.items) |device| {
                try stdout.print("  - {s}\n", .{device.device_path});
            }
        }
        
        if (info.libraries.items.len > 0) {
            try stdout.print("\nNVIDIA Libraries Found: {d}\n", .{info.libraries.items.len});
        }
    }
};

test "info gatherer creation" {
    const gatherer = InfoGatherer.init(std.testing.allocator);
    _ = gatherer;
}

test "gather system info" {
    var gatherer = InfoGatherer.init(std.testing.allocator);
    var info = try gatherer.gatherSystemInfo();
    defer info.deinit(std.testing.allocator);
    
    // Should complete without error regardless of system state
    std.testing.expect(info.gpu_count >= 0) catch unreachable;
}