const std = @import("std");
const mem = std.mem;

pub const Token = struct {
    const Self = @This();

    // Since we can parse multiple file, we have to keep a reference to the source in which this token occured
    source: []const u8,
    script_name: []const u8,
    token_type: TokenType,
    lexeme: []const u8,
    // Literal is either a string or a number
    literal_string: ?[]const u8 = null,
    literal_float: ?f64 = null,
    literal_integer: ?i32 = null,
    line: usize,
    column: usize,
    offset: usize = 0,

    pub fn eql(self: Self, other: Self) bool {
        // zig fmt: off
        return self.token_type == other.token_type
            and self.line == other.line
            and self.column == other.column
            and self.offset == other.offset
            and std.mem.eql(u8, self.source, other.source)
            and std.mem.eql(u8, self.script_name, other.script_name);
        // zig fmt: on
    }

    pub fn identifier(name: []const u8) Self {
        return .{
            .token_type = .Identifier,
            .lexeme = name,
            .line = 0,
            .column = 0,
            .source = "",
            .script_name = "",
        };
    }

    pub fn clone(self: Self) Self {
        return .{
            .token_type = self.token_type,
            .lexeme = self.lexeme,
            .source = self.source,
            .script_name = self.script_name,
            .literal_string = self.literal_string,
            .literal_float = self.literal_float,
            .literal_integer = self.literal_integer,
            .line = self.line,
            .column = self.column,
        };
    }

    // Return `n` lines around the token line in its source
    pub fn getLines(self: Self, allocator: mem.Allocator, n: usize) !std.ArrayList([]const u8) {
        var lines = std.ArrayList([]const u8).init(allocator);
        const index = if (self.line > 0) self.line - 1 else 0;

        var it = std.mem.split(u8, self.source, "\n");
        var count: usize = 0;
        while (it.next()) |line| : (count += 1) {
            if (count >= index and count < index + n) {
                try lines.append(line);
            }

            if (count > index + n) {
                break;
            }
        }

        return lines;
    }
};

// WARNING: don't reorder without reordering `rules` in parser.zig
pub const TokenType = enum {
    Pipe, // |
    LeftBracket, // [
    RightBracket, // ]
    LeftParen, // (
    RightParen, // )
    LeftBrace, // {
    RightBrace, // }
    Dot, // .
    Comma, // ,
    Semicolon, // ;
    Greater, // >
    Less, // <
    Plus, // +
    Minus, // -
    Star, // *
    Slash, // /
    Percent, // %
    Question, // ?
    Bang, // !
    Colon, // :
    Equal, // =
    EqualEqual, // ==
    BangEqual, // !=
    BangGreater, // !>
    GreaterEqual, // >=
    LessEqual, // <=
    QuestionQuestion, // ??
    PlusEqual, // +=
    MinusEqual, // -=
    StarEqual, // *=
    SlashEqual, // /=
    Increment, // ++
    Decrement, // --
    Arrow, // ->
    True, // true
    False, // false
    Null, // null
    Str, // str
    Ud, // ud
    Int, // int
    Float, // float
    Type, // type
    Bool, // bool
    Function, // Function

    ShiftRight, // >>
    ShiftLeft, // <<
    Xor, // ^
    Bor, // \
    Bnot, // ~

    Or, // or
    And, // and
    Return, // return
    If, // if
    Else, // else
    Do, // do
    Until, // until
    While, // while
    For, // for
    ForEach, // foreach
    Switch, // switch
    Break, // break
    Continue, // continue
    Default, // default
    In, // in
    Is, // is
    IntegerValue, // 123
    FloatValue, // 123.2
    String, // "hello"
    Identifier, // anIdentifier
    Fun, // fun
    Object, // object
    Obj, // obj
    Protocol, // protocol
    Enum, // enum
    Throw, // throw
    Try, // try
    Catch, // catch
    Test, // test
    Import, // import
    Export, // export
    Const, // const
    Static, // static
    From, // from
    As, // as
    Extern, // extern
    Eof, // EOF
    Error, // Error
    Void, // void
    Docblock, // Docblock
    Pattern, // Pattern
    Pat, // pat
    Fib, // fib
    Ampersand, // async or band
    Resume, // resume
    Resolve, // resolve
    Yield, // yield
};

pub const keywords = std.ComptimeStringMap(TokenType, .{
    .{ "ud", .Ud },
    .{ "void", .Void },
    .{ "true", .True },
    .{ "false", .False },
    .{ "null", .Null },
    .{ "or", .Or },
    .{ "and", .And },
    .{ "as", .As },
    .{ "return", .Return },
    .{ "if", .If },
    .{ "else", .Else },
    .{ "while", .While },
    .{ "for", .For },
    .{ "foreach", .ForEach },
    .{ "switch", .Switch },
    .{ "break", .Break },
    .{ "continue", .Continue },
    .{ "default", .Default },
    .{ "const", .Const },
    .{ "fun", .Fun },
    .{ "in", .In },
    .{ "str", .Str },
    .{ "int", .Int },
    .{ "float", .Float },
    .{ "type", .Type },
    .{ "bool", .Bool },
    .{ "pat", .Pat },
    .{ "do", .Do },
    .{ "until", .Until },
    .{ "is", .Is },
    .{ "object", .Object },
    .{ "obj", .Obj },
    .{ "static", .Static },
    .{ "protocol", .Protocol },
    .{ "enum", .Enum },
    .{ "throw", .Throw },
    .{ "catch", .Catch },
    .{ "try", .Try },
    .{ "test", .Test },
    .{ "Function", .Function },
    .{ "import", .Import },
    .{ "export", .Export },
    .{ "extern", .Extern },
    .{ "from", .From },
    .{ "fib", .Fib },
    .{ "resume", .Resume },
    .{ "resolve", .Resolve },
    .{ "yield", .Yield },
});
