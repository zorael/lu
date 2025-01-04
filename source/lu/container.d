/++
    Containers.

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
    {
        RehashingAA!(int[string]) aa;
        aa.minimumNeededForRehash = 2;

        aa["abc"] = 123;
        aa["def"] = 456;
        assert((aa.newKeysSinceLastRehash == 2), aa.newKeysSinceLastRehash.to!string);
        assert((aa.numRehashes == 0), aa.numRehashes.to!string);
        aa["ghi"] = 789;
        assert((aa.numRehashes == 1), aa.numRehashes.to!string);
        assert((aa.newKeysSinceLastRehash == 0), aa.newKeysSinceLastRehash.to!string);
        aa.rehash();
        assert((aa.numRehashes == 2), aa.numRehashes.to!string);

        auto realAA = cast(int[string])aa;
        assert("abc" in realAA);
        assert("def" in realAA);

        auto alsoRealAA = aa.aaOf;
        assert("ghi" in realAA);
        assert("jkl" !in realAA);

        auto aa2 = aa.dup;
        aa2["jkl"] = 123;
        assert("jkl" in aa2);
        assert("jkl" !in aa);
    }
    {
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        aa[1] = "one";
        aa[2] = "two";
        aa[3] = "three";

        auto hasOne = aa.has(1);
        assert(hasOne);
        assert(aa[1] == "one");

        assert(aa[2] == "two");

        auto three = aa.get(3);
        assert(three == "three");

        auto four = aa.get(4, "four");
        assert(four == "four");

        auto five = aa.require(5, "five");
        assert(five == "five");
        assert(aa[5] == "five");

        auto keys = aa.keys;
        assert(keys.canFind(1));
        assert(keys.canFind(5));
        assert(!keys.canFind(6));

        auto values = aa.values;
        assert(values.canFind("one"));
        assert(values.canFind("four"));
        assert(!values.canFind("six"));

        aa.rehash();
    }
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.container;

private:

import std.typecons : Flag, No, Yes;

public:


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
            Defaults to `No.dynamic`; a static array.
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
        void put(/*const*/ T more) pure @safe nothrow
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
        void put(/*const*/ T more) pure @safe nothrow @nogc
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
        void reserve(const size_t reserveSize) pure @safe nothrow
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
    void opOpAssign(string op : "~")(/*const*/ T more) pure @safe nothrow
    {
        return put(more);
    }

    // front
    /++
        Fetches the item at the current position of the buffer.

        Returns:
            An item T.
     +/
    ref auto front() inout pure @safe nothrow @nogc
    in ((end > 0), '`' ~ typeof(this).stringof ~ "` buffer underrun")
    {
        return buf[pos];
    }

    // popFront
    /++
        Advances the current position to the next item in the buffer.
     +/
    void popFront() pure @safe nothrow @nogc
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
    auto length() const inout
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
    auto empty() const inout
    {
        return (end == 0);
    }

    // reset
    /++
        Resets the array positions, effectively soft-emptying the buffer.

        The old elements' values are still there, they will just be overwritten
        as the buffer is appended to.
     +/
    void reset() pure @safe nothrow @nogc
    {
        pos = 0;
        end = 0;
    }

    // clear
    /++
        Zeroes out the buffer's elements, getting rid of old contents.
     +/
    void clear() pure @safe nothrow @nogc
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
if (originalSize > 1)
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
    ref auto front() inout
    in ((buf.length > 0), "Tried to get `front` from a zero-sized " ~ typeof(this).stringof)
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
    in ((buf.length > 0), "Tried to `put` something into a zero-sized " ~ typeof(this).stringof)
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
    in ((buf.length > 0), "Tried to `popFront` a zero-sized " ~ typeof(this).stringof)
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
    auto size() const inout
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
    auto empty() const inout
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
        Resets the buffer pointers but doesn't clear the contents.
     +/
    void reset() pure @safe @nogc nothrow
    {
        head = 0;
        tail = 0;
    }

    // clear
    /++
        Zeroes out the buffer's elements, getting rid of old contents.
     +/
    void clear() pure @safe @nogc nothrow
    {
        reset();
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
        assert((buf.buf[] == [ 4, 2, 3 ]), buf.buf.text);
        buf ~= 5;
        assert((buf.front == 5), buf.front.text);
        buf ~= 6;
        assert((buf.front == 6), buf.front.text);
        assert((buf.buf[] == [ 4, 5, 6 ]), buf.buf.text);
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
        assert((buf.buf[] == [ 4, 2, 3 ]), buf.buf.text);
        buf.popFront();
        buf.popFront();
        buf.popFront();
        assert(buf.empty);
    }
    {
        CircularBuffer!(int, No.dynamic, 2) buf;
        //buf.resize(2);

        buf.put(1);
        assert((buf.front == 1), buf.front.text);
        buf.put(2);
        assert((buf.front == 2), buf.front.text);
        buf.put(3);
        assert((buf.front == 3), buf.front.text);
        buf ~= 4;
        assert((buf.front == 4), buf.front.text);
        assert((buf.buf[] == [ 3, 4 ]), buf.buf.text);
        buf.popFront();
        buf.popFront();
        assert(buf.empty);
        //buf.popFront();  // AssertError
    }
    {
        CircularBuffer!(int, No.dynamic, 2) buf;
        //buf.resize(2);

        buf.put(1);
        assert((buf.front == 1), buf.front.text);
        buf.put(2);
        assert((buf.front == 2), buf.front.text);
        buf.put(3);
        assert((buf.front == 3), buf.front.text);
        buf ~= 4;
        assert((buf.front == 4), buf.front.text);
        assert((buf.buf[] == [ 3, 4 ]), buf.buf.text);
        auto savedBuf = buf.save();
        buf.popFront();
        buf.popFront();
        assert(buf.empty);
        assert((savedBuf.front == 4), savedBuf.front.text);
        savedBuf.popFront();
        auto savedBuf2 = savedBuf.save();
        savedBuf.popFront();
        assert(savedBuf.empty);
        assert((savedBuf2.front == 3), savedBuf2.front.text);
        savedBuf2.popFront();
        assert(savedBuf2.empty);
    }
}


