const std = @import("std");
const ffi = @import("ffi");

const c = @cImport({
    @cInclude("basic.h");
});

test "simple ffi" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;
    const nativeFunction = struct {
        fn cfn(short: i16, char: u16, int: i32, float: f32, long: i64) callconv(.C) i32 {
            std.testing.expectEqual(0x1234, short) catch unreachable;
            std.testing.expectEqual(0x5678, char) catch unreachable;
            std.testing.expectEqual(0x12345678, int) catch unreachable;
            std.testing.expectEqual(3.14, float) catch unreachable;
            std.testing.expectEqual(0x12121212_24242424, long) catch unreachable;

            return 123;
        }
    }.cfn;

    var ffiFunc = try ffi.CallableFunction.init(allocator, &nativeFunction, &.{ .{ .ffiType = ffi.Type.i16 }, .{ .ffiType = ffi.Type.u16 }, .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.float }, .{ .ffiType = ffi.Type.i64 } }, .{ .ffiType = ffi.Type.i32 });
    defer ffiFunc.deinit();

    var arg1: i16 = 0x1234;
    var arg2: u16 = 0x5678;
    var arg3: i32 = 0x12345678;
    var arg4: f32 = 3.14;
    var arg5: i64 = 0x12121212_24242424;

    const ret = try ffiFunc.call(&.{
        &arg1, &arg2, &arg3, &arg4, &arg5,
    });
    defer ffiFunc.free(ret);

    try std.testing.expect(std.mem.readVarInt(i32, ret, .little) == 123);
}

test "simple ffi with void return" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;
    const nativeFunction = struct {
        fn cfn(b: i8) callconv(.C) void {
            _ = b;
        }
    }.cfn;

    var ffiFunc = try ffi.CallableFunction.init(allocator, &nativeFunction, &.{}, .{ .ffiType = ffi.Type.void });
    defer ffiFunc.deinit();

    _ = try ffiFunc.call(&.{});
}

test "simple ffi with param underflow" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;
    const nativeFunction = struct {
        fn cfn(a: i8, b: i8) callconv(.C) void {
            _ = b;
            std.testing.expectEqual(1, a) catch unreachable;
        }
    }.cfn;

    var ffiFunc = try ffi.CallableFunction.init(allocator, &nativeFunction, &.{.{ .ffiType = ffi.Type.i8 }}, .{ .ffiType = ffi.Type.void });
    defer ffiFunc.deinit();

    var arg1: i8 = 1;
    _ = try ffiFunc.call(&.{&arg1});
}

test "simple ffi with param overflow" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;
    const nativeFunction = struct {
        fn cfn(a: i8) callconv(.C) void {
            std.testing.expectEqual(1, a) catch unreachable;
        }
    }.cfn;

    var ffiFunc = try ffi.CallableFunction.init(allocator, &nativeFunction, &.{ .{ .ffiType = ffi.Type.i8 }, .{ .ffiType = ffi.Type.i8 } }, .{ .ffiType = ffi.Type.void });
    defer ffiFunc.deinit();

    var arg1: i8 = 1;
    var arg2: i8 = 2;
    _ = try ffiFunc.call(&.{ &arg1, &arg2 });
}

test "c basic ffi - int add(int a, int b)" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;

    var ffiFunc = try ffi.CallableFunction.init(allocator, &c.add, &.{ .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.i32 });
    defer ffiFunc.deinit();

    var arg1: i32 = 1;
    var arg2: i32 = 1;
    const result = try ffiFunc.call(&.{ &arg1, &arg2 });
    defer ffiFunc.free(result);

    try std.testing.expectEqual(2, std.mem.readVarInt(i32, result, .little));
}

test "c basic ffi - int check(int a, int b);" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;

    var ffiFunc = try ffi.CallableFunction.init(allocator, &c.check, &.{ .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.i32 });
    defer ffiFunc.deinit();

    var arg1a: i32 = 1;
    var arg2a: i32 = 2;
    const resulta = try ffiFunc.call(&.{ &arg1a, &arg2a });
    defer ffiFunc.free(resulta);

    try std.testing.expectEqual(0, std.mem.readVarInt(i32, resulta, .little));

    var arg1b: i32 = 500;
    var arg2b: i32 = 500;
    const resultb = try ffiFunc.call(&.{ &arg1b, &arg2b });
    defer ffiFunc.free(resultb);

    try std.testing.expectEqual(1, std.mem.readVarInt(i32, resultb, .little));
}

