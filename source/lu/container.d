/++
    Containers and thereto related functionality.

    Example:
    ---
    {
        Buffer!string buffer;

        buffer.put("abc");
        buffer.put("def");
        assert(!buffer.empty);
        assert(buffer.front == "abc");
        buffer.popFront();
        assert(buffer.front == "def");
        buffer.popFront();
        assert(buffer.empty);
    }
    {
        Buffer!(char, Yes.dynamic, 3) buffer;

        assert(!buffer.buf.length);
        buffer ~= 'a';
        assert(buffer.buf.length == 3);
        buffer ~= 'b';
        buffer ~= 'c';
        assert(buffer.length == 3);
        buffer ~= 'd';
        assert(buffer.buf.length > 3);
        assert(buffer[0..5] == "abcd");
        buffer.clear();
        assert(buffer.empty);
    }
    ---
 +/
module lu.container;

private:

import std.typecons : Flag, No, Yes;

public:

@safe:


// Buffer
/++
    Simple buffer/queue for storing and fetching items of any type `T`.
    Does not use manual memory allocation.

    It can use a static array internally to store elements on the stack, which
    imposes a hard limit on how many items can be added, or a dynamic heap one
    with a resizable buffer.

    Example:
    ---
    Buffer!(string, No.dynamic, 16) buffer;

    buffer.put("abc");
    buffer ~= "def";
    assert(!buffer.empty);
    assert(buffer.front == "abc");
    buffer.popFront();
    assert(buffer.front == "def");
    buffer.popFront();
    assert(buffer.empty);
    ---

    Params:
        T = Buffer item type.
        dynamic = Whether to use a dynamic array whose size can be grown at
            runtime, or to use a static array with a fixed size. Trying to add
            more elements than there is room for will cause an assert.
            Defaults to `No.dynamic`; a static bufferCurrent position in the array..
        originalSize = How many items to allocate space for. If `No.dynamic` was
            passed it will assert if you attempt to store anything past this amount.
 +/
struct Buffer(T, Flag!"dynamic" dynamic = No.dynamic, size_t originalSize = 128)
{
pure nothrow:

    static if (dynamic)
    {
        /++
            By how much to grow the buffer when we reach the end of it.
         +/
        private enum growthFactor = 1.5;

        /++
            Internal buffer dynamic array.
         +/
        T[] buf;

        /++
            Variable buffer size.
         +/
        size_t bufferSize;
    }
    else
    {
        /++
            Internal buffer static array.
         +/
        T[bufferSize] buf;

        /++
            Static buffer size.
         +/
        alias bufferSize = originalSize;
    }

    /++
        Current position in the array.
     +/
    ptrdiff_t pos;

    /++
        Position of last entry in the array.
     +/
    ptrdiff_t end;


    static if (dynamic)
    {
        // put
        /++
            Append an item to the end of the buffer.

            If it would be put beyond the end of the buffer, it will be resized to fit.

            Params:
                more = Item to add.
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
            Append an item to the end of the buffer.

            If it would be put beyond the end of the buffer, it will assert.

            Params:
                more = Item to add.
         +/
        void put(/*const*/ T more) @nogc
        in ((end < bufferSize), '`' ~ typeof(this).stringof ~ "` buffer overflow")
        {
            buf[end++] = more;
        }
    }