// RehashingAA
/++
    A wrapper around a native associative array that you can controllably set to
    automatically rehash as entries are added.

    Params:
        AA = Associative array type.
        V = Value type.
        K = Key type.
 +/
struct RehashingAA(AA : V[K], V, K)
{
private:
    import std.range.primitives : ElementEncodingType;
    import std.traits : isIntegral;

    /++
        Internal associative array.
     +/
    AA aa;

    /++
        The number of times this instance has rehashed itself. Private value.
     +/
    uint _numRehashes;

    /++
        The number of new entries that has been added since the last rehash. Private value.
     +/
    uint _newKeysSinceLastRehash;

    /++
        The number of keys (and length of the array) when the last rehash took place.
        Private value.
     +/
    size_t _lengthAtLastRehash;

public:
    /++
        The minimum number of additions needed before the first rehash takes place.
     +/
    uint minimumNeededForRehash = 64;

    /++
        The modifier by how much more entries must be added before another rehash
        takes place, with regards to the current [RehashingAA.aa|aa] length.

        A multiplier of `2.0` means the associative array will be rehashed as
        soon as its length doubles in size. Must be more than 1.
     +/
    double rehashThresholdMultiplier = 1.5;

    // opIndexAssign
    /++
        Assigns a value into the internal associative array. If it created a new
        entry, then call [maybeRehash] to bump the internal counter and maybe rehash.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        ---

        Params:
            value = Value.
            key = Key.
     +/
    void opIndexAssign(V value, K key)
    {
        if (auto existing = key in aa)
        {
            *existing = value;
        }
        else
        {
            aa[key] = value;
            maybeRehash();
        }
    }

    // opIndex
    /++
        Returns the value for the passed key in the internal associative array.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        writeln(aa["abc"]);  // 123
        ---

        Params:
            key = Key.

        Returns:
            The value for the key `key`.
     +/
    ref auto opIndex(K key)
    {
        return aa[key];
    }

    // opIndexUnary
    /++
        Performs a unary operation on a value in the internal associative array.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        writeln(-aa["abc"]);  // -123
        ---

        Params:
            op = Unary operation as a string.
            key = Key.

        Returns:
            The result of the operation.
     +/
    ref auto opIndexUnary(string op)(K key)
    {
        mixin("return " ~ op ~ "aa[key];");
    }

    // opAssign
    /++
        Inherit a native associative array into [RehashingAA.aa|aa].

        Example:
        ---
        RehashingAA!(int[string]) aa;
        int[string] nativeAA;

        nativeAA["abc"] = 123;
        aa = nativeAA;
        assert(aa["abc"] == 123);
        ---

        Params:
            aa = Other associative array.
     +/
    void opAssign(V[K] aa)
    {
        this.aa = aa;
        this.rehash();
        _numRehashes = 0;
    }

    // opIndexOpAssign
    /++
        Performs an assingment operation on a value in the internal associative array.

        Example:
        ---
        RehashingAA!(int[int]) aa;
        aa[1] = 42;
        aa[1] += 1;
        assert(aa[1] == 43);

        aa[1] *= 2;
        assert(aa[1] == 86);
        ---

        Params:
            op = Assignment operation as a string.
            value = Value to assign.
            key = Key.
     +/
    void opIndexOpAssign(string op, U)(U value, K key)
    if (is(U == V) || is(U == ElementEncodingType!V))
    {
        mixin("aa[key] " ~ op ~ "= value;");
        maybeRehash();
    }

    // opCast
    /++
        Allows for casting this into the base associative array type.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        auto native = cast(int[string])aa;
        assert(native["abc"] == 123);
        ---

        Params:
            T = Type to cast to, here the same as the type of [RehashingAA.aa|aa].

        Returns:
            The internal associative array.
     +/
    ref auto opCast(T : AA)() inout
    {
        return aa;
    }

    // aaOf
    /++
        Returns the internal associative array, for when the wrapper is insufficient.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        static assert(is(typeof(aa.aaOf) == int[string]));
        ---

        Returns:
            The internal associative array.
     +/
    ref auto aaOf() inout
    {
        return aa;
    }

    // remove
    /++
        Removes a key from the [RehashingAA.aa|aa] associative array by merely
        invoking `.remove`.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        assert("abc" in aa);

        aa.remove("abc");
        assert("abc" !in aa);
        ---

        Params:
            key = The key to remove.

        Returns:
            Whatever `aa.remove(key)` returns.
     +/
    auto remove(K key)
    {
        //scope(exit) maybeRehash();
        return aa.remove(key);
    }

    // maybeRehash
    /++
        Bumps the internal counter of new keys since the last rehash, and depending
        on the resulting value of it, maybe rehashes.

        Returns:
            `true` if the associative array was rehashed; `false` if not.
     +/
    auto maybeRehash()
    {
        if (++_newKeysSinceLastRehash > minimumNeededForRehash)
        {
            if (aa.length > (_lengthAtLastRehash * rehashThresholdMultiplier))
            {
                this.rehash();
                return true;
            }
        }

        return false;
    }

    // clear
    /++
        Clears the internal associative array and all counters.
     +/
    void clear()
    {
        aa.clear();
        _newKeysSinceLastRehash = 0;
        _lengthAtLastRehash = 0;
        _numRehashes = 0;
    }

