const List = @import("list.zig").List;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;
const debug = @import("debug.zig");
const assert = debug.assert;

const strlen = len;

// TODO fix https://github.com/andrewrk/zig/issues/140
// and then make this able to run at compile time
#static_eval_enable(false)
pub fn len(ptr: &const u8) -> usize {
    var count: usize = 0;
    while (ptr[count] != 0; count += 1) {}
    return count;
}

// TODO fix https://github.com/andrewrk/zig/issues/140
// and then make this able to run at compile time
#static_eval_enable(false)
pub fn cmp(a: &const u8, b: &const u8) -> i32 {
    var index: usize = 0;
    while (a[index] == b[index] && a[index] != 0; index += 1) {}
    return a[index] - b[index];
}

pub fn toSliceConst(str: &const u8) -> []const u8 {
    return str[0...strlen(str)];
}

pub fn toSlice(str: &u8) -> []u8 {
    return str[0...strlen(str)];
}


/// A buffer that allocates memory and maintains a null byte at the end.
pub struct CBuf {
    list: List(u8),

    /// Must deinitialize with deinit.
    pub fn init(self: &CBuf, allocator: &Allocator) {
        self.list.init(allocator);
        // This resize is guaranteed to not have an error because we use a list
        // with preallocated memory of at least 1 byte.
        %%self.resize(0);
    }

    /// Must deinitialize with deinit.
    pub fn initFromMem(self: &CBuf, allocator: &Allocator, m: []const u8) -> %void {
        self.init(allocator);
        %return self.resize(m.len);
        mem.copy(u8, self.list.items, m);
    }

    /// Must deinitialize with deinit.
    pub fn initFromCStr(self: &CBuf, allocator: &Allocator, s: &const u8) -> %void {
        self.initFromMem(allocator, s[0...strlen(s)])
    }

    /// Must deinitialize with deinit.
    pub fn initFromCBuf(self: &CBuf, cbuf: &const CBuf) -> %void {
        self.initFromMem(cbuf.list.allocator, cbuf.list.items[0...cbuf.len()])
    }

    /// Must deinitialize with deinit.
    pub fn initFromSlice(self: &CBuf, other: &const CBuf, start: usize, end: usize) -> %void {
        self.initFromMem(other.list.allocator, other.list.items[start...end])
    }

    pub fn deinit(self: &CBuf) {
        self.list.deinit();
    }

    pub fn resize(self: &CBuf, new_len: usize) -> %void {
        %return self.list.resize(new_len + 1);
        self.list.items[self.len()] = 0;
    }

    pub fn len(self: &const CBuf) -> usize {
        return self.list.len - 1;
    }

    pub fn appendMem(self: &CBuf, m: []const u8) -> %void {
        const old_len = self.len();
        %return self.resize(old_len + m.len);
        mem.copy(u8, self.list.items[old_len...], m);
    }

    pub fn appendCStr(self: &CBuf, s: &const u8) -> %void {
        self.appendMem(s[0...strlen(s)])
    }

    pub fn appendChar(self: &CBuf, c: u8) -> %void {
        %return self.resize(self.len() + 1);
        self.list.items[self.len() - 1] = c;
    }

    pub fn eqlMem(self: &const CBuf, m: []const u8) -> bool {
        if (self.len() != m.len) return false;
        return mem.cmp(u8, self.list.items[0...m.len], m) == mem.Cmp.Equal;
    }

    pub fn eqlCStr(self: &const CBuf, s: &const u8) -> bool {
        self.eqlMem(s[0...strlen(s)])
    }

    pub fn eqlCBuf(self: &const CBuf, other: &const CBuf) -> bool {
        self.eqlMem(other.list.items[0...other.len()])
    }

    pub fn startsWithMem(self: &const CBuf, m: []const u8) -> bool {
        if (self.len() < m.len) return false;
        return mem.cmp(u8, self.list.items[0...m.len], m) == mem.Cmp.Equal;
    }

    pub fn startsWithCBuf(self: &const CBuf, other: &const CBuf) -> bool {
        self.startsWithMem(other.list.items[0...other.len()])
    }

    pub fn startsWithCStr(self: &const CBuf, s: &const u8) -> bool {
        self.startsWithMem(s[0...strlen(s)])
    }
}

#attribute("test")
fn testSimpleCBuf() {
    var buf: CBuf = undefined;
    buf.init(&debug.global_allocator);
    assert(buf.len() == 0);
    %%buf.appendCStr(c"hello");
    %%buf.appendChar(' ');
    %%buf.appendMem("world");
    assert(buf.eqlCStr(c"hello world"));
    assert(buf.eqlMem("hello world"));

    var buf2: CBuf = undefined;
    %%buf2.initFromCBuf(&buf);
    assert(buf.eqlCBuf(&buf2));

    assert(buf.startsWithMem("hell"));
    assert(buf.startsWithCStr(c"hell"));

    %%buf2.resize(4);
    assert(buf.startsWithCBuf(&buf2));
}