test "c basic ffi - void set(int *a, int b);" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;

    var ffiFunc = try ffi.CallableFunction.init(allocator, &c.set, &.{ .{ .ffiType = ffi.Type.pointer }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.void });
    defer ffiFunc.deinit();

    var arg1: i32 = 1;
    var arg2: i32 = 345;
    _ = try ffiFunc.call(&.{ @constCast(@ptrCast(&&arg1)), &arg2 });

    try std.testing.expectEqual(345, arg1);
}

test "c basic ffi - int runOpFunc(opFunc op, int a, int b);" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;

    var ffiFunc = try ffi.CallableFunction.init(allocator, &c.runOpFunc, &.{ .{ .ffiType = ffi.Type.pointer }, .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.i32 });
    defer ffiFunc.deinit();

    var arg1: i32 = 10;
    var arg2: i32 = 2;
    const res = try ffiFunc.call(&.{ @constCast(@ptrCast(&&c.add)), &arg1, &arg2 });
    defer ffiFunc.free(res);

    try std.testing.expectEqual(12, std.mem.readVarInt(i32, res, .little));
}

test "closure basic ffi - int runOpFunc(opFunc op, int a, int b);" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;

    const closureFunction = struct {
        fn cfn(cif: [*c]ffi.CallInfo, _ret: ?*anyopaque, _args: [*c]?*anyopaque, user_data: ?*anyopaque) callconv(.C) void {
            std.testing.expectEqual(2, cif.*.nargs) catch unreachable;
            const ret = _ret orelse unreachable;
            _ = user_data;
            const args: []?*anyopaque = _args[0..cif.*.nargs];
            const a: *i32 = @ptrCast(@alignCast((args[0] orelse unreachable)));
            std.testing.expectEqual(10, a.*) catch unreachable;
            const b: *i32 = @ptrCast(@alignCast((args[1] orelse unreachable)));
            std.testing.expect(b.* == 2 or b.* == 5) catch unreachable;
            const res: i32 = @divFloor(a.*, b.*);
            @as(*i32, @ptrCast(@alignCast(ret))).* = res;
        }
    }.cfn;

    var closure = try ffi.CallbackClosure.init(allocator, &closureFunction, &.{ .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.i32 });
    defer closure.deinit();

    var ffiFunc = try ffi.CallableFunction.init(allocator, &c.runOpFunc, &.{ .{ .ffiType = ffi.Type.pointer }, .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.i32 });
    defer ffiFunc.deinit();

    var arg1: i32 = 10;
    var arg2: i32 = 2;

    try closure.prep();
    const res = try ffiFunc.call(&.{ @ptrCast(&closure.executable), &arg1, &arg2 });
    defer ffiFunc.free(res);
    arg2 = 5;
    const res2 = try ffiFunc.call(&.{ @ptrCast(&closure.executable), &arg1, &arg2 });
    defer ffiFunc.free(res2);

    try std.testing.expectEqual(5, std.mem.readVarInt(i32, res, .little));
    try std.testing.expectEqual(2, std.mem.readVarInt(i32, res2, .little));
}