    // rehash
    /++
        Rehashes the internal associative array, bumping the rehash counter and
        zeroing the keys-added counter. Additionally invokes the [onRehashDg] delegate.

        Returns:
            A reference to the rehashed internal array.
     +/
    ref auto rehash() @system
    {
        scope(exit) if (onRehashDg) onRehashDg(aa);
        _lengthAtLastRehash = aa.length;
        _newKeysSinceLastRehash = 0;
        ++_numRehashes;
        aa.rehash();
        return this;
    }

    // numRehashes
    /++
        The number of times this instance has rehashed itself. Accessor.

        Returns:
            The number of times this instance has rehashed itself.
     +/
    auto numRehashes() inout
    {
        return _numRehashes;
    }

    // numKeysAddedSinceLastRehash
    /++
        The number of new entries that has been added since the last rehash. Accessor.

        Returns:
            The number of new entries that has been added since the last rehash.
     +/
    auto newKeysSinceLastRehash() inout
    {
        return _newKeysSinceLastRehash;
    }

    // opBinaryRight
    /++
        Wraps `key in aa` to the internal associative array.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        assert("abc" in aa);
        ---

        Params:
            op = Operation, here "in".
            key = Key.

        Returns:
            A pointer to the value of the key passed, or `null` if it isn't in
            the associative array
     +/
    auto opBinaryRight(string op : "in")(K key) inout
    {
        return key in aa;
    }

    // byValue
    /++
        Wraps the internal associative array's `byValue` function.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        foreach (value; aa.byValue)
        {
            writeln(value);
        }
        ---

        Returns:
            The Voldemort returned from the associative array's `byValue` function.
     +/
    auto byValue() inout
    {
        return aa.byValue();
    }

    // byKey
    /++
        Wraps the internal associative array's `byKey` function.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        foreach (key; aa.byKey)
        {
            writeln(key);
        }
        ---

        Returns:
            The Voldemort returned from the associative array's `byKey` function.
     +/
    auto byKey() inout
    {
        return aa.byKey();
    }

    // values
    /++
        Wraps the internal associative array's `values` function.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        auto values = aa.values;  // allocate it once

        // Order cannot be relied upon
        foreach (val; [ 123, 456, 789 ])
        {
            import std.algorithm.searching : canFind;
            assert(values.canFind(val));
        }
        ---

        Returns:
            A new dynamic array of all values, as returned by the associative array's
            `values` function.
     +/
    auto values() const
    {
        return aa.values;
    }

    // keys
    /++
        Wraps the internal associative array's `keys` function.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        auto keys = aa.keys;  // allocate it once

        // Order cannot be relied upon
        foreach (key; [ "abc", "def", "ghi" ])
        {
            assert(key in aa);
        }
        ---

        Returns:
            A new dynamic array of all keys, as returned by the associative array's
            `keys` function.
     +/
    auto keys() const
    {
        return aa.keys;
    }

    // byKeyValue
    /++
        Wraps the internal associative array's `byKeyValue` function.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        foreach (key, value; aa.byKeyValue)
        {
            writeln(key, " = ", value);
        }
        ---

        Returns:
            A new range of all key-value pairs, as returned by the associative
            array's `byKeyValue` function.
     +/
    auto byKeyValue() inout
    {
        return aa.byKeyValue();
    }

    // length
    /++
        Returns the length of the internal associative array.

        Returns:
            The length of the internal associative array.
     +/
    auto length() const inout
    {
        return aa.length;
    }

    // dup
    /++
        Duplicates this. Explicitly copies the internal associative array.

        If `copyState: false` is passed, it will not copy over the internal state
        such as the number of rehashes and keys added since the last rehash.

        Example:
        ---
        RehashingAA!(int[string]) aa;
        aa.minimumNeededForRehash = 2;

        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;
        assert(aa.numRehashes == 1);

        auto aa2 = aa.dup(copyState: false);
        assert(aa2 == aa);
        assert(aa2.numRehashes == 1);

        auto aa3 = aa.dup;  //(copyState: false);
        assert(aa3 == aa);
        assert(aa3.numRehashes == 0);
        ---

        Params:
            copyState = (Optional) Whether or not to copy over the internal state.

        Returns:
            A duplicate of this object.
     +/
    auto dup(const bool copyState = false)
    {
        auto copy = copyState ?
            this :
            typeof(this).init;

        copy.aa = this.aa.dup;
        return copy;
    }

    // require
    /++
        Returns the value for the key `key`, inserting `value` lazily if it is not present.

        Example:
        ---
        RehashingAA!(string[int]) aa;
        string hello = aa.require(42, "hello");
        assert(hello == "hello");
        assert(aa[42] == "hello");
        ---

        Params:
            key = Key.
            value = Value to insert if the key is not present.

        Returns:
            The value for the key `key`, or `value` if it was not present.
     +/
    ref auto require(K key, lazy V value)
    {
        if (auto existing = key in aa)
        {
            return *existing;
        }
        else
        {
            aa[key] = value;
            return value;
        }
    }

    // get
    /++
        Retrieves the value for the key `key`, or returns the default `value`
        if there was none.

        Example:
        ---
        RehashingAA!(int[int]) aa;
        aa[1] = 42;
        aa[2] = 99;

        assert(aa.get(1, 0) == 42);
        assert(aa.get(2, 0) == 99);
        assert(aa.get(0, 0) == 0);
        assert(aa.get(3, 999) == 999);

        assert(0 !in aa);
        assert(3 !in aa);
        ---
     +/
    ref auto get(K key, lazy V value)
    {
        if (auto existing = key in aa)
        {
            return *existing;
        }
        else
        {
            return value;
        }
    }

