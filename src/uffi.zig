const std = @import("std");

/// Check if the FFI module is supported on the current platform
pub fn Supported() bool {
    return false;
}

const clib_ffi_type = extern struct {};
const clib_ffi_cif = extern struct {
    abi: c_uint,
    nargs: c_uint,
    arg_types: [*c][*c]clib_ffi_type,
    rtype: [*c]clib_ffi_type,
    bytes: c_uint,
    flags: c_uint,
};
const clib_ffi_closure = extern struct {};

pub const CallInfo = clib_ffi_cif;

/// Error types for the FFI module
pub const PrepError = error{
    BadABI,
    BadTypeDefintion,
    BadArgumentType,
};

pub const ClosureError = error{
    AllocationFailed,
    NoExecutable,
};
/// Zig FFI types for FFI TypeDef
pub const Type = enum(usize) {
    void,
    i8,
    u8,
    i16,
    u16,
    i32,
    u32,
    i64,
    u64,
    float,
    double,
    pointer,
    unknownReturn,

    pub inline fn toNative(t: Type) [*c]clib_ffi_type {
        return switch (t) {
            else => unreachable,
        };
    }

    pub inline fn toSize(t: Type) usize {
        return switch (t) {
            .void => 0,
            .u8 => 1,
            .i8 => 1,
            .u16 => 2,
            .i16 => 2,
            .u32 => 4,
            .i32 => 4,
            .u64 => 8,
            .i64 => 8,
            .float => 4,
            .double => 8,
            .pointer => @sizeOf(*anyopaque),
            else => unreachable,
        };
    }
};

/// Zig FFI types for FFI StructDef
pub const Struct = struct {
    allocator: std.mem.Allocator,
    fields: []const GenType,
    structType: clib_ffi_type,
    structFields: [][*c]clib_ffi_type,
    offsets: []usize,

    /// Fields are in the order they appear on c structs
    pub fn init(allocator: std.mem.Allocator, fields: []const GenType) !Struct {
        _ = allocator;
        _ = fields;
        @panic("FFI is unsupported on this platform");
    }

    pub fn toNative(self: *const Struct) [*c]clib_ffi_type {
        _ = self;
        @panic("FFI is unsupported on this platform");
    }

    pub fn getType(self: *Struct) clib_ffi_type {
        _ = self;
        @panic("FFI is unsupported on this platform");
    }

    pub fn getSize(self: *Struct) usize {
        _ = self;
        @panic("FFI is unsupported on this platform");
    }

    pub fn deinit(self: *Struct) void {
        _ = self;
    }
};

pub const GenType = union(enum) {
    ffiType: Type,
    structType: Struct,
};

/// Convert a FFI type to a Zig FFI type
pub fn toffiType(t: [*c]clib_ffi_type) Type {
    _ = t;
    @panic("FFI is unsupported on this platform");
}

/// A wrapper for FFI function that can be called from Zig
pub const CallableFunction = struct {
    allocator: std.mem.Allocator,
    cif: CallInfo,
    argTypes: [][*c]clib_ffi_type,
    returnType: GenType,
    fnPtr: *const anyopaque,

    pub fn init(allocator: std.mem.Allocator, functionPtr: anytype, ffiArgTypes: []const GenType, ffiRetType: GenType) !CallableFunction {
        _ = allocator;
        _ = functionPtr;
        _ = ffiArgTypes;
        _ = ffiRetType;
        @panic("FFI is unsupported on this platform");
    }

    pub fn call(self: *CallableFunction, callArgs: []const *anyopaque) !usize {
        _ = self;
        _ = callArgs;
        @panic("FFI is unsupported on this platform");
    }

    pub fn deinit(self: *CallableFunction) void {
        _ = self;
    }
};

const CClosureFn = fn (cif: [*c]CallInfo, ret: ?*anyopaque, args: [*c]?*anyopaque, user_data: ?*anyopaque) callconv(.C) void;
const ZigClosureFn = fn (cif: CallInfo, args: []?*anyopaque, ret: ?*anyopaque) void;

pub fn toCClosureFn(comptime func: ZigClosureFn) CClosureFn {
    return struct {
        fn cfunc(cif: [*c]CallInfo, ret: ?*anyopaque, _args: [*c]?*anyopaque, user_data: ?*anyopaque) callconv(.C) void {
            _ = cif;
            _ = ret;
            _ = _args;
            _ = user_data;
            _ = func;
            @panic("FFI is unsupported on this platform");
        }
    }.cfunc;
}

/// A wrapper for FFI closure created in Zig that can be called from C
pub const CallbackClosure = struct {
    allocator: std.mem.Allocator,
    cif: CallInfo,
    closure: [*c]clib_ffi_closure,
    executable: *anyopaque,
    argTypes: [][*c]clib_ffi_type,
    returnType: GenType,
    functionPtr: *const CClosureFn,

    pub fn init(allocator: std.mem.Allocator, functionPtr: *const CClosureFn, ffiArgTypes: []const GenType, ffiRetType: GenType) !CallbackClosure {
        _ = allocator;
        _ = functionPtr;
        _ = ffiArgTypes;
        _ = ffiRetType;
        @panic("FFI is unsupported on this platform");
    }

    pub fn prep(self: *CallbackClosure) !void {
        _ = self;
        @panic("FFI is unsupported on this platform");
    }

    pub fn deinit(self: *CallbackClosure) void {
        _ = self;
    }
};