test "closure basic ffi - int runOpFunc(opFunc op, int a, int b); Zig Style" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;

    const closureFunction = struct {
        fn cfn(cif: ffi.CallInfo, args: []?*anyopaque, _ret: ?*anyopaque) void {
            std.testing.expectEqual(2, cif.nargs) catch unreachable;
            std.testing.expectEqual(2, args.len) catch unreachable;
            const ret = _ret orelse unreachable;
            const a: *i32 = @ptrCast(@alignCast((args[0] orelse unreachable)));
            std.testing.expectEqual(10, a.*) catch unreachable;
            const b: *i32 = @ptrCast(@alignCast((args[1] orelse unreachable)));
            std.testing.expect(b.* == 2 or b.* == 3) catch unreachable;
            const res: i32 = (a.*) * (b.*) + 1;
            @as(*i32, @ptrCast(@alignCast(ret))).* = res;
        }
    }.cfn;

    var closure = try ffi.CallbackClosure.init(allocator, &ffi.toCClosureFn(closureFunction), &.{ .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.i32 });
    defer closure.deinit();

    var ffiFunc = try ffi.CallableFunction.init(allocator, &c.runOpFunc, &.{ .{ .ffiType = ffi.Type.pointer }, .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.i32 });
    defer ffiFunc.deinit();

    var arg1: i32 = 10;
    var arg2: i32 = 2;

    try closure.prep();
    const res = try ffiFunc.call(&.{ @ptrCast(&closure.executable), &arg1, &arg2 });
    defer ffiFunc.free(res);
    arg2 = 3;
    const res2 = try ffiFunc.call(&.{ @ptrCast(&closure.executable), &arg1, &arg2 });
    defer ffiFunc.free(res2);

    try std.testing.expectEqual(21, std.mem.readVarInt(i32, res, .little));
    try std.testing.expectEqual(31, std.mem.readVarInt(i32, res2, .little));
}

const sampleStructA = extern struct {
    a: i32, // int
    b: i32, // int
    c: i8, // char
    d: f32, // float
    e: i64, // long
};

const sampleStructB = extern struct {
    a: i32, // int
    b: sampleStructA, // struct
};

test "structure basic ffi" {
    if (!ffi.Supported()) return;
    const allocator = std.testing.allocator;

    var ffiStructA = try ffi.Struct.init(allocator, &.{ .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i32 }, .{ .ffiType = ffi.Type.i8 }, .{ .ffiType = ffi.Type.float }, .{ .ffiType = ffi.Type.i64 } });
    defer ffiStructA.deinit();

    try std.testing.expectEqual(@sizeOf(sampleStructA), ffiStructA.getSize());
    try std.testing.expectEqual(@offsetOf(sampleStructA, "a"), ffiStructA.offsets[0]);
    try std.testing.expectEqual(@offsetOf(sampleStructA, "b"), ffiStructA.offsets[1]);
    try std.testing.expectEqual(@offsetOf(sampleStructA, "c"), ffiStructA.offsets[2]);
    try std.testing.expectEqual(@offsetOf(sampleStructA, "d"), ffiStructA.offsets[3]);
    try std.testing.expectEqual(@offsetOf(sampleStructA, "e"), ffiStructA.offsets[4]);

    const structObjectA = try allocator.alloc(u8, ffiStructA.getSize());
    defer allocator.free(structObjectA);

    const aVarA: [4]u8 = @bitCast(@as(i32, 1));
    const bVarA: [4]u8 = @bitCast(@as(i32, 2));
    const cVarA: [1]u8 = @bitCast(@as(i8, 44));
    const dVarA: [4]u8 = @bitCast(@as(f32, 3.14));
    const eVarA: [8]u8 = @bitCast(@as(i64, 0x12121212_24242424));
    @memcpy(structObjectA[ffiStructA.offsets[0] .. ffiStructA.offsets[0] + 4], aVarA[0..4]);
    @memcpy(structObjectA[ffiStructA.offsets[1] .. ffiStructA.offsets[1] + 4], bVarA[0..4]);
    @memcpy(structObjectA[ffiStructA.offsets[2] .. ffiStructA.offsets[2] + 1], cVarA[0..1]);
    @memcpy(structObjectA[ffiStructA.offsets[3] .. ffiStructA.offsets[3] + 4], dVarA[0..4]);
    @memcpy(structObjectA[ffiStructA.offsets[4] .. ffiStructA.offsets[4] + 8], eVarA[0..8]);

    const castStructA: *sampleStructA = @ptrCast(@alignCast(structObjectA.ptr));
    try std.testing.expectEqual(1, castStructA.a);
    try std.testing.expectEqual(2, castStructA.b);
    try std.testing.expectEqual(44, castStructA.c);
    try std.testing.expectEqual(3.14, castStructA.d);
    try std.testing.expectEqual(0x12121212_24242424, castStructA.e);

    var ffiStructB = try ffi.Struct.init(allocator, &.{ .{ .ffiType = ffi.Type.i32 }, .{ .structType = ffiStructA } });
    defer ffiStructB.deinit();

    try std.testing.expectEqual(@sizeOf(sampleStructB), ffiStructB.getSize());
    try std.testing.expectEqual(@offsetOf(sampleStructB, "a"), ffiStructB.offsets[0]);
    try std.testing.expectEqual(@offsetOf(sampleStructB, "b"), ffiStructB.offsets[1]);

    const structObjectB = try allocator.alloc(u8, ffiStructB.getSize());
    defer allocator.free(structObjectB);

    const aVarB: [4]u8 = @bitCast(@as(i32, 3));
    @memcpy(structObjectB[ffiStructB.offsets[0] .. ffiStructB.offsets[0] + 4], aVarB[0..4]);
    @memcpy(structObjectB[ffiStructB.offsets[1] .. ffiStructB.offsets[1] + ffiStructA.getSize()], structObjectA[0..ffiStructA.getSize()]);

    const castStructB: *sampleStructB = @ptrCast(@alignCast(structObjectB.ptr));

    try std.testing.expectEqual(3, castStructB.a);
    try std.testing.expectEqual(1, castStructB.b.a);
    try std.testing.expectEqual(2, castStructB.b.b);
    try std.testing.expectEqual(44, castStructB.b.c);
    try std.testing.expectEqual(3.14, castStructB.b.d);
    try std.testing.expectEqual(0x12121212_24242424, castStructB.b.e);
}

