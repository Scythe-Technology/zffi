const std = @import("std");

/// Check if the FFI module is supported on the current platform
pub fn Supported() bool {
    return true;
}

const clib = @cImport({
    @cInclude("ffi.h");
});

pub const CallInfo = clib.ffi_cif;

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

const c_ffi_type_void = &clib.ffi_type_void;
const c_ffi_type_uint8 = &clib.ffi_type_uint8;
const c_ffi_type_sint8 = &clib.ffi_type_sint8;
const c_ffi_type_uint16 = &clib.ffi_type_uint16;
const c_ffi_type_sint16 = &clib.ffi_type_sint16;
const c_ffi_type_uint32 = &clib.ffi_type_uint32;
const c_ffi_type_sint32 = &clib.ffi_type_sint32;
const c_ffi_type_uint64 = &clib.ffi_type_uint64;
const c_ffi_type_sint64 = &clib.ffi_type_sint64;
const c_ffi_type_float = &clib.ffi_type_float;
const c_ffi_type_double = &clib.ffi_type_double;
const c_ffi_type_pointer = &clib.ffi_type_pointer;

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

    pub inline fn toNative(t: Type) [*c]clib.ffi_type {
        return switch (t) {
            .void => c_ffi_type_void,
            .u8 => c_ffi_type_uint8,
            .i8 => c_ffi_type_sint8,
            .u16 => c_ffi_type_uint16,
            .i16 => c_ffi_type_sint16,
            .u32 => c_ffi_type_uint32,
            .i32 => c_ffi_type_sint32,
            .u64 => c_ffi_type_uint64,
            .i64 => c_ffi_type_sint64,
            .float => c_ffi_type_float,
            .double => c_ffi_type_double,
            .pointer => c_ffi_type_pointer,
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
    structType: clib.ffi_type,
    structFields: [][*c]clib.ffi_type,
    offsets: []usize,

    /// Fields are in the order they appear on c structs
    pub fn init(allocator: std.mem.Allocator, fields: []const GenType) !Struct {
        var structFields = try allocator.alloc([*c]clib.ffi_type, fields.len + 1);
        errdefer allocator.free(structFields);

        for (fields, 0..) |field, i| structFields[i] = switch (field) {
            .ffiType => |ffiType| ffiType.toNative(),
            .structType => |structType| structType.toNative(),
        };

        structFields[fields.len] = null;

        var structType = clib.ffi_type{
            .size = 0,
            .alignment = 0,
            .type = clib.FFI_TYPE_STRUCT,
            .elements = structFields.ptr,
        };

        const offsets = try allocator.alloc(usize, fields.len);
        errdefer allocator.free(offsets);

        const status = clib.ffi_get_struct_offsets(clib.FFI_DEFAULT_ABI, @ptrCast(&structType), offsets.ptr);
        if (status != clib.FFI_OK) {
            return if (status == clib.FFI_BAD_ABI)
                PrepError.BadABI
            else if (status == clib.FFI_BAD_TYPEDEF)
                PrepError.BadTypeDefintion
            else
                PrepError.BadArgumentType;
        }

        return .{ .allocator = allocator, .fields = fields, .structType = structType, .structFields = structFields, .offsets = offsets };
    }

    pub fn toNative(self: *const Struct) [*c]clib.ffi_type {
        return @constCast(@ptrCast(&self.structType));
    }

    pub fn getType(self: *Struct) clib.ffi_type {
        return self.structType;
    }

    pub fn getSize(self: *Struct) usize {
        return self.structType.size;
    }

    pub fn deinit(self: *Struct) void {
        self.allocator.free(self.structFields);
        self.allocator.free(self.offsets);
    }
};

pub const GenType = union(enum) {
    ffiType: Type,
    structType: Struct,
};

/// Convert a FFI type to a Zig FFI type
pub fn toffiType(t: [*c]clib.ffi_type) Type {
    if (t == c_ffi_type_void) {
        return Type.void;
    } else if (t == c_ffi_type_uint8) {
        return Type.u8;
    } else if (t == c_ffi_type_sint8) {
        return Type.i8;
    } else if (t == c_ffi_type_uint16) {
        return Type.u16;
    } else if (t == c_ffi_type_sint16) {
        return Type.i16;
    } else if (t == c_ffi_type_uint32) {
        return Type.u32;
    } else if (t == c_ffi_type_sint32) {
        return Type.i32;
    } else if (t == c_ffi_type_uint64) {
        return Type.u64;
    } else if (t == c_ffi_type_sint64) {
        return Type.i64;
    } else if (t == c_ffi_type_float) {
        return Type.float;
    } else if (t == c_ffi_type_double) {
        return Type.double;
    } else if (t == c_ffi_type_pointer) {
        return Type.pointer;
    } else {
        return Type.unknownReturn;
    }
}

/// A wrapper for FFI function that can be called from Zig
pub const CallableFunction = struct {
    allocator: std.mem.Allocator,
    cif: CallInfo,
    argTypes: [][*c]clib.ffi_type,
    returnType: GenType,
    fnPtr: *const anyopaque,

    pub fn init(allocator: std.mem.Allocator, functionPtr: anytype, ffiArgTypes: []const GenType, ffiRetType: GenType) !CallableFunction {
        var cif: CallInfo = undefined;

        var argTypes = try allocator.alloc([*c]clib.ffi_type, ffiArgTypes.len + 1);
        errdefer allocator.free(argTypes);

        for (ffiArgTypes, 0..) |argType, i| argTypes[i] = switch (argType) {
            .ffiType => |ffiType| ffiType.toNative(),
            .structType => |structType| structType.toNative(),
        };

        argTypes[ffiArgTypes.len] = null;

        const ret = clib.ffi_prep_cif(&cif, clib.FFI_DEFAULT_ABI, @intCast(ffiArgTypes.len), switch (ffiRetType) {
            .ffiType => |ffiType| ffiType.toNative(),
            .structType => |structType| structType.toNative(),
        }, argTypes.ptr);
        if (ret != clib.FFI_OK) {
            return if (ret == clib.FFI_BAD_ABI)
                PrepError.BadABI
            else if (ret == clib.FFI_BAD_TYPEDEF)
                PrepError.BadTypeDefintion
            else
                PrepError.BadArgumentType;
        }

        return .{
            .allocator = allocator,
            .cif = cif,
            .argTypes = argTypes,
            .returnType = ffiRetType,
            .fnPtr = @ptrCast(functionPtr),
        };
    }

    pub fn call(self: *CallableFunction, callArgs: []const *anyopaque) !usize {
        if (callArgs.len != self.argTypes.len - 1) return PrepError.BadArgumentType;
        var retValue: usize = undefined;
        clib.ffi_call(@ptrCast(&self.cif), @as(*const fn () callconv(.C) void, @ptrCast(self.fnPtr)), &retValue, @constCast(@ptrCast(callArgs.ptr)));
        return retValue;
    }

    pub fn deinit(self: *CallableFunction) void {
        self.allocator.free(self.argTypes);
    }
};

const CClosureFn = fn (cif: [*c]CallInfo, ret: ?*anyopaque, args: [*c]?*anyopaque, user_data: ?*anyopaque) callconv(.C) void;
const ZigClosureFn = fn (cif: CallInfo, args: []?*anyopaque, ret: ?*anyopaque) void;

pub fn toCClosureFn(comptime func: ZigClosureFn) CClosureFn {
    return struct {
        fn cfunc(cif: [*c]CallInfo, ret: ?*anyopaque, _args: [*c]?*anyopaque, user_data: ?*anyopaque) callconv(.C) void {
            const callInfo = cif.*;
            _ = user_data;
            const args: []?*anyopaque = _args[0..callInfo.nargs];
            @call(.always_inline, func, .{ callInfo, args, ret });
        }
    }.cfunc;
}

/// A wrapper for FFI closure created in Zig that can be called from C
pub const CallbackClosure = struct {
    allocator: std.mem.Allocator,
    cif: CallInfo,
    closure: [*c]clib.ffi_closure,
    executable: *anyopaque,
    argTypes: [][*c]clib.ffi_type,
    returnType: GenType,
    functionPtr: *const CClosureFn,

    pub fn init(allocator: std.mem.Allocator, functionPtr: *const CClosureFn, ffiArgTypes: []const GenType, ffiRetType: GenType) !CallbackClosure {
        var cif: CallInfo = undefined;
        var executableFn: ?*anyopaque = undefined;

        var argTypes = try allocator.alloc([*c]clib.ffi_type, ffiArgTypes.len + 1);
        errdefer allocator.free(argTypes);

        const closure = clib.ffi_closure_alloc(@sizeOf(clib.ffi_closure), @ptrCast(&executableFn)) orelse return ClosureError.AllocationFailed;
        errdefer clib.ffi_closure_free(closure);

        for (ffiArgTypes, 0..) |argType, i| argTypes[i] = switch (argType) {
            .ffiType => |ffiType| ffiType.toNative(),
            .structType => |structType| structType.toNative(),
        };

        argTypes[ffiArgTypes.len] = null;

        const ret = clib.ffi_prep_cif(&cif, clib.FFI_DEFAULT_ABI, @intCast(ffiArgTypes.len), switch (ffiRetType) {
            .ffiType => |ffiType| ffiType.toNative(),
            .structType => |structType| structType.toNative(),
        }, argTypes.ptr);
        if (ret != clib.FFI_OK) {
            return if (ret == clib.FFI_BAD_ABI)
                PrepError.BadABI
            else if (ret == clib.FFI_BAD_TYPEDEF)
                PrepError.BadTypeDefintion
            else
                PrepError.BadArgumentType;
        }

        return .{
            .allocator = allocator,
            .cif = cif,
            .closure = @ptrCast(@alignCast(closure)),
            .argTypes = argTypes,
            .returnType = ffiRetType,
            .executable = executableFn orelse return ClosureError.NoExecutable,
            .functionPtr = functionPtr,
        };
    }

    pub fn prep(self: *CallbackClosure) !void {
        const status = clib.ffi_prep_closure_loc(self.closure, &self.cif, self.functionPtr, null, self.executable);
        if (status != clib.FFI_OK) {
            return if (status == clib.FFI_BAD_ABI)
                PrepError.BadABI
            else if (status == clib.FFI_BAD_TYPEDEF)
                PrepError.BadTypeDefintion
            else
                PrepError.BadArgumentType;
        }
    }

    pub fn deinit(self: *CallbackClosure) void {
        clib.ffi_closure_free(self.closure);
        self.allocator.free(self.argTypes);
    }
};
