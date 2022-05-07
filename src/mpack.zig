const std = @import("std");
const c = @import("c.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const AllocError = Allocator.Error;

pub const MpackReader = extern struct {
    reader: c.mpack_reader_t,

    /// Initializes an MPack reader to parse a pre-loaded
    /// contiguous chunk of data. The reader does not assume
    /// ownership of the data.
    pub fn init_data(data: []const u8) MpackReader {
        var self: MpackReader = undefined;
        c.mpack_reader_init_data(&self.reader, data.ptr, data.len);
        return self;
    }

    /// Queries the error state of the MPack reader
    pub inline fn error_info(self: *MpackReader) ErrorInfo {
        return .{ .err = c.mpack_reader_error(&self.reader) };
    }

    /// Parses the next MessagePack object header
    /// (an MPack tag) without advancing the reader.
    pub fn peek_tag(self: *MpackReader) Error!MTag {
        const tag = c.mpack_peek_tag(&self.reader);
        if (tag.is_nil()) {
            try self.error_info().check_okay();
        } else {
            // should have returned nil if error
            assert(self.error_info().is_okay());
        }
        return tag;
    }

    /// Reads a MessagePack object header (an MPack tag.)
    ///
    /// If the type is compound (i.e. is a map, array, string,
    /// binary or extension type), additional reads are required
    /// to get the contained data, and the corresponding done
    /// function must be called when done.
    pub fn read_tag(self: *MpackReader) Error!MTag {
        const tag = c.mpack_read_tag(&self.reader);
        if (tag.is_nil()) {
            try self.error_info().check_okay();
        } else {
            // should have returned nil if error
            assert(self.error_info().is_okay());
        }
        return tag;
    }

    /// Reads and discards the next object.
    ///
    /// This will read and discard all
    /// contained data as well if it is a compound type.
    pub fn discard(self: *MpackReader) Error!void {
        c.mpack_discard(&self.reader);
        try self.error_info().check_okay();
    }

    /// Finishes reading an array.
    pub fn done_array(self: *MpackReader) Error!void {
        c.mpack_done_array(&self.reader);
        try self.error_info().check_okay();
    }

    /// Finishes reading a map.
    pub fn done_map(self: *MpackReader) Error!void {
        c.mpack_done_map(&self.reader);
        try self.error_info().check_okay();
    }

    /// Finishes reading a binary data blob.
    pub fn done_bin(self: *MpackReader) Error!void {
        c.mpack_done_bin(&self.reader);
        try self.error_info().check_okay();
    }

    /// Finishes reading a string.
    pub fn done_str(self: *MpackReader) Error!void {
        c.mpack_done_str(&self.reader);
        try self.error_info().check_okay();
    }

    /// Cleans up the MPack reader,
    /// ensuring that all compound elements
    /// have been completely read
    ///
    /// Returns the final error state of the
    /// reader.
    pub inline fn destroy(self: *MpackReader) Error!void {
        var err = c.mpack_reader_destroy(&self.reader);
        try (ErrorInfo{ .err = err }).check_okay();
    }

    /// Reads bytes from a string, binary blob or extension object,
    /// copying them into the given buffer.
    ///
    /// A str, bin or ext must have been opened by a call to read_tag()
    /// which gave one of these types.
    ///
    /// This can be called multiple times for a single str, bin or ext
    /// to read the data in chunks.
    /// The total data read must add up to the size of the object.
    ///
    /// If an error occurs, the buffer contents are undefined.
    pub fn read_bytes_into(self: *MpackReader, dest: []u8) Error!void {
        if (dest.len != 0) {
            c.mpack_read_bytes(&self.reader, dest.ptr, dest.len);
            try self.error_info().check_okay();
        }
    }

    /// Reads bytes from a string, binary blob or extension object,
    /// allocating storage for them and returning the allocated pointer.
    pub fn read_bytes_alloc(self: *MpackReader, alloc: Allocator, size: u32) Error![]u8 {
        var dest = try alloc.alloc(u8, @intCast(usize, size));
        try self.read_bytes_into(dest);
        return dest;
    }

    //
    // expect API
    //

    /// Reads an 8-bit unsigned integer.
    pub inline fn expect_u8(self: *MpackReader) Error!u8 {
        const val = c.mpack_expect_u8(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a 32-bit unsigned integer.
    pub inline fn expect_u32(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_u32(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads an 64-bit unsigned integer.
    pub inline fn expect_u64(self: *MpackReader) Error!u64 {
        const val = c.mpack_expect_u64(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads an 32-bit signed integer.
    pub inline fn expect_i32(self: *MpackReader) Error!i32 {
        const val = c.mpack_expect_i32(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads an 64-bit signed integer.
    pub inline fn expect_i64(self: *MpackReader) Error!i64 {
        const val = c.mpack_expect_i64(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a 64-bit unsigned integer, ensuring that it falls within the given range.
    ///
    /// The underlying type may be an integer
    /// type of any size and signedness, as long as the value
    /// can be represented in a 64-bit unsigned int.
    ///
    /// Both values are inclusive
    pub inline fn expect_u64_range(self: *MpackReader, min: u64, max: u64) Error!u64 {
        const val = c.mpack_expect_u64_range(&self.reader, min, max);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a 64-bit signed integer, ensuring that it falls within the given range.
    ///
    /// The underlying type may be an integer
    /// type of any size and signedness, as long as the value
    /// can be represented in a 64-bit signed int.
    ///
    /// Both values are inclusive
    pub inline fn expect_i64_range(self: *MpackReader, min: i64, max: i64) Error!i64 {
        const val = c.mpack_expect_i64_range(&self.reader, min, max);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a number, returning the value as a double.
    ///
    /// The underlying value can be an integer, float or double;
    /// the value is converted to a double.
    ///
    /// Reading a very large integer with this function
    /// can incur a loss of precision.
    pub inline fn expect_double(self: *MpackReader) Error!f64 {
        const val = c.mpack_expect_double(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a double.
    ///
    /// The underlying value must be a float or double, not an integer.
    /// This ensures no loss of precision can occur.
    pub inline fn expect_double_strict(self: *MpackReader) Error!f64 {
        const val = c.mpack_expect_double_strict(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a nil.
    pub inline fn expect_nil(self: *MpackReader) Error!void {
        c.mpack_expect_nil(&self.reader);
        try self.error_info().check_okay();
    }

    /// Reads a boolean.
    ///
    /// Integers will raise an error,
    /// the value must be strictly a boolean.
    pub inline fn expect_bool(self: *MpackReader) Error!bool {
        const val = c.mpack_expect_bool(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads the start of a map, returning its element count.
    ///
    /// A number of values follow equal to twice the
    /// element count of the map, alternating between keys and values.
    ///
    /// NOTE: Maps in JSON are unordered, so it is recommended
    /// not to expecta specific ordering for your map values
    /// in case your data is converted to/from JSON.
    ///
    /// WARNING(from C): This call is dangerous! It does not have
    /// a size limit, and it does not have any way of checking
    /// whether there is enough data in the message.
    ///
    /// NOTE: This is almost entirely mitigated by careful error handling
    /// of the Zig bindings, which check for errors after every call :)
    pub fn expect_map(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_map(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads the start of an array, returning its element count.
    ///
    /// A number of values follow equal to
    /// the element count of the array.
    pub fn expect_array(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_array(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads the start of an array, expecting the exact size given.
    pub fn expect_array_match(self: *MpackReader, count: u32) Error!void {
        c.mpack_expect_array_match(&self.reader, count);
        try self.error_info().check_okay();
    }

    /// Reads the start of a string, returning its size in bytes.
    ///
    /// The bytes follow and must be read separately.
    /// done_str() must be called once all bytes have been read.
    ///
    /// NUL bytes are allowed in the string, and no encoding checks are done.
    pub fn expect_str_start(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_str(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a string, allocating it in the specified allocator.
    ///
    /// NULL bytes are allowed in the string,
    /// and no encoding checks are done (it may not be valid UTF8).
    ///
    /// See also `expect_utf8_alloc`, which requires the data is UTF8 encoded
    pub fn expect_str_relaxed_alloc(self: *MpackReader, alloc: Allocator) Error![]const u8 {
        const size = try self.expect_str_start();
        const res = try self.read_bytes_alloc(alloc, size);
        try self.done_str();
        return res;
    }

    /// Reads a UTF8 encoded string,
    ///
    /// Null bytes are allowed in the string.
    /// However, it must be valid UTF8
    pub fn expect_utf8_alloc(self: *MpackReader, alloc: Allocator) Error![]const u8 {
        const bytes = try self.expect_str_relaxed_alloc(alloc);
        if (!std.unicode.utf8ValidateSlice(bytes)) {
            return Error.MsgpackErrorInvalid;
        }
        return bytes;
    }

    /// Parse the specified type using compile time reflection
    ///
    /// Types that can be parsed:
    /// 1. Primitives (Integers, Floats, Booleans)
    /// 2. Strings and bytes
    /// 3. Optional types
    /// 3. struct
    /// 4. Arrays
    /// 5. Enums
    ///
    /// NOTES:
    /// An interpretation must be specified for "byte types".
    /// Does `[]const u8` in the source mean we expect
    pub fn expect_reflect(
        self: *MpackReader,
        comptime T: type,
        comptime ctx: ReflectParseContext,
    ) Error!T {
        _ = ctx.allocator;
        const info = @typeInfo(T);
        switch (info) {
            .Void => {
                try self.expect_nil();
                return;
            },
            .Bool => {
                return @as(T, try self.expect_bool());
            },
            .Int => |i| {
                assert(i.bits <= 64);
                const effective_bits = switch (i.signedness) {
                    .signed => i.bits - 1,
                    .unsigned => i.bits,
                };
                const max: comptime_int = (1 << effective_bits) - 1;
                return switch (i.signedness) {
                    .signed => {
                        const min: comptime_int = -(1 << effective_bits);
                        return @intCast(T, try self.expect_i64_range(@intCast(i64, min), @intCast(i64, max)));
                    },
                    .unsigned => {
                        return @intCast(T, try self.expect_u64_range(@intCast(u64, 0), @intCast(u64, max)));
                    },
                };
            },
            // invalid type
            else => unreachable,
        }
    }
    /// This is a special case of `expect_reflect`,
    /// that only supports structs.
    ///
    /// It is special cased because it is often
    /// useful to mix struct reflection with otherwise
    /// hand-coded deserialization.
    pub fn parse_reflect_struct(
        _: *MpackReader,
        comptime T: type,
        comptime _: ReflectParseContext,
        comptime _: StructSerStyle,
    ) Error!T {}
};
pub const ReflectParseContext = struct {
    allocator: ?Allocator = null,
    /// Ignore extra fields when parsing structs
    ///
    /// If this is false, then extra fields are errors.
    ignore_extra_fields: bool = true,
    struct_require_style: ?StructSerStyle = null,
    /// Requires that enums are serialized in the specified style
    ///
    /// If this is null, then either style can be used.
    enum_require_style: ?EnumSerStyle = null,
    /// Require that strings are UTF8 encoded
    ///
    /// This implies an extra validation step (for strings)
    require_utf8: bool = true,
    /// The way to interpret byte slices.
    ///
    /// If this is null, then byte types are errors.
    bytes_type: ?BytesType = null,
};

/// The "style" for struct serialization
pub const StructSerStyle = enum {
    map,
    array,
};

/// The style for enum serializtion
pub const EnumSerStyle = enum {
    names,
    ordinals,
};

/// The way to interpret byte slices.
///
/// Zig has two meainings for `[]const u8`.
/// 1: A byte array
/// 2. A string array
///
/// There is also the special "anything" type
/// which means that either type is permitted.
pub const BytesType = enum {
    bytes,
    string,
    anything,
};

pub const MType = enum(c.mpack_type_t) {
    missing = c.mpack_type_missing,
    nil = c.mpack_type_nil,
    int = c.mpack_type_int,
    uint = c.mpack_type_uint,
    float = c.mpack_type_float,
    double = c.mpack_type_double,
    str = c.mpack_type_str,
    bin = c.mpack_type_bin,
    array = c.mpack_type_array,
    map = c.mpack_type_map,
    ext = c.mpack_type_ext,

    pub fn to_string(self: MType) [*:0]const u8 {
        return c.mpack_type_to_string(@as(c.mpack_type_t, self));
    }
};

pub const MTag = extern struct {
    tag: c.mpack_tag_t,

    pub inline fn tag_type(self: MTag) MType {
        return c.mpack_tag_type(&self.taga);
    }

    pub inline fn is_nil(self: MTag) bool {
        return self.tag_type() == MType.nil;
    }
};

pub const TypeError = error{
    /// The type or value range did not match what was expected by the caller.
    ///
    /// This can include not only unexpected type tag,
    /// but also an unexpected value.
    /// In particular it can indicate invalid UTF8.
    ///
    /// In some contexts this is the only error that is possible
    /// (which is why it is a seperate type)
    MsgpackErrorType,
};
pub const Error = error{
    /// Some other error occured related to msgpack
    MsgpackError,
    /// The data read is not valid MessagePack
    MsgpackErrorInvalid,
    /// Indicates an underlying error occurred with IO.
    ///
    /// The reader or writer failed to fill or flush,
    /// or some other file or socket error occurred.
    MsgpackErrorIO,
    /// While reading msgpack, an allocation failure occurred
    MsgpackErrorMemory,
} || TypeError || AllocError;

pub const ErrorInfo = extern struct {
    err: c.mpack_error_t,

    pub inline fn is_ok(self: ErrorInfo) bool {
        return self.err == c.mpack_ok;
    }
    pub inline fn check_okay(self: ErrorInfo) Error!void {
        return switch (self.err) {
            c.mpack_ok => return,
            c.mpack_error_io => Error.MsgpackErrorIO,
            c.mpack_error_type => Error.MsgpackErrorType,
            c.mpack_error_invalid => Error.MsgpackErrorInvalid,
            c.mpack_error_memory => Error.MsgpackErrorMemory,
            else => Error.MsgpackError,
        };
    }

    pub fn to_string(self: ErrorInfo) [*:0]const u8 {
        return c.mpack_error_to_string(self.err);
    }
};

pub fn free(ptr: anytype) void {
    c.MPACK_FREE(ptr);
}

//
// code used for testing
//

const PrimitiveValue = union(enum) {
    U8: u8,
    U32: u32,
    U64: u64,
    I32: i32,
    I64: i64,
    Bool: bool,
    Nil: void,
};
const TestValue = struct {
    bytes: []const u8,
    value: PrimitiveValue,
};
fn expect_primitive(reader: *MpackReader, expected: PrimitiveValue, reflect: bool) !void {
    const expectEqual = std.testing.expectEqual;
    switch (expected) {
        .U8 => |val| {
            if (reflect) {
                try expectEqual(val, try reader.*.expect_reflect(u8, .{}));
            } else {
                try expectEqual(val, try reader.*.expect_u8());
            }
        },
        .U32 => |val| {
            if (reflect) {
                try expectEqual(val, try reader.*.expect_reflect(u32, .{}));
            } else {
                try expectEqual(val, try reader.*.expect_u32());
            }
        },
        .U64 => |val| {
            if (reflect) {
                try expectEqual(val, try reader.*.expect_reflect(u64, .{}));
            } else {
                try expectEqual(val, try reader.*.expect_u64());
            }
        },
        .I32 => |val| {
            if (reflect) {
                try expectEqual(val, try reader.*.expect_reflect(i32, .{}));
            } else {
                try expectEqual(val, try reader.*.expect_i32());
            }
        },
        .I64 => |val| {
            if (reflect) {
                try expectEqual(val, try reader.*.expect_reflect(i64, .{}));
            } else {
                try expectEqual(val, try reader.*.expect_i64());
            }
        },
        .Bool => |val| {
            if (reflect) {
                try expectEqual(val, try reader.*.expect_reflect(bool, .{}));
            } else {
                try expectEqual(val, try reader.*.expect_bool());
            }
        },
        .Nil => {
            if (reflect) {
                try reader.*.expect_reflect(void, .{});
            } else {
                try reader.*.expect_nil();
            }
        },
    }
}

test "mpack primitives" {
    const expected_values = [_]TestValue{
        .{ .bytes = "\x07", .value = PrimitiveValue{ .U8 = 7 } },
        .{ .bytes = "\xcc\xf0", .value = PrimitiveValue{ .U8 = 240 } },
        .{ .bytes = "\x01", .value = PrimitiveValue{ .U8 = 1 } },
        .{ .bytes = "\x01", .value = PrimitiveValue{ .U32 = 1 } },
        .{ .bytes = "\xFF", .value = PrimitiveValue{ .I32 = -1 } },
        .{ .bytes = "\xE7", .value = PrimitiveValue{ .I32 = -25 } },
        .{ .bytes = "\xd1\xf2\x06", .value = PrimitiveValue{ .I32 = -3578 } },
        .{ .bytes = "\xcd\r\xfa", .value = PrimitiveValue{ .I32 = 3578 } },
        .{ .bytes = "\xce\x01\x00\x00\x00", .value = PrimitiveValue{ .U32 = 1 << 24 } },
        .{ .bytes = "\xd2\xff\x00\x00\x00", .value = PrimitiveValue{ .I32 = -(1 << 24) } },
        .{
            .bytes = "\xcf\x00\x00 \x00\x00\x00\x00\x1f",
            .value = PrimitiveValue{ .U64 = (1 << 45) + 31 },
        },
        .{
            .bytes = "\xd3\xff\xff\xdf\xff\xff\xff\xff\xe1",
            .value = PrimitiveValue{ .I64 = -(1 << 45) - 31 },
        },
        .{ .bytes = "\xc0", .value = PrimitiveValue{ .Nil = {} } },
        .{ .bytes = "\xc3", .value = PrimitiveValue{ .Bool = true } },
        .{ .bytes = "\xc2", .value = PrimitiveValue{ .Bool = false } },
    };
    for (expected_values) |value| {
        const should_reflect = [2]bool{ false, true };
        for (should_reflect) |reflect| {
            var reader = MpackReader.init_data(value.bytes);
            defer reader.destroy() catch unreachable;
            try expect_primitive(&reader, value.value, reflect);
        }
    }
}

test "mpack strings" {
    const TestString = struct {
        encoded: []const u8,
        text: []const u8,
        utf8: bool = true,
    };
    const long_phrases = [_][]const u8{
        "For Faith is the Substance of the Things I have hoped for, the evidence for the things not seen.",
        "Let it go! Let it go! Can't hold it back anymore.",
    };
    const test_strings = [_]TestString{
        .{ .encoded = "\xa0", .text = "" },
        .{ .encoded = "\xa3foo", .text = "foo" },
        .{ .encoded = "\xd9`" ++ long_phrases[0], .text = long_phrases[0] },
        .{ .encoded = "\xd91" ++ long_phrases[1], .text = long_phrases[1] },
    };
    const alloc = std.testing.allocator;
    for (test_strings) |value| {
        var reader = MpackReader.init_data(value.encoded);
        defer reader.destroy() catch unreachable;
        var actual_text = blk: {
            if (value.utf8) {
                break :blk try reader.expect_str_relaxed_alloc(alloc);
            } else {
                break :blk try reader.expect_utf8_alloc(alloc);
            }
        };
        try std.testing.expectEqualStrings(actual_text, value.text);
        defer alloc.free(actual_text);
    }
}
