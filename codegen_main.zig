//! Build-time entry point for the Protocol Buffer → Zig code generator.
//!
//! Zig 0.17 removed third-party custom build steps (`makeFn`): the build graph
//! must be serializable from the configurer to a separately-compiled maker
//! process, and a function pointer can't cross that boundary. The idiomatic
//! replacement is a build-time executable invoked via a `Run` step. This file
//! is that executable; `step.zig` wires it into the graph.
//!
//! It lives at the repo root (not under src/codegen/) so its module root
//! encompasses all of `src/` — gen.zig imports `../parser/...`, which must stay
//! inside the module subtree.
//!
//! Usage: gremlin-protoc-gen <proto_root> <target_root> [ignore_mask ...]

const std = @import("std");
const gen = @import("src/codegen/gen.zig");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    // argv layout: [exe, proto_root, target_root, ignore_mask...]
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 3) {
        std.process.fatal(
            "usage: gremlin-protoc-gen <proto_root> <target_root> [ignore_mask ...]",
            .{},
        );
    }

    const proto_root: []const u8 = args[1];
    const target_root: []const u8 = args[2];

    // `args` are [:0]const u8; copy the tail into a plain [][]const u8 since
    // slice-of-slice types don't coerce element-wise.
    const ignore_masks: ?[]const []const u8 = if (args.len > 3) blk: {
        const masks = try arena.alloc([]const u8, args.len - 3);
        for (args[3..], 0..) |a, i| masks[i] = a;
        break :blk masks;
    } else null;

    gen.generateProtobuf(io, arena, proto_root, target_root, ignore_masks) catch |err| {
        std.process.fatal("failed to generate protobuf code: {t}", .{err});
    };
}

test {
    std.testing.refAllDecls(gen);
}