    static if (isIntegral!K)
    {
        /++
            Reserves a unique key in the associative array.

            Note: The key type must be an integral type.

            Example:
            ---
            RehashingAA!(string[int]) aa;

            int i = aa.uniqueKey;
            assert(i > 0);
            assert(i in aa);
            assert(aa[i] == string.init);
            ---

            Params:
                min = Optional minimum key value; defaults to `1``.
                max = Optional maximum key value; defaults to `K.max`, where `K` is
                    the key type of the passed associative array.
                value = Optional value to assign to the key; defaults to `V.init`,
                    where `V` is the value type of the passed associative array.

            Returns:
                A unique key for the passed associative array, for which there is now
                a value of `value`.`

            See_Also:
                [lu.array.uniqueKey]
         +/
        auto uniqueKey()
            (K min = 1,
            K max = K.max,
            V value = V.init)
        {
            static import lu.array;
            return lu.array.uniqueKey(aa, min, max, value);
        }
    }

    // update
    /++
        Updates the value for the key `key` in the internal associative array,
        invoking the first of the passed delegate to insert a new value if it
        doesn't exist, or the second selegate to modify it in place if it does.

        Note: Doesn't compile with compilers earlier than version 2.088.

        Example:
        ---
        RehashingAA!(int[int]) aa;

        assert(1 !in aa);

        aa.update(1,
            () => 42,
            (int i) => i + 1);
        assert(aa[1] == 42);

        aa.update(1,
            () => 42,
            (int i) => i + 1);
        assert(aa[1] == 43);
        ---

        Params:
            key = Key.
            createDg = Delegate to invoke to create a new value if it doesn't exist.
            updateDg = Delegate to invoke to update an existing value.
     +/
    static if (__VERSION__ >= 2088L)
    void update(U)
        (K key,
        scope V delegate() createDg,
        scope U delegate(K) updateDg)
    if (is(U == V) || is(U == void))
    {
        .object.update(aa, key, createDg, updateDg);
    }

    // opEquals
    /++
        Implements `opEquals` for this type, comparing the internal associative
        array with that of another `RehashingAA`.

        Example:
        ---
        RehashingAA!(string[int]) aa1;
        aa1[1] = "one";

        RehashingAA!(string[int]) aa2;
        aa2[1] = "one";
        assert(aa1 == aa2);

        aa2[2] = "two";
        assert(aa1 != aa2);

        aa1[2] = "two";
        assert(aa1 == aa2);
        ---

        Params:
            other = Other `RehashingAA` whose internal associative array to compare
                with the one of this instance.

        Returns:
            `true` if the internal associative arrays are equal; `false` if not.
     +/
    auto opEquals(typeof(this) other)
    {
        return (aa == other.aa);
    }

    // opEquals
    /++
        Implements `opEquals` for this type, comparing the internal associative
        array with a different one.

        Example:
        ---
        RehashingAA!(string[int]) aa1;
        aa1[1] = "one";
        aa1[2] = "two";

        string[int] aa2;
        aa2[1] = "one";

        assert(aa1 != aa2);

        aa2[2] = "two";
        assert(aa1 == aa2);
        ---

        Params:
            other = Other associative array to compare the internal one with.

        Returns:
            `true` if the internal associative arrays are equal; `false` if not.
     +/
    auto opEquals(AA other)
    {
        return (aa == other);
    }

    // this
    /++
        Constructor.

        Params:
            aa = Associative array to inherit. Taken by reference for now.
     +/
    this(AA aa) pure @safe nothrow @nogc
    {
        this.aa = aa;
    }

    // onRehashDg
    /++
        Delegate called when rehashing takes place.

        Example:
        ---
        uint counter;

        void dg(ref int[string] aa)
        {
            ++counter;
            writeln("Rehashed!");
        }

        RehashingAA!(int[string]) aa;
        aa.onRehashDg = &dg;
        aa.minimumNeededForRehash = 2;

        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        assert(aa.numRehashes == 1);
        assert(counter == 1);
        ---
     +/
    void delegate(ref AA) @system onRehashDg;
}

