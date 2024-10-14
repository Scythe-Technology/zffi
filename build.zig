const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = target.result;

    const safe_build = b.option(bool, "safe_build", "Build regardless if the device doesn't support ffi") orelse false;

    const ffiModule = b.addModule("ffi", .{
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "zffi",
        .target = target,
        .optimize = optimize,
        .version = std.SemanticVersion{ .major = 0, .minor = 0, .patch = 1 },
    });

    lib.linkLibCpp();

    ffiModule.linkLibrary(lib);

    var ffiSupported = false;
    // Credit to https://github.com/vezel-dev/graf/blob/ff694e720cece7b7386c85e2f9beea9e889b51b5/build.zig#L127
    // TODO: https://github.com/ziglang/zig/issues/20361
    if (!t.isDarwin() and switch (t.cpu.arch) {
        // libffi only supports MSVC for Windows on Arm.
        .aarch64, .aarch64_be, .aarch64_32 => t.os.tag != .windows,
        // TODO: https://github.com/ziglang/zig/issues/10411
        .arm, .armeb => t.getFloatAbi() != .soft and t.os.tag != .windows,
        // TODO: https://github.com/llvm/llvm-project/issues/58377
        .mips, .mipsel, .mips64, .mips64el => false,
        // TODO: https://github.com/ziglang/zig/issues/20376
        .powerpc, .powerpcle => !t.isGnuLibC(),
        // TODO: https://github.com/ziglang/zig/issues/19107
        .riscv32, .riscv64 => !t.isGnuLibC(),
        else => true,
    }) {
        const ffi_dep = b.dependency("libffi", .{
            .target = target,
            .optimize = optimize,
        });
        const bffiLib = ffi_dep.artifact("ffi");
        lib.linkLibrary(bffiLib);
        ffiModule.addIncludePath(bffiLib.getEmittedIncludeTree());
        ffiSupported = true;
    } else {
        if (!safe_build) @panic("This device doesn't support ffi");
    }

    if (ffiSupported) {
        ffiModule.root_source_file = b.path("src/ffi.zig");
        lib.root_module.root_source_file = b.path("src/ffi.zig");
    } else {
        ffiModule.root_source_file = b.path("src/uffi.zig");
        lib.root_module.root_source_file = b.path("src/uffi.zig");
    }

    b.installArtifact(lib);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    unit_tests.linkLibC();
    unit_tests.addIncludePath(b.path("src/tests"));
    unit_tests.addCSourceFile(.{
        .file = b.path("src/tests/basic.c"),
    });

    unit_tests.root_module.addImport("ffi", ffiModule);

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const docs = b.addStaticLibrary(.{
        .name = "ffi",
        .target = target,
        .optimize = optimize,
    });

    if (ffiSupported) {
        docs.root_module.root_source_file = b.path("src/ffi.zig");
    } else {
        docs.root_module.root_source_file = b.path("src/uffi.zig");
    }

    docs.linkLibrary(lib);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Build and install the documentation");
    docs_step.dependOn(&install_docs.step);
}
