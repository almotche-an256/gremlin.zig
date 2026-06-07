//               .'\   /`.
//             .'.-.`-'.-.`.
//        ..._:   .-. .-.   :_...
//      .'    '-.(o ) (o ).-'    `.
//     :  _    _ _`~(_)~`_ _    _  :
//    :  /:   ' .-=_   _=-. `   ;\  :
//    :   :|-.._  '     `  _..-|:   :
//     :   `:| |`:-:-.-:-:'| |:'   :
//      `.   `.| | | | | | |.'   .'
//        `.   `-:_| | |_:-'   .'
//          `-._   ````    _.-'
//              ``-------''
//
// Created by ab, 14.11.2024
// Reworked for Zig 0.17: custom build steps (makeFn) were removed, so code
// generation now runs as a build-time executable (src/codegen/main.zig)
// invoked through a `Run` step instead of an in-process custom step.

const std = @import("std");

pub const ProtoGenConfig = struct {
    name: []const u8 = "protobuf",
    proto_sources: std.Build.LazyPath,
    target: std.Build.LazyPath,
    ignore_masks: ?[]const []const u8 = null,
};

/// Build the protobuf codegen tool and return a `Run` step that invokes it.
/// Depend on the result via `&result.step`, exactly like the old custom step.
///
/// `gremlin_dep` is the gremlin dependency in the *consumer's* build graph
/// (`b.dependency("gremlin", .{})`). It is required because the codegen tool's
/// source (`codegen_main.zig`) lives inside the gremlin package, not the
/// consumer's tree — so its path must be resolved relative to the dependency
/// root, not the consumer's `b`.
///
/// The tool writes generated Zig into `config.target`; `config.proto_sources`
/// is registered as an input dependency.
pub fn create(
    b: *std.Build,
    gremlin_dep: *std.Build.Dependency,
    config: ProtoGenConfig,
) *std.Build.Step.Run {
    return createFromSource(b, gremlin_dep.path("codegen_main.zig"), config);
}

/// Lower-level entry point: wire a Run step against a codegen-tool source file
/// at `codegen_root`. Used by gremlin's own build.zig (where the source is
/// `b.path("codegen_main.zig")`); external consumers should use `create`.
pub fn createFromSource(
    b: *std.Build,
    codegen_root: std.Build.LazyPath,
    config: ProtoGenConfig,
) *std.Build.Step.Run {
    const exe = b.addExecutable(.{
        .name = "gremlin-protoc-gen",
        .root_module = b.createModule(.{
            .root_source_file = codegen_root,
            // Always build the generator for the host: it runs at build time.
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run = b.addRunArtifact(exe);
    run.setName(config.name);
    // argv: <proto_root> <target_root> [ignore_mask ...]
    run.addDirectoryArg(config.proto_sources);
    run.addDirectoryArg(config.target);
    if (config.ignore_masks) |masks| {
        for (masks) |mask| run.addArg(mask);
    }
    return run;
}