///
unittest
{
    import std.conv : to;

    {
        uint counter;

        void dg(ref int[string] aa)
        {
            ++counter;
        }

        RehashingAA!(int[string]) aa;
        aa.onRehashDg = &dg;
        aa.minimumNeededForRehash = 2;

        aa["abc"] = 123;
        aa["def"] = 456;
        assert((aa.newKeysSinceLastRehash == 2), aa.newKeysSinceLastRehash.to!string);
        assert((aa.numRehashes == 0), aa.numRehashes.to!string);
        aa["ghi"] = 789;
        assert((aa.numRehashes == 1), aa.numRehashes.to!string);
        assert((aa.newKeysSinceLastRehash == 0), aa.newKeysSinceLastRehash.to!string);
        aa.rehash();
        assert((aa.numRehashes == 2), aa.numRehashes.to!string);
        assert((counter == 2), counter.to!string);

        auto realAA = cast(int[string])aa;
        assert("abc" in realAA);
        assert("def" in realAA);

        auto alsoRealAA = aa.aaOf;
        assert("ghi" in alsoRealAA);
        assert("jkl" !in alsoRealAA);

        auto aa2 = aa.dup(copyState: true);
        assert((aa2.numRehashes == 2), aa2.numRehashes.to!string);
        aa2["jkl"] = 123;
        assert("jkl" in aa2);
        assert("jkl" !in aa);

        auto aa3 = aa.dup();  //(copyState: false);
        assert(!aa3.numRehashes, aa3.numRehashes.to!string);
        assert(aa3.aaOf == aa.aaOf);
        assert(aa3.aaOf !is aa.aaOf);
    }
    {
        RehashingAA!(int[int]) aa;
        aa[1] = 2;
        ++aa[1];
        assert((aa[1] == 3), aa[1].to!string);
        assert((-aa[1] == -3), (-aa[1]).to!string);
    }
    {
        RehashingAA!(int[int]) aa;
        aa[1] = 42;
        aa[1] += 1;
        assert(aa[1] == 43);

        aa[1] *= 2;
        assert(aa[1] == 86);
    }
    {
        RehashingAA!(int[string]) aa;
        static assert(is(typeof(aa.aaOf()) == int[string]));

        aa["abc"] = 123;
        auto native = cast(int[string])aa;
        assert(native["abc"] == 123);
    }
    {
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        assert((aa.length == 2), aa.length.to!string);
        aa.remove("abc");
        assert((aa.length == 1), aa.length.to!string);
        aa.remove("def");
        assert(!aa.length, aa.length.to!string);
    }
    {
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        foreach (value; aa.byValue)
        {
            import std.algorithm.comparison : among;
            assert(value.among!(123, 456, 789), value.to!string);
        }
    }
    {
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        foreach (key; aa.byKey)
        {
            assert(key in aa);
        }
    }
    {
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        auto values = aa.values;  // allocate it once

        // Order cannot be relied upon
        foreach (val; [ 123, 456, 789 ])
        {
            import std.algorithm.searching : canFind;
            assert(values.canFind(val));
        }
    }
    {
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        auto keys = aa.keys;  // allocate it once

        // Order cannot be relied upon
        foreach (key; [ "abc", "def", "ghi" ])
        {
            assert(key in aa);
        }
    }
    {
        RehashingAA!(int[string]) aa;
        aa["abc"] = 123;
        aa["def"] = 456;
        aa["ghi"] = 789;

        foreach (kv; aa.byKeyValue)
        {
            assert(kv.key in aa);
            assert(aa[kv.key] == kv.value);
        }
    }
    {
        RehashingAA!(string[int]) aa;
        string hello = aa.require(42, "hello");
        assert(hello == "hello");
        assert(aa[42] == "hello");
    }
    {
        RehashingAA!(int[int]) aa;
        aa[1] = 42;
        aa[2] = 99;

        assert(aa.get(1, 0) == 42);
        assert(aa.get(2, 0) == 99);
        assert(aa.get(0, 0) == 0);
        assert(aa.get(3, 999) == 999);

        assert(0 !in aa);
        assert(3 !in aa);
    }
    static if (__VERSION__ >= 2088L)
    {{
        RehashingAA!(int[int]) aa;

        assert(1 !in aa);

        aa.update(1,
            () => 42,
            (int i) => i + 1);
        assert(aa[1] == 42);

        aa.update(1,
            () => 42,
            (int i) => i + 1);
        assert(aa[1] == 43);
    }}
    {
        RehashingAA!(string[int]) aa1;
        aa1[1] = "one";

        RehashingAA!(string[int]) aa2;
        aa2[1] = "one";
        assert(aa1 == aa2);

        aa2[2] = "two";
        assert(aa1 != aa2);

        aa1[2] = "two";
        assert(aa1 == aa2);
    }
    {
        RehashingAA!(string[int]) aa1;
        aa1[1] = "one";
        aa1[2] = "two";

        string[int] aa2;
        aa2[1] = "one";

        assert(aa1 != aa2);

        aa2[2] = "two";
        assert(aa1 == aa2);
    }
    {
        RehashingAA!(string[int]) aa;
        int i = aa.uniqueKey;
        assert(i > 0);
        assert(i in aa);
        assert(aa[i] == string.init);
    }
}


// MutexedAA
/++
    An associative array and a [core.sync.mutex.Mutex|Mutex]. Wraps associative
    array operations in mutex locks.

    Example:
    ---
    MutexedAA!(string[int]) aa;
    aa.setup();  // important!

    aa[1] = "one";
    aa[2] = "two";
    aa[3] = "three";

    auto hasOne = aa.has(1);
    assert(hasOne);
    assert(aa[1] == "one");

    assert(aa[2] == "two");

    auto three = aa.get(3);
    assert(three == "three");

    auto four = aa.get(4, "four");
    assert(four == "four");

    auto five = aa.require(5, "five");
    assert(five == "five");
    assert(aa[5] == "five");

    auto keys = aa.keys;
    assert(keys.canFind(1));
    assert(keys.canFind(5));
    assert(!keys.canFind(6));

    auto values = aa.values;
    assert(values.canFind("one"));
    assert(values.canFind("four"));
    assert(!values.canFind("six"));

    aa.rehash();
    ---

    Params:
        AA = Associative array type.
        V = Value type.
        K = Key type.
 +/
struct MutexedAA(AA : V[K], V, K)
{
private:
    import std.range.primitives : ElementEncodingType;
    import std.traits : isIntegral;
    import core.sync.mutex : Mutex;

    /++
        [core.sync.mutex.Mutex|Mutex] to lock the associative array with.
     +/
    shared Mutex mutex;

public:
    /++
        The internal associative array.
     +/
    shared AA aa;

    /++
        Sets up this instance. Does nothing if it has already been set up.

        Instantiates the [mutex] and minimally initialises the associative array
        by assigning and removing a dummy value.
     +/
    void setup() nothrow
    {
        if (mutex) return;

        mutex = new shared Mutex;
        (cast()mutex).lock_nothrow();

        if (K.init !in cast(AA)aa)
        {
            (cast(AA)aa)[K.init] = V.init;
            (cast(AA)aa).remove(K.init);
        }

        (cast()mutex).unlock_nothrow();
    }

    /++
        Returns whether or not this instance has been set up.

