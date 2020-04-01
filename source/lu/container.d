/++
 +  Containers and thereto related functionality.
 +/
module lu.container;

public:

@safe:


// Buffer
/++
 +  Simple buffer for storing and fetching items of any type `T`.
 +
 +  It uses a static array internally, which imposes a hard limit on how many
 +  items can be added.
 +
 +  Example:
 +  ---
 +  Buffer!string buffer;
 +
 +  buffer.put("abc");
 +  buffer.put("def");
 +  assert(!buffer.empty);
 +  assert(buffer.front == "abc");
 +  buffer.popFront();
 +  assert(buffer.front == "def");
 +  buffer.popFront();
 +  assert(buffer.empty);
 +  ---
 +
 +  Params:
 +      T = Buffer item type.
 +      bufferSize = How many items to allocate space for. It will assert if
 +          you attempt to store any past this amount.
 +/
struct Buffer(T, size_t bufferSize = 128)
{
pure nothrow @nogc:
    /// Internal buffer static array.
    T[bufferSize] buf;

    /// Current position in the array.
    ptrdiff_t pos;

    /// Position of last entry in the array.
    ptrdiff_t end;

    /++
     +  Append an item to the end of the buffer.
     +
     +  Params:
     +      more = Item to add.
     +/
    void put(const T more)
    in ((end < bufferSize), typeof(this).stringof ~ " buffer overflow")
    do
    {
        buf[end++] = more;
    }

    /++
     +  Implements `buf ~= someT` (appending) by wrapping `put`.
     +
     +  Params:
     +      op = Op type, here specialised to "`~`".
     +      more = Item to add.
     +/
    void opOpAssign(string op : "~")(const T more)
    {
        return put(more);
    }

    /++
     +  Fetches the item at the current position of the buffer.
     +
     +  Returns:
     +      An item T.
     +/
    T front() const
    in ((end > 0), "Empty range")
    do
    {
        return buf[pos];
    }

    /// Advances the current position to the next item in the buffer.
    void popFront()
    {
        if (++pos == end) reset();
    }

    /++
     +  Returns whether or not the array is considered empty.
     +
     +  Mind that the buffer may well still contain old contents. Use `clear`
     +  to zero it out.
     +
     +  Returns:
     +      `true` if there are items available to get via `front`, `false` if not.
     +/
    bool empty() const
    {
        return (end == 0);
    }

    /// Resets the array positions, effectively emptying the buffer.
    void reset()
    {
        pos = 0;
        end = 0;
    }

    /// Zeroes out the buffer, getting rid of old contents.
    void clear()
    {
        buf[] = T.init;
    }
}

///
unittest
{
    {
        Buffer!(bool, 4) buf;

        assert(buf.empty);
        buf.put(true);
        buf.put(false);
        buf.put(true);
        buf.put(false);

        assert(!buf.empty);
        assert(buf.front == true);
        buf.popFront();
        assert(buf.front == false);
        buf.popFront();
        assert(buf.front == true);
        buf.popFront();
        assert(buf.front == false);
        buf.popFront();
        assert(buf.empty);
        assert(buf.buf == [ true, false, true, false ]);
        buf.put(false);
        assert(buf.buf == [ false, false, true, false ]);
        buf.reset();
        assert(buf.empty);
        buf.clear();
        assert(buf.buf == [ false, false, false, false ]);
    }
    {
        Buffer!(string, 4) buf;

        assert(buf.empty);
        buf.put("abc");
        buf.put("def");
        buf.put("ghi");

        assert(!buf.empty);
        assert(buf.front == "abc");
        buf.popFront();
        assert(buf.front == "def");
        buf.popFront();
        buf.put("JKL");
        assert(buf.front == "ghi");
        buf.popFront();
        assert(buf.front == "JKL");
        buf.popFront();
        assert(buf.empty);
        assert(buf.buf == [ "abc", "def", "ghi", "JKL" ]);
        buf.put("MNO");
        assert(buf.buf == [ "MNO", "def", "ghi", "JKL" ]);
        buf.clear();
        assert(buf.buf == [ string.init, string.init, string.init, string.init ]);
    }
    {
        Buffer!(char, 64) buf;
        buf ~= 'a';
        buf ~= 'b';
        buf ~= 'c';
        assert(buf.buf[0..3] == "abc".dup);

        foreach (char_; buf)
        {
            assert((char_ == 'a') || (char_ == 'b') || (char_ == 'c'));
        }
    }
}