    static if (dynamic)
    {
        // reserve
        /++
            Reserves enough room for the specified number of elements. If there
            is already enough room, nothing is done. Otherwise the buffer is grown.

            Params:
                reserveSize = Number of elements to reserve size for.
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
        Implements `buf ~= someT` (appending) by wrapping `put`.

        Params:
            op = Operation type, here specialised to "`~`".
            more = Item to add.
     +/
    void opOpAssign(string op : "~")(const T more)
    {
        return put(more);
    }

    // front
    /++
        Fetches the item at the current position of the buffer.

        Returns:
            An item T.
     +/
    T front() const @nogc
    in ((end > 0), '`' ~ typeof(this).stringof ~ "` buffer underrun")
    {
        return buf[pos];
    }

    // popFront
    /++
        Advances the current position to the next item in the buffer.
     +/
    void popFront() @nogc
    {
        if (++pos == end) reset();
    }

    // length
    /++
        Returns what amounts to the current length of the buffer; the distance
        between the current position `pos` and the last element `end`.

        Returns:
            The buffer's current length.
     +/
    size_t length() const @nogc
    {
        return (end - pos);
    }

    // empty
    /++
        Returns whether or not the container is considered empty.

        Mind that the buffer may well still contain old contents. Use `clear`
        to zero it out.

        Returns:
            `true` if there are items available to get via `front`,
            `false` if not.
     +/
    bool empty() const @nogc
    {
        return (end == 0);
    }

    // reset
    /++
        Resets the array positions, effectively soft-emptying the buffer.

        The old elements' values are still there, they will just be overwritten
        as the buffer is appended to.
     +/
    void reset() @nogc
    {
        pos = 0;
        end = 0;
    }

    // clear
    /++
        Zeroes out the buffer's elements, getting rid of old contents.
     +/
    void clear() @nogc
    {
        reset();
        buf[] = T.init;
    }
}

///
unittest
{
    {
        Buffer!(bool, No.dynamic, 4) buffer;

        assert(buffer.empty);
        buffer.put(true);
        buffer.put(false);
        assert(buffer.length == 2);
        buffer.put(true);
        buffer.put(false);

        assert(!buffer.empty);
        assert(buffer.front == true);
        buffer.popFront();
        assert(buffer.front == false);
        buffer.popFront();
        assert(buffer.front == true);
        buffer.popFront();
        assert(buffer.front == false);
        buffer.popFront();
        assert(buffer.empty);
        assert(buffer.buf == [ true, false, true, false ]);
        buffer.put(false);
        assert(buffer.buf == [ false, false, true, false ]);
        buffer.reset();
        assert(buffer.empty);
        buffer.clear();
        assert(buffer.buf == [ false, false, false, false ]);
    }
    {
        Buffer!(string, No.dynamic, 4) buffer;

        assert(buffer.empty);
        buffer.put("abc");
        buffer.put("def");
        buffer.put("ghi");

        assert(!buffer.empty);
        assert(buffer.front == "abc");
        buffer.popFront();
        assert(buffer.front == "def");
        buffer.popFront();
        buffer.put("JKL");
        assert(buffer.front == "ghi");
        buffer.popFront();
        assert(buffer.front == "JKL");
        buffer.popFront();
        assert(buffer.empty);
        assert(buffer.buf == [ "abc", "def", "ghi", "JKL" ]);
        buffer.put("MNO");
        assert(buffer.buf == [ "MNO", "def", "ghi", "JKL" ]);
        buffer.clear();
        assert(buffer.buf == [ string.init, string.init, string.init, string.init ]);
    }
    {
        Buffer!(char, No.dynamic, 64) buffer;
        buffer ~= 'a';
        buffer ~= 'b';
        buffer ~= 'c';
        assert(buffer.buf[0..3] == "abc");

        foreach (char_; buffer)
        {
            assert((char_ == 'a') || (char_ == 'b') || (char_ == 'c'));
        }
    }
    {
        Buffer!(int, Yes.dynamic, 3) buffer;
        assert(!buffer.buf.length);
        buffer ~= 1;
        assert(buffer.buf.length == 3);
        buffer ~= 2;
        buffer ~= 3;
        assert(buffer.front == 1);
        buffer.popFront();
        assert(buffer.front == 2);
        buffer.popFront();
        assert(buffer.front == 3);
        buffer.popFront();
        assert(buffer.empty);
        buffer.reserve(64);
        assert(buffer.buf.length == 64);
        buffer.reserve(63);
        assert(buffer.buf.length == 64);
    }
    {
        Buffer!(char, No.dynamic, 4) buffer;
        buffer ~= 'a';
        buffer ~= 'b';
        buffer ~= 'c';
        buffer ~= 'd';
        assert(buffer.buf == "abcd");
        assert(buffer.length == 4);
        buffer.reset();
        assert(buffer.buf == "abcd");
        buffer.clear();
        assert(buffer.buf == typeof(buffer.buf).init);
    }
}


// CircularBuffer
/++
    Simple circular-ish buffer for storing items of type `T` that discards elements
    when the maximum size is reached. Does not use manual memory allocation.

    It can use a static array internally to store elements on the stack, which
    imposes a hard limit on how many items can be added, or a dynamic heap one
    with a resizable buffer.

    Example:
    ---
    CircularBuffer!(int, Yes.dynamic) buf;
    buf.resize(3);
    buf.put(1);
    buf.put(2);
    buf.put(3);
    but.put(4);
    assert(buf.front == 4);
    assert(buf.buf == [ 4, 2, 3 ]);
    ---

    Params:
        T = Buffer item type.
        dynamic = Whether to use a dynamic array whose size can be grown at
            runtime, or to use a static array with a fixed size. Trying to add
            more elements than there is room for will wrap around and discard elements.
            Defaults to `No.dynamic`; a static buffer.
        originalSize = How many items to allocate space for in the case of a
            static array.
 +/
struct CircularBuffer(T, Flag!"dynamic" dynamic = No.dynamic, size_t originalSize = 16)
if (originalSize > 0)
{
private:
    static if (dynamic)
    {
        // buf
        /++
            Internal buffer dynamic array.
         +/
        T[] buf;
    }
    else
    {
        // buf
        /++
            Internal buffer static array.
         +/
        T[originalSize] buf;
    }

    // head
    /++
        Head position in the internal buffer.
     +/
    size_t head;

    // tail
    /++
        Tail position in the internal buffer.
     +/
    size_t tail;

    // caughtUp
    /++
        Whether or not [head] and [tail] point to the same position in the
        context of a circular array.
     +/
    bool caughtUp;

    // initialised
    /++
        Whether or not at least one element has been added.
     +/
    bool initialised;

public:
    // front
    /++
        Returns the front element.

        Returns:
            An item T.
     +/
    auto front()
    in ((buf.length > 0), "Tried to get `front` from an unresized " ~ typeof(this).stringof)
    {
        return buf[head];
    }

    // put
    /++
        Append an item to the buffer.

        If it would be put beyond the end of the buffer, it will wrap around and
        truncate old values.

        Params:
            item = Item to add.
     +/
    void put(T item) pure @safe @nogc nothrow
    in ((buf.length > 0), "Tried to `put` something into an unresized " ~ typeof(this).stringof)
    {
        if (initialised) ++head %= buf.length;
        buf[head] = item;
        tail = head;
        caughtUp = true;
        initialised = true;
    }

    // popFront
    /++
        Advances the current position to the next item in the buffer.
     +/
    void popFront() pure @safe @nogc nothrow
    in ((buf.length > 0), "Tried to `popFront` an unresized " ~ typeof(this).stringof)
    in (!empty, "Tried to `popFront` an empty " ~ typeof(this).stringof)
    {
        if (head == 0)
        {
            head = (buf.length + (-1));
            caughtUp = false;
        }
        else
        {
            --head;
        }
    }

    static if (dynamic)
    {
        // resize
        /++
            Resizes the internal buffer to a specified size.

            Params:
                size = New size.
         +/
        void resize(const size_t size) pure @safe nothrow
        {
            buf.length = size;
            if (head >= buf.length) head = buf.length +(-1);
            if (tail >= buf.length) tail = buf.length +(-1);
        }
    }

    // opOpAssign
    /++
        Implements `buf ~= someT` (appending) by wrapping `put`.

        Params:
            op = Operation type, here specialised to "`~`".
            more = Item to add.
     +/
    void opOpAssign(string op : "~")(const T more) pure @safe @nogc nothrow
    {
        return put(more);
    }

    // size
    /++
        Returns the size of the internal buffer.

        Returns:
            Internal buffer size.
     +/
    auto size() const
    {
        return buf.length;
    }

    // empty
    /++
        Returns whether or not the container is considered empty.

        Mind that the buffer may well still contain old contents. Use `clear`
        to zero it out.

        Returns:
            `true` if there are items available to get via `front`,
            `false` if not.
     +/
    auto empty() const
    {
        return !caughtUp && (head == tail);
    }

    // save
    /++
        Implements Range `save`.

        Returns:
            A shallow copy of the container.
     +/
    auto save()
    {
        return this;
    }

    // dup
    /++
        Makes a deep(er) duplicate of the container.

        Returns:
            A copy of the current container with the internal buffer explicitly `.dup`ed.
     +/
    auto dup()
    {
        auto copy = this;

        static if (dynamic)
        {
            copy.buf = this.buf.dup;
        }

        return copy;
    }

    // clear
    /++
        Zeroes out the buffer's elements, getting rid of old contents.
     +/
    void clear() pure @safe @nogc nothrow
    {
        head = 0;
        tail = 0;
        buf[] = T.init;
    }
}

///
unittest
{
    import std.conv : text;

    {
        CircularBuffer!(int, Yes.dynamic) buf;
        buf.resize(3);

        buf.put(1);
        assert((buf.front == 1), buf.front.text);
        buf.put(2);
        assert((buf.front == 2), buf.front.text);
        buf.put(3);
        assert((buf.front == 3), buf.front.text);
        buf ~= 4;
        assert((buf.front == 4), buf.front.text);
        assert((buf.buf == [ 4, 2, 3 ]), buf.buf.text);
        buf.popFront();
        buf.popFront();
        buf.popFront();
        assert(buf.empty);
    }
    {
        CircularBuffer!(int, No.dynamic, 3) buf;
        //buf.resize(3);

        buf.put(1);
        assert((buf.front == 1), buf.front.text);
        buf.put(2);
        assert((buf.front == 2), buf.front.text);
        buf.put(3);
        assert((buf.front == 3), buf.front.text);
        buf ~= 4;
        assert((buf.front == 4), buf.front.text);
        assert((buf.buf == [ 4, 2, 3 ]), buf.buf.text);
        buf.popFront();
        buf.popFront();
        buf.popFront();
        assert(buf.empty);
    }
}