        Returns:
            Whether or not the [mutex] was instantiated, and thus whether this
            instance has been set up.
     +/
    auto isReady() inout
    {
        return (mutex !is null);
    }

    /++
        `aa[key] = value` array assign operation, wrapped in a mutex lock.

        Example:
        ---
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        aa[1] = "one";
        aa[2] = "two";
        ---

        Params:
            value = Value.
            key = Key.

        Returns:
            The value assigned.
     +/
    auto opIndexAssign(V value, K key)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        (cast(AA)aa)[key] = value;
        (cast()mutex).unlock_nothrow();
        return value;
    }

    /++
        `aa[key]` array retrieve operation, wrapped in a mutex lock.

        Example:
        ---
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        // ...

        string one = aa[1];
        writeln(aa[2]);
        ---

        Params:
            key = Key.

        Returns:
            The value assigned.
     +/
    auto opIndex(K key)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto value = (cast(AA)aa)[key];
        (cast()mutex).unlock_nothrow();
        return value;
    }

    /++
        Returns whether or not the passed key is in the associative array.

        Example:
        ---
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        aa[1] = "one";
        assert(aa.has(1));
        ---

        Params:
            key = Key.

        Returns:
            `true` if the key is in the associative array; `false` if not.
     +/
    auto has(K key)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto exists = (key in cast(AA)aa) !is null;
        (cast()mutex).unlock_nothrow();
        return exists;
    }

    /++
        `aa.remove(key)` array operation, wrapped in a mutex lock.

        Example:
        ---
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        aa[1] = "one";
        assert(aa.has(1));

        aa.remove(1);
        assert(!aa.has(1));
        ---

        Params:
            key = Key.

        Returns:
            Whatever `aa.remove(key)` returns.
     +/
    auto remove(K key)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto value = (cast(AA)aa).remove(key);
        (cast()mutex).unlock_nothrow();
        return value;
    }

    static if (isIntegral!K)
    {
        /++
            Reserves a unique key in the associative array.

            Note: The key type must be an integral type.

            Example:
            ---
            MutexedAA!(string[int]) aa;
            aa.setup();  // important!

            int i = aa.uniqueKey;
            assert(i > 0);
            assert(aa.has(i));
            assert(aa[i] == string.init);
            ---

            Params:
                min = Optional minimum key value; defaults to `1``.
                max = Optional maximum key value; defaults to `K.max`, where `K` is
                    the key type of the passed associative array.
                value = Optional value to assign to the key; defaults to `V.init`,
                    where `V` is the value type of the passed associative array.

            Returns:
                A unique key for the passed associative array, for which there is now
                a value of `value`.`

            See_Also:
                [lu.array.uniqueKey]
         +/
        auto uniqueKey()
            (K min = 1,
            K max = K.max,
            V value = V.init)
        in (mutex, typeof(this).stringof ~ " has null Mutex")
        {
            static import lu.array;

            (cast()mutex).lock_nothrow();
            auto key = lu.array.uniqueKey(*(cast(AA*)&aa), min, max, value);
            (cast()mutex).unlock_nothrow();
            return key;
        }
    }

    /++
        Implements `opEquals` for this type, comparing the internal associative
        array with that of another `MutexedAA`.

        Example:
        ---
        MutexedAA!(string[int]) aa1;
        aa1.setup();  // important!
        aa1[1] = "one";

        MutexedAA!(string[int]) aa2;
        aa2.setup();  // as above
        aa2[1] = "one";
        assert(aa1 == aa2);

        aa2[2] = "two";
        assert(aa1 != aa2);

        aa1[2] = "two";
        assert(aa1 == aa2);
        ---

        Params:
            other = Other `MutexedAA` whose internal associative array to compare
                with the one of this instance.

        Returns:
            `true` if the internal associative arrays are equal; `false` if not.
     +/
    auto opEquals(typeof(this) other)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto isEqual = (cast(AA)aa == cast(AA)(other.aa));
        (cast()mutex).unlock_nothrow();
        return isEqual;
    }

    /++
        Implements `opEquals` for this type, comparing the internal associative
        array with a different one.

        Example:
        ---
        MutexedAA!(string[int]) aa1;
        aa1.setup();  // important!
        aa1[1] = "one";
        aa1[2] = "two";

        string[int] aa2;
        aa2[1] = "one";

        assert(aa1 != aa2);

        aa2[2] = "two";
        assert(aa1 == aa2);
        ---

        Params:
            other = Other associative array to compare the internal one with.

        Returns:
            `true` if the internal associative arrays are equal; `false` if not.
     +/
    auto opEquals(AA other)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto isEqual = (cast(AA)aa == other);
        (cast()mutex).unlock_nothrow();
        return isEqual;
    }

    /++
        Rehashes the internal associative array.

        Example:
        ---
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        aa[1] = "one";
        aa[2] = "two";
        aa.rehash();
        ---

        Returns:
            A reference to the rehashed internal array.
     +/
    auto rehash()
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto rehashed = (cast(AA)aa).rehash();
        (cast()mutex).unlock_nothrow();
        return rehashed;
    }

    /++
        Clears the internal associative array.

        Example:
        ---
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        aa[1] = "one";
        aa[2] = "two";
        assert(aa.has(1));

        aa.clear();
        assert(!aa.has(2));
        ---
     +/
    void clear()
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        (cast(AA)aa).clear();
        (cast()mutex).unlock_nothrow();
    }

    /++
        Returns the length of the internal associative array.

        Example:
        ---
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        assert(aa.length == 0);
        aa[1] = "one";
        aa[2] = "two";
        assert(aa.length == 2);
        ---

        Returns:
            The length of the internal associative array.
     +/
    auto length()
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto length = (cast(AA)aa).length;
        (cast()mutex).unlock_nothrow();
        return length;
    }

    /++
        Returns the value for the key `key`, inserting `value` lazily if it is not present.

        Example:
        ---
        MutexedAA!(string[int]) aa;
        aa.setup();  // important!

        assert(!aa.has(42));
        string hello = aa.require(42, "hello");
        assert(hello == "hello");
        assert(aa[42] == "hello");
        ---

        Params:
            key = Key.
            value = Lazy value.

        Returns:
            The value for the key `key`, or `value` if there was no value there.
     +/
    auto require(K key, lazy V value)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        V retval;

        (cast()mutex).lock_nothrow();
        if (auto existing = key in cast(AA)aa)
        {
            retval = *existing;
        }
        else
        {
            (cast(AA)aa)[key] = value;
            retval = value;
        }

        (cast()mutex).unlock_nothrow();
        return retval;
    }

    /++
        Returns a new dynamic array of all the keys in the internal associative array.

        Example:
        ---
        MutexedAA!(int[int]) aa;
        aa.setup();  // important!
        aa[1] = 42;
        aa[2] = 99;

        auto keys = aa.keys;
        assert(keys.canFind(1));
        assert(keys.canFind(2));
        assert(!keys.canFind(3));
        ---

        Returns:
            A new `K[]` of all the AA keys.
     +/
    auto keys()
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto keys = (cast(AA)aa).keys;  // allocates a new array
        (cast()mutex).unlock_nothrow();
        return keys;
    }

    /++
        Returns a new dynamic array of all the values in the internal associative array.

        Example:
        ---
        MutexedAA!(int[int]) aa;
        aa.setup();  // important!
        aa[1] = 42;
        aa[2] = 99;

        auto values = aa.values;
        assert(values.canFind(42));
        assert(values.canFind(99));
        assert(!values.canFind(0));
        ---

        Returns:
            A new `V[]` of all the AA values.
     +/
    auto values()
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto values = (cast(AA)aa).values;  // as above
        (cast()mutex).unlock_nothrow();
        return values;
    }

    /++
        Retrieves the value for the key `key`, or returns the default `value`
        if there was none.

        Example:
        ---
        MutexedAA!(int[int]) aa;
        aa.setup();  // important!
        aa[1] = 42;
        aa[2] = 99;

        assert(aa.get(1, 0) == 42);
        assert(aa.get(2, 0) == 99);
        assert(aa.get(0, 0) == 0);
        assert(aa.get(3, 999) == 999);

        assert(!aa.has(0));
        assert(!aa.has(3));
        ---

        Params:
            key = Key.
            value = Lazy default value.

        Returns:
            The value for the key `key`, or `value` if there was no value there.
     +/
    auto get(K key, lazy V value)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        auto existing = key in cast(AA)aa;
        auto retval = existing ? *existing : value;
        (cast()mutex).unlock_nothrow();
        return retval;
    }

    /++
        Updates the value for the key `key` in the internal associative array,
        invoking the first of the passed delegate to insert a new value if it
        doesn't exist, or the second selegate to modify it in place if it does.

        Note: Doesn't compile with compilers earlier than version 2.088.

        Example:
        ---
        MutexedAA!(int[int]) aa;
        aa.setup();  // important!

        assert(!aa.has(1));

        aa.update(1,
            () => 42,
            (int i) => i + 1);
        assert(aa[1] == 42);

        aa.update(1,
            () => 42,
            (int i) => i + 1);
        assert(aa[1] == 43);
        ---

        Params:
            key = Key.
            createDg = Delegate to invoke to create a new value if it doesn't exist.
            updateDg = Delegate to invoke to update an existing value.
     +/
    static if (__VERSION__ >= 2088L)
    void update(U)
        (K key,
        scope V delegate() createDg,
        scope U delegate(K) updateDg)
    if (is(U == V) || is(U == void))
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        .object.update((*(cast(AA*)&aa)), key, createDg, updateDg);
        (cast()mutex).unlock_nothrow();
    }

    /++
        Implements unary operations by mixin strings.

        Example:
        ---
        MutexedAA!(int[int]) aa;
        aa.setup();  // important!

        aa[1] = 42;
        assert(-aa[1] == -42);
        ---

        Params:
            op = Operation, here a unary operator.
            key = Key.

        Returns:
            The result of the operation.
     +/
    auto opIndexUnary(string op)(K key)
    //if (isIntegral!V)
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        mixin("auto value = " ~ op ~ "(cast(AA)aa)[key];");
        (cast()mutex).unlock_nothrow();
        return value;
    }

    /++
        Implements index assign operations by mixin strings.

        Example:
        ---
        MutexedAA!(int[int]) aa;
        aa.setup();  // important!

        aa[1] = 42;
        aa[1] += 1;
        assert(aa[1] == 43);

        aa[1] *= 2;
        assert(aa[1] == 86);
        ---

        Params:
            op = Operation, here an index assign operator.
            value = Value.
            key = Key.
     +/
    void opIndexOpAssign(string op, U)(U value, K key)
    if (is(U == V) || is(U == ElementEncodingType!V))
    in (mutex, typeof(this).stringof ~ " has null Mutex")
    {
        (cast()mutex).lock_nothrow();
        mixin("(*(cast(AA*)&aa))[key] " ~ op ~ "= value;");
        (cast()mutex).unlock_nothrow();
    }
}

