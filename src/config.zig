//! Configuration management module
//! 
//! Handles loading and parsing of nvzkit configuration files.

const std = @import("std");

/// Runtime mode for container operations
pub const RuntimeMode = enum {
    legacy,
    csv,
    cdi,
    
    pub fn fromString(str: []const u8) ?RuntimeMode {
        if (std.mem.eql(u8, str, "legacy")) return .legacy;
        if (std.mem.eql(u8, str, "csv")) return .csv;
        if (std.mem.eql(u8, str, "cdi")) return .cdi;
        return null;
    }
    
    pub fn toString(self: RuntimeMode) []const u8 {
        return switch (self) {
            .legacy => "legacy",
            .csv => "csv",
            .cdi => "cdi",
        };
    }
};

/// Configuration for nvzkit
pub const Config = struct {
    runtime_mode: RuntimeMode,
    debug: bool,
    library_paths: std.ArrayList([]const u8),
    device_paths: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Config {
        return Config{
            .runtime_mode = .cdi,
            .debug = false,
            .library_paths = std.ArrayList([]const u8){},
            .device_paths = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Config) void {
        for (self.library_paths.items) |path| {
            self.allocator.free(path);
        }
        self.library_paths.deinit(self.allocator);
        
        for (self.device_paths.items) |path| {
            self.allocator.free(path);
        }
        self.device_paths.deinit(self.allocator);
    }
    
    /// Load default configuration
    pub fn loadDefault(allocator: std.mem.Allocator) !Config {
        var config = Config.init(allocator);
        
        // Add default library paths
        try config.library_paths.append(allocator, try allocator.dupe(u8, "/usr/lib/x86_64-linux-gnu"));
        try config.library_paths.append(allocator, try allocator.dupe(u8, "/usr/lib64"));
        try config.library_paths.append(allocator, try allocator.dupe(u8, "/usr/local/cuda/lib64"));
        
        // Add default device paths
        try config.device_paths.append(allocator, try allocator.dupe(u8, "/dev"));
        
        return config;
    }
    
    /// Load configuration from file
    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Config {
        // For now, return default config
        // TODO: Implement TOML parsing when needed
        _ = path;
        return loadDefault(allocator);
    }
};

/// Configuration manager
pub const ConfigManager = struct {
    allocator: std.mem.Allocator,
    config: Config,
    
    pub fn init(allocator: std.mem.Allocator) !ConfigManager {
        return ConfigManager{
            .allocator = allocator,
            .config = try Config.loadDefault(allocator),
        };
    }
    
    pub fn deinit(self: *ConfigManager) void {
        self.config.deinit();
    }
    
    pub fn getConfig(self: *ConfigManager) *const Config {
        return &self.config;
    }
    
    /// Update runtime mode
    pub fn setRuntimeMode(self: *ConfigManager, mode: RuntimeMode) void {
        self.config.runtime_mode = mode;
    }
    
    /// Enable or disable debug mode
    pub fn setDebug(self: *ConfigManager, debug: bool) void {
        self.config.debug = debug;
    }
};

test "config creation" {
    var config = Config.init(std.testing.allocator);
    defer config.deinit();
    
    try std.testing.expect(config.runtime_mode == .cdi);
    try std.testing.expect(config.debug == false);
}

test "config manager" {
    var manager = try ConfigManager.init(std.testing.allocator);
    defer manager.deinit();
    
    const config = manager.getConfig();
    try std.testing.expect(config.runtime_mode == .cdi);
    
    manager.setRuntimeMode(.legacy);
    try std.testing.expect(manager.getConfig().runtime_mode == .legacy);
}

test "runtime mode conversion" {
    try std.testing.expect(RuntimeMode.fromString("cdi") == .cdi);
    try std.testing.expect(RuntimeMode.fromString("legacy") == .legacy);
    try std.testing.expect(RuntimeMode.fromString("invalid") == null);
    
    try std.testing.expectEqualStrings("cdi", RuntimeMode.cdi.toString());
    try std.testing.expectEqualStrings("legacy", RuntimeMode.legacy.toString());
}