/++
 +  Containers and thereto related functionality.
 +/
module lu.container;

private:

import std.typecons : Flag, No, Yes;

public:

@safe:


// Buffer
/++
 +  Simple buffer for storing and fetching items of any type `T`. Does not use
 +  manual memory allcation.
 +
 +  It can use a static array internally to store elements on the stack, which
 +  imposes a hard limit on how many items can be added, or a dynamic heap one
 +  with a resizable buffer.
 +
 +  Example:
 +  ---
 +  Buffer!(string, No.dynamic, 16) buffer;
 +
 +  buffer.put("abc");
 +  buffer ~= "def";
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
 +      dynamic = Whether to use a dynamic array whose size can be grown at
 +          runtime, or to use a static array with a fixed size. Trying to add
 +          more elements than there is room for will cause an assert.
 +          Defaults to `No.dynamic`; a static bufferCurrent position in the array..
 +      originalSize = How many items to allocate space for. If `No.dynamic` was
 +          passed it will assert if you attempt to store anything past this amount.
 +/
struct Buffer(T, Flag!"dynamic" dynamic = No.dynamic, size_t originalSize = 128)
{
pure nothrow:

version(dynamic) {}
else
{
    @nogc:
}

    static if (dynamic)
    {
        /++
         +  By how much to grow the buffer when we reach the end of it.
         +/
        private enum growthFactor = 1.5;

        /++
         +  Internal buffer dynamic array.
         +/
        T[] buf;

        /++
         +  Variable buffer size.
         +/
        size_t bufferSize;
    }
    else
    {
        /++
         +  Internal buffer static array.
         +/
        T[bufferSize] buf;

        /++
         +  Static buffer size.
         +/
        alias bufferSize = originalSize;
    }

    /++
     +  Current position in the array.
     +/
    ptrdiff_t pos;

    /++
     +  Position of last entry in the array.
     +/
    ptrdiff_t end;


    static if (dynamic)
    {
        // put
        /++
         +  Append an item to the end of the buffer.
         +
         +  If it would be put beyond the end of the buffer, it will be resized to fit.
         +
         +  Params:
         +      more = Item to add.
         +/
        void put(/*const*/ T more)
        {
            if (end == bufferSize)
            {
                bufferSize = !bufferSize ? originalSize : cast(size_t)(bufferSize * growthFactor);
                buf.length = bufferSize;
            }

            buf[end++] = more;
        }
    }
    else
    {
        // put
        /++
         +  Append an item to the end of the buffer.
         +
         +  If it would be put beyond the end of the buffer, it will assert.
         +
         +  Params:
         +      more = Item to add.
         +/
        void put(/*const*/ T more)
        in ((end < bufferSize), '`' ~ typeof(this).stringof ~ "` buffer overflow")
        do
        {
            buf[end++] = more;
        }
    }

    static if (dynamic)
    {
        // reserve
        /++
         +  Reserves enough room for the specified number of elements. If there
         +  is already enough room, nothing is done. Otherwise the buffer is grown.
         +
         +  Params:
         +      reserveSize = Number of elements to reserve size for.
         +/
        void reserve(const size_t reserveSize)
        {
            if (bufferSize < reserveSize)
            {
                bufferSize = reserveSize;
                buf.length = bufferSize;
            }
        }
    }

    // opOpAssign
    /++
     +  Implements `buf ~= someT` (appending) by wrapping `put`.
     +
     +  Params:
     +      op = Operation type, here specialised to "`~`".
     +      more = Item to add.
     +/
    void opOpAssign(string op : "~")(const T more)
    {
        return put(more);
    }

    // front
    /++
     +  Fetches the item at the current position of the buffer.
     +
     +  Returns:
     +      An item T.
     +/
    T front() const
    in ((end > 0), '`' ~ typeof(this).stringof ~ "` buffer underrun")
    do
    {
        return buf[pos];
    }

    // popFront
    /++
     +  Advances the current position to the next item in the buffer.
     +/
    void popFront()
    {
        if (++pos == end) reset();
    }

    // length
    /++
     +  Returns what amounts to the current length of the buffer; the distance
     +  between the current position `pos` and the last element `end`.
     +
     +  Returns:
     +      The buffer's current length.
     +/
    size_t length() const
    {
        return (end - pos);
    }

    // empty
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

    // reset
    /++
     +  Resets the array positions, effectively soft-emptying the buffer.
     +
     +  The old elements' values are still there, they will just be overwritten
     +  as the buffer is appended to.
     +/
    void reset()
    {
        pos = 0;
        end = 0;
    }

    // clear
    /++
     +  Zeroes out the buffer's elements, getting rid of old contents.
     +/
    void clear()
    {
        reset();
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