test "structure basic ffi function" {
    if (!ffi.Supported()) return;
    // struct simpleUnknownStruct
    // {
    //     char a;
    //     float b;
    //     int c;
    // };

    const allocator = std.testing.allocator;

    var ffiStruct = try ffi.Struct.init(allocator, &.{ .{ .ffiType = ffi.Type.i8 }, .{ .ffiType = ffi.Type.float }, .{ .ffiType = ffi.Type.i32 } });
    defer ffiStruct.deinit();

    var ffiFunc = try ffi.CallableFunction.init(allocator, &c.validateStruct, &.{ .{ .ffiType = ffi.Type.pointer }, .{ .ffiType = ffi.Type.i8 }, .{ .ffiType = ffi.Type.float }, .{ .ffiType = ffi.Type.i32 } }, .{ .ffiType = ffi.Type.i32 });
    defer ffiFunc.deinit();

    var structObject = try allocator.alloc(u8, ffiStruct.getSize());
    defer allocator.free(structObject);

    const aVar: [1]u8 = @bitCast(@as(i8, 15));
    const bVar: [4]u8 = @bitCast(@as(f32, 3.14));
    const cVar: [4]u8 = @bitCast(@as(i32, 12345678));
    @memcpy(structObject[ffiStruct.offsets[0] .. ffiStruct.offsets[0] + 1], aVar[0..1]);
    @memcpy(structObject[ffiStruct.offsets[1] .. ffiStruct.offsets[1] + 4], bVar[0..4]);
    @memcpy(structObject[ffiStruct.offsets[2] .. ffiStruct.offsets[2] + 4], cVar[0..4]);

    const castStruct: *c.simpleUnknownStruct = @ptrCast(@alignCast(structObject.ptr));

    try std.testing.expectEqual(15, castStruct.a);
    try std.testing.expectEqual(3.14, castStruct.b);
    try std.testing.expectEqual(12345678, castStruct.c);

    var arg1: i8 = 15;
    var arg2: f32 = 3.14;
    var arg3: i32 = 12345678;

    const res = try ffiFunc.call(&.{ @ptrCast(&structObject.ptr), &arg1, &arg2, &arg3 });
    defer ffiFunc.free(res);

    try std.testing.expectEqual(1, std.mem.readVarInt(i32, res, .little));
}
