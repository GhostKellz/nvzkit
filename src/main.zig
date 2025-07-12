const std = @import("std");
const nvzkit = @import("nvzkit");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    // Initialize CLI
    var cli = nvzkit.cli.Cli.init(allocator) catch |err| {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Error initializing nvzkit: {}\n", .{err});
        std.process.exit(1);
    };
    defer cli.deinit();
    
    // Parse and execute command
    var cli_args = cli.parseArgs(args) catch |err| {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Error parsing arguments: {}\n", .{err});
        std.process.exit(1);
    };
    defer cli_args.deinit();
    
    cli.execute(&cli_args) catch |err| {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Error executing command: {}\n", .{err});
        std.process.exit(1);
    };
}
