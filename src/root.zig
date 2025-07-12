//! nvzkit - NVIDIA Container Toolkit port to Zig
//! 
//! This library provides functionality to enable GPU access in containers
//! by discovering NVIDIA devices, mounting driver libraries, and configuring
//! container runtimes.

const std = @import("std");

// Core modules
pub const discover = @import("discover.zig");
pub const runtime = @import("runtime.zig");
pub const config = @import("config.zig");
pub const info = @import("info.zig");
pub const cli = @import("cli.zig");

// Version information
pub const version = "0.1.0";

test "nvzkit module imports" {
    _ = discover;
    _ = runtime;
    _ = config;
    _ = info;
    _ = cli;
}
