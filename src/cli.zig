//! Command line interface module
//! 
//! Provides the main CLI interface for nvzkit with subcommands for
//! info, run, shell, and other operations.

const std = @import("std");
const info = @import("info.zig");
const runtime = @import("runtime.zig");
const config = @import("config.zig");
const discover = @import("discover.zig");

/// CLI command types
const Command = enum {
    info,
    run,
    shell,
    help,
};

/// CLI arguments structure
pub const CliArgs = struct {
    command: Command,
    verbose: bool,
    runtime_mode: ?config.RuntimeMode,
    container_args: std.ArrayList([]const u8),
    
    pub fn deinit(self: *CliArgs) void {
        self.container_args.deinit();
    }
};

/// Main CLI handler
pub const Cli = struct {
    allocator: std.mem.Allocator,
    config_manager: config.ConfigManager,
    
    pub fn init(allocator: std.mem.Allocator) !Cli {
        return Cli{
            .allocator = allocator,
            .config_manager = try config.ConfigManager.init(allocator),
        };
    }
    
    pub fn deinit(self: *Cli) void {
        self.config_manager.deinit();
    }
    
    /// Parse command line arguments
    pub fn parseArgs(self: *Cli, args: []const []const u8) !CliArgs {
        var cli_args = CliArgs{
            .command = .help,
            .verbose = false,
            .runtime_mode = null,
            .container_args = std.ArrayList([]const u8).init(self.allocator),
        };
        
        if (args.len < 2) {
            return cli_args;
        }
        
        // Parse command
        if (std.mem.eql(u8, args[1], "info")) {
            cli_args.command = .info;
        } else if (std.mem.eql(u8, args[1], "run")) {
            cli_args.command = .run;
        } else if (std.mem.eql(u8, args[1], "shell")) {
            cli_args.command = .shell;
        } else if (std.mem.eql(u8, args[1], "help") or std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
            cli_args.command = .help;
        }
        
        // Parse flags
        var i: usize = 2;
        while (i < args.len) {
            if (std.mem.eql(u8, args[i], "--verbose") or std.mem.eql(u8, args[i], "-v")) {
                cli_args.verbose = true;
            } else if (std.mem.eql(u8, args[i], "--runtime-mode")) {
                i += 1;
                if (i < args.len) {
                    cli_args.runtime_mode = config.RuntimeMode.fromString(args[i]);
                }
            } else {
                // Remaining args are container arguments
                try cli_args.container_args.append(args[i]);
            }
            i += 1;
        }
        
        return cli_args;
    }
    
    /// Execute the parsed command
    pub fn execute(self: *Cli, cli_args: *CliArgs) !void {
        // Update config with CLI args
        if (cli_args.runtime_mode) |mode| {
            self.config_manager.setRuntimeMode(mode);
        }
        self.config_manager.setDebug(cli_args.verbose);
        
        switch (cli_args.command) {
            .info => try self.executeInfo(),
            .run => try self.executeRun(cli_args.container_args.items),
            .shell => try self.executeShell(cli_args.container_args.items),
            .help => try self.executeHelp(),
        }
    }
    
    /// Execute info command
    fn executeInfo(self: *Cli) !void {
        var gatherer = info.InfoGatherer.init(self.allocator);
        try gatherer.printSystemInfo();
    }
    
    /// Execute run command
    fn executeRun(self: *Cli, container_args: []const []const u8) !void {
        if (container_args.len == 0) {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Error: No container image specified\n", .{});
            try stderr.print("Usage: nvzkit run <image> [args...]\n", .{});
            return;
        }
        
        // Build docker/podman command
        var cmd_args = std.ArrayList([]const u8).init(self.allocator);
        defer cmd_args.deinit();
        
        // Detect container runtime
        const runtime_cmd = self.detectContainerRuntime() catch "docker";
        try cmd_args.append(runtime_cmd);
        try cmd_args.append("run");
        try cmd_args.append("--gpus");
        try cmd_args.append("all");
        
        // Add container arguments
        for (container_args) |arg| {
            try cmd_args.append(arg);
        }
        
        // Execute container runtime
        var child = std.process.Child.init(cmd_args.items, self.allocator);
        const result = try child.spawnAndWait();
        
        switch (result) {
            .Exited => |code| {
                std.process.exit(code);
            },
            else => {
                std.process.exit(1);
            },
        }
    }
    
    /// Execute shell command
    fn executeShell(self: *Cli, container_args: []const []const u8) !void {
        var shell_args = std.ArrayList([]const u8).init(self.allocator);
        defer shell_args.deinit();
        
        // Add shell arguments
        if (container_args.len > 0) {
            for (container_args) |arg| {
                try shell_args.append(arg);
            }
        } else {
            // Default to nvidia/cuda image
            try shell_args.append("nvidia/cuda:latest");
        }
        
        // Add interactive shell flags
        try shell_args.append("/bin/bash");
        
        // Execute run command with shell
        try self.executeRun(shell_args.items);
    }
    
    /// Execute help command
    fn executeHelp(_: *Cli) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("nvzkit - NVIDIA Container Toolkit (Zig)\n\n", .{});
        try stdout.print("USAGE:\n", .{});
        try stdout.print("    nvzkit <COMMAND> [OPTIONS]\n\n", .{});
        try stdout.print("COMMANDS:\n", .{});
        try stdout.print("    info      Display system information about NVIDIA GPUs and drivers\n", .{});
        try stdout.print("    run       Run a container with GPU access\n", .{});
        try stdout.print("    shell     Start an interactive shell in a GPU-enabled container\n", .{});
        try stdout.print("    help      Show this help message\n\n", .{});
        try stdout.print("OPTIONS:\n", .{});
        try stdout.print("    -v, --verbose         Enable verbose output\n", .{});
        try stdout.print("    --runtime-mode MODE   Set runtime mode (legacy, csv, cdi)\n", .{});
        try stdout.print("    -h, --help            Show help\n\n", .{});
        try stdout.print("EXAMPLES:\n", .{});
        try stdout.print("    nvzkit info\n", .{});
        try stdout.print("    nvzkit run nvidia/cuda:latest nvidia-smi\n", .{});
        try stdout.print("    nvzkit shell nvidia/cuda:latest\n", .{});
    }
    
    /// Detect available container runtime
    fn detectContainerRuntime(self: *Cli) ![]const u8 {
        
        // Try podman first, then docker
        const runtimes = [_][]const u8{ "podman", "docker" };
        
        for (runtimes) |runtime_cmd| {
            var child = std.process.Child.init(&[_][]const u8{ "which", runtime_cmd }, self.allocator);
            child.stdout_behavior = .Ignore;
            child.stderr_behavior = .Ignore;
            
            const result = child.spawnAndWait() catch continue;
            
            switch (result) {
                .Exited => |code| {
                    if (code == 0) {
                        return runtime_cmd;
                    }
                },
                else => continue,
            }
        }
        
        return error.NoContainerRuntimeFound;
    }
};

test "cli creation" {
    var cli = try Cli.init(std.testing.allocator);
    defer cli.deinit();
}

test "parse args info command" {
    var cli = try Cli.init(std.testing.allocator);
    defer cli.deinit();
    
    const args = [_][]const u8{ "nvzkit", "info" };
    var cli_args = try cli.parseArgs(&args);
    defer cli_args.deinit();
    
    try std.testing.expect(cli_args.command == .info);
    try std.testing.expect(cli_args.verbose == false);
}

test "parse args with verbose flag" {
    var cli = try Cli.init(std.testing.allocator);
    defer cli.deinit();
    
    const args = [_][]const u8{ "nvzkit", "info", "--verbose" };
    var cli_args = try cli.parseArgs(&args);
    defer cli_args.deinit();
    
    try std.testing.expect(cli_args.command == .info);
    try std.testing.expect(cli_args.verbose == true);
}