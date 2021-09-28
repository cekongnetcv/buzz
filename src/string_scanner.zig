const std = @import("std");
const Compiler = @import("./compiler.zig").Compiler;
const Scanner = @import("./scanner.zig").Scanner;
const _obj = @import("./obj.zig");
const _value = @import("./value.zig");

const Value = _value.Value;
const ObjTypeDef = _obj.ObjTypeDef;
const copyStringRaw = _obj.copyStringRaw;

pub const StringScanner = struct {
    const Self = @This();

    source: []const u8,

    compiler: *Compiler,
    current: ?u8 = null,
    current_chunk: std.ArrayList(u8),
    offset: usize = 0,
    previous_interp: ?usize = null,
    chunk_count: usize = 0,

    pub fn init(compiler: *Compiler, source: []const u8) Self {
        return Self {
            .compiler = compiler,
            .source = source,
            .current_chunk = std.ArrayList(u8).init(compiler.allocator)
        };
    }

    pub fn deinit(self: *Self) void {
        self.current_chunk.deinit();
    }

    fn advance(self: *Self) ?u8 {
        if (self.offset >= self.source.len) {
            return null;
        }

        self.current = self.source[self.offset];
        self.offset += 1;

        return self.current;
    }

    pub fn parse(self: *Self) !void {
        if (self.source.len == 0) return;

        while (self.offset < self.source.len) {
            const char: ?u8 = self.advance();
            if (char == null) {
                break;
            }

            switch (char.?) {
                '\\' => try self.escape(),
                '{' => {
                    if (self.previous_interp == null or self.previous_interp.? < self.offset - 1) {
                        if (self.current_chunk.items.len > 0) {
                            try self.push(self.current_chunk.items);
                            self.current_chunk.clearAndFree();

                            try self.inc();
                        }
                    }

                    try self.interpolation();

                    try self.inc();
                },
                else => try self.current_chunk.append(char.?)
            }
        }

        // Trailing string
        if ((self.previous_interp == null or self.previous_interp.? < self.offset)
            and self.current_chunk.items.len > 0) {
            try self.push(self.current_chunk.items);
            self.current_chunk.clearAndFree();
        }
    }

    fn push(self: *Self, chars: []const u8) !void {
        try self.compiler.emitConstant(Value {
            .Obj = (try copyStringRaw(
                self.compiler.strings,
                self.compiler.allocator,
                chars
            )).toObj()
        });
    }

    fn inc(self: *Self) !void {
        self.chunk_count += 1;

        if (self.chunk_count == 2 or self.chunk_count > 2) {
            try self.compiler.emitOpCode(.OP_ADD);
        }
    }

    fn interpolation(self: *Self) !void {
        var expr: []const u8 = self.source[self.offset..];

        var expr_scanner = Scanner.init(expr);

        // Replace compiler scanner with one that only looks at that substring
        var scanner = self.compiler.scanner;
        self.compiler.scanner = expr_scanner;
        var parser = self.compiler.parser;
        self.compiler.parser = .{};

        try self.compiler.advance();

        // Parse expression
        var expr_type: *ObjTypeDef = try self.compiler.expression(false);
        // if placeholder we emit a useless OP_TO_STRING!
        if (expr_type.def_type != .String) {
            try self.compiler.emitOpCode(.OP_TO_STRING);
        }

        self.offset += self.compiler.scanner.?.current.offset
            - self.compiler.parser.current_token.?.lexeme.len
            - self.compiler.parser.next_token.?.lexeme.len
            - (if (self.compiler.parser.next_token.?.lexeme.len > 0) @intCast(usize, 1) else @intCast(usize, 0));
        self.previous_interp = self.offset;

        // Put back compiler's scanner
        self.compiler.scanner = scanner;
        self.compiler.parser = parser;

        // Consume closing `}`
        _ = self.advance();
    } 

    fn escape(self: *Self) !void {
        const char: ?u8 = self.advance();
        if (char == null) {
            return;
        }
        switch (char.?) {
            'n' => try self.current_chunk.append('\n'),
            't' => try self.current_chunk.append('\t'),
            'r' => try self.current_chunk.append('\r'),
            '"' => try self.current_chunk.append('"'),
            '\\' => try self.current_chunk.append('\\'),
            '{' => try self.current_chunk.append('{'),
            else => try self.rawChar(),
        }
    }

    fn rawChar(self: *Self) !void {
        const start: usize = self.offset;
        while (self.advance()) |char| {
            if (char < '0' and char > '9') {
                break;
            }
        }

        const num_str: []const u8 = self.source[start..self.offset];
        const number: ?u8 = std.fmt.parseInt(u8, num_str, 10) catch null;

        if (number) |unumber| {
            try self.current_chunk.append(unumber);
        } else {
            try self.compiler.reportError("Raw char should be between 0 and 255.");
        }
    }
};