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
    var cli = nvzkit.cli.Cli.init(allocator) catch {
        try std.fs.File.stderr().writeAll("Error initializing nvzkit\n");
        std.process.exit(1);
    };
    defer cli.deinit();
    
    // Parse and execute command
    var cli_args = cli.parseArgs(args) catch {
        try std.fs.File.stderr().writeAll("Error parsing arguments\n");
        std.process.exit(1);
    };
    defer cli_args.deinit();
    
    cli.execute(&cli_args) catch {
        try std.fs.File.stderr().writeAll("Error executing command\n");
        std.process.exit(1);
    };
}