///
unittest
{
    {
        MutexedAA!(string[int]) aa1;
        assert(!aa1.isReady);
        aa1.setup();
        assert(aa1.isReady);
        aa1.setup();  // extra setups ignored

        MutexedAA!(string[int]) aa2;
        aa2.setup();

        aa1[42] = "hello";
        aa2[42] = "world";
        assert(aa1 != aa2);

        aa1[42] = "world";
        assert(aa1 == aa2);

        aa2[99] = "goodbye";
        assert(aa1 != aa2);
    }
    {
        MutexedAA!(string[int]) aa;
        aa.setup();

        assert(!aa.has(42));
        aa.require(42, "hello");
        assert((aa[42] == "hello"), aa[42]);

        bool set1;
        assert(!aa.has(99));
        string world1 = aa.require(99, { set1 = true; return "world"; }());
        assert(set1);
        assert((world1 == "world"), world1);
        assert((aa[99] == "world"), aa[99]);

        bool set2;
        string world2 = aa.require(99, { set2 = true; return "goodbye"; }());
        assert(!set2);
        assert((world2 != "goodbye"), world2);
        assert((aa[99] != "goodbye"), aa[99]);
    }
    {
        import std.concurrency : Tid, send, spawn;
        import std.conv : to;
        import core.time : MonoTime, seconds;

        static immutable timeout = 1.seconds;

        static void workerFn(MutexedAA!(string[int]) aa)
        {
            static void _assert(
                lazy bool condition,
                const string message = "unittest failure",
                const string file = __FILE__,
                const uint line = __LINE__)
            {
                if (!condition)
                {
                    import std.format : format;
                    import std.stdio : writeln;

                    enum pattern = "core.exception.AssertError@%s(%d): %s";
                    immutable assertMessage = pattern.format(file, line, message);
                    writeln(assertMessage);
                    assert(0, assertMessage);
                }
            }

            _assert(aa.isReady, "MutexedAA passed to worker was not set up properly");

            bool halt;

            while (!halt)
            {
                import std.concurrency : OwnerTerminated, receiveTimeout;
                import std.variant : Variant;

                immutable receivedSomething = receiveTimeout(timeout,
                    (bool _)
                    {
                        halt = true;
                    },
                    (int i)
                    {
                        _assert((aa.length == i-1), "Incorrect MutexedAA length before insert");
                        aa[i] = i.to!string;
                        _assert((aa.length == i), "Incorrect MutexedAA length after insert");
                    },
                    (OwnerTerminated _)
                    {
                        halt = true;
                    },
                    (Variant v)
                    {
                        import std.stdio : writeln;
                        writeln("MutexedAA unit test worker received unknown message: ", v);
                        halt = true;
                    }
                );

                if (!receivedSomething) return;
            }
        }

        MutexedAA!(string[int]) aa;
        aa.setup();

        auto worker = spawn(&workerFn, aa);
        immutable start = MonoTime.currTime;

        foreach (/*immutable*/ i; 1..10)  // start at 1 to enable length checks in worker
        {
            worker.send(i);
            aa.setup();
            auto present = aa.has(i);

            while (!present && (MonoTime.currTime - start) < timeout)
            {
                import core.thread : Thread;
                import core.time : msecs;

                static immutable briefWait = 2.msecs;
                Thread.sleep(briefWait);
                present = aa.has(i);
            }

            assert(present, "MutexedAA unit test worker timed out responding to " ~ i.to!string);
            assert((aa[i] == i.to!string), aa[i]);
        }

        worker.send(true);  // halt
    }
    {
        import std.algorithm.searching : canFind;

        MutexedAA!(int[int]) aa;
        aa.setup();

        aa[1] = 42;
        aa[2] = 99;
        assert(aa.length == 2);

        auto keys = aa.keys;
        assert(keys.canFind(1));
        assert(keys.canFind(2));
        assert(!keys.canFind(3));

        auto values = aa.values;
        assert(values.canFind(42));
        assert(values.canFind(99));
        assert(!values.canFind(0));

        assert(aa.get(1, 0) == 42);
        assert(aa.get(2, 0) == 99);
        assert(aa.get(0, 0) == 0);
        assert(aa.get(3, 999) == 999);
    }
    {
        MutexedAA!(int[int]) aa1;
        aa1.setup();

        aa1[1] = 42;
        aa1[2] = 99;

        int[int] aa2;

        aa2[1] = 42;
        assert(aa1 != aa2);

        aa2[2] = 99;
        assert(aa1 == aa2);

        ++aa2[2];
        assert(aa2[2] == 100);

        aa2[1] += 1;
        assert(aa2[1] == 43);

        aa2[1] -= 1;
        assert(aa2[1] == 42);

        aa2[1] *= 2;
        assert(aa2[1] == 84);

        int i = -aa2[1];
        assert(i == -84);
    }
    {
        MutexedAA!(char[][int]) aa;
        aa.setup();

        aa[1] ~= 'a';
        aa[1] ~= 'b';
        aa[1] ~= 'c';
        assert(aa[1] == "abc".dup);

        aa[1] ~= [ 'd', 'e', 'f' ];
        assert(aa[1] == "abcdef".dup);
    }
    {
        MutexedAA!(int[int]) aa;
        aa.setup();

        immutable key = aa.uniqueKey;
        assert(key > 0);

        assert(aa.has(key));
        assert(aa[key] == int.init);
        aa.remove(key);
        assert(!aa.has(key));

        immutable key2 = aa.uniqueKey(1, 2, -1);
        assert(key2 == 1);
        assert(aa.has(key2));
        assert(aa[key2] == -1);
    }
    static if (__VERSION__ >= 2088L)
    {{
        MutexedAA!(int[int]) aa;
        aa.setup();

        assert(!aa.has(1));

        aa.update(1,
            () => 42,
            (int i) => i + 1);
        assert(aa.has(1));
        assert(aa[1] == 42);

        aa.update(1,
            () => 42,
            (int i) => i + 1);
        assert(aa[1] == 43);
    }}
}
