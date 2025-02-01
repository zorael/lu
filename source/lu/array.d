/++
    Simple array utilities.

    Example:
    ---
    string[int] aa;

    immutable key = aa.uniqueKey;

    assert(key > 0);
    assert(key in aa);
    assert(aa[key] == string.init);

    Appender!(int]) sink;
    sink.put(1);
    sink.put(2);
    sink.put(3);

    sink.zero(clear: false);
    assert(sink[] == [ 0, 0, 0 ]);

    sink.zero(clear: false, 42);
    assert(sink[] == [ 42, 42, 42 ]);

    sink.zero();  //(clear: true);
    assert(!sink[].length);

    immutable table = truthTable(1, 3, 5);
    assert((table.length == 6));
    assert(table == [ false, true, false, true, false, true ]);

    enum E { a, b, c, d }

    const enumTable = truthTable(E.b, E.c);
    assert((enumTable.length == 3));
    assert(enumTable == [ false, true, true, false ]);

    static staticTable = truthTable!(Yes.fullEnumRange, E.a, E.b);
    assert(is(typeof(staticTable) == bool[4]));
    assert(staticTable == [ true, true, false, false ]);

    immutable staticNumTable = truthTable!(2, 4, 6);
    assert(is(typeof(staticNumTable) == bool[7]));
    assert(staticNumTable == [ false, false, true, false, true, false, true ]);
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.array;

private:

import lu.traits : isEnum, isImplicitlyConvertibleToSize_t;
import std.array : Appender;
import std.meta : allSatisfy, templateNot;
import std.traits : allSameType, isIntegral, isMutable, isType;
import std.typecons : Flag, No, Yes;

public:


// uniqueKey
/++
    Returns a unique key for the passed associative array. Reserves the key by
    assigning it a value.

    Note: This function will end up in an endless loop if a narrow range of indexes
    is supplied and the associative array already contains values for all of them.

    Example:
    ---
    string[int] aa;
    immutable key = aa.uniqueKey;
    assert(key > 0);
    assert(key in aa);
    assert(aa[key] == string.init);
    ---

    Params:
        aa = Associative array to get a unique key for.
        min = Optional minimum key value; defaults to `1`.
        max = Optional maximum key value; defaults to `K.max`, where `K` is the
            key type of the passed associative array.
        value = Optional value to assign to the key; defaults to `V.init`, where
            `V` is the value type of the passed associative array.

    Returns:
        A unique key for the passed associative array. There will exist an array
        entry for the key, with the value `value`.
 +/
auto uniqueKey(AA : V[K], V, K)
    (ref AA aa,
    K min = 1,
    K max = K.max,
    V value = V.init)
if (isIntegral!K)
in ((max > min), "The upper index bound must be greater than the lower to get a unique key")
{
    import std.random : uniform;

    auto id = uniform(min, max);  // mutable
    while (id in aa) id = uniform(min, max);

    aa[id] = value;  // reserve it
    return id;
}

///
unittest
{
    import std.conv : to;

    {
        string[int] aa;
        immutable key = aa.uniqueKey;
        assert(key in aa);
    }
    {
        long[long] aa;
        immutable key = aa.uniqueKey;
        assert(key in aa);
    }
    {
        shared bool[int] aa;
        immutable key = aa.uniqueKey;
        assert(key in aa);
    }
    {
        int[int] aa;
        immutable key = aa.uniqueKey(5, 6, 42);
        assert(key == 5);
        assert((aa[5] == 42), aa[5].to!string);
    }
}


// zero
/++
    Zeroes out the contents of an [std.array.Appender|Appender].

    This is in contrast to the built-in `.clear()` method, which keeps the
    memory contents and only resets the internal position pointer to the start
    of it.

    Params:
        sink = The [std.array.Appender|Appender] to zero out.
        clear = (Optional) Whether to also call the `.clear()` method of the
            [std.array.Appender|Appender] sink.
        zeroValue = (Optional) The value to zero out the contents with.
 +/
void zero(Sink : Appender!(T[]), T)
    (ref Sink sink,
    const bool clear = true,
    T zeroValue = T.init)
{
    foreach (ref thing; sink[])
    {
        thing = zeroValue;
    }

    if (clear) sink.clear();
}

///
unittest
{
    {
        Appender!(char[]) sink;
        sink.put('a');
        sink.put('b');
        sink.put('c');
        assert(sink[] == ['a', 'b', 'c']);

        sink.zero(clear: false);
        assert(sink[] == [ char.init, char.init, char.init ]);

        sink.put('d');
        assert(sink[] == [ char.init, char.init, char.init, 'd' ]);

        sink.zero(clear: false, 'X');
        assert(sink[] == [ 'X', 'X', 'X', 'X' ]);

        sink.zero(clear: true);
        assert(!sink[].length);
    }
    {
        Appender!(string[]) sink;
        sink.put("abc");
        sink.put("def");
        sink.put("ghi");
        assert(sink[] == [ "abc", "def", "ghi" ]);

        sink.zero(clear: false, "(empty)");
        assert(sink[] == [ "(empty)", "(empty)", "(empty)" ]);

        sink.zero(clear: false);
        assert(sink[] == [ string.init, string.init, string.init ]);

        sink.zero(clear: true);
        assert(!sink[].length);
    }
}


// truthTable
/++
    Generates a truth table from a list of runtime numbers.

    The table is an array of booleans, where each index corresponds to a number
    in the input list. The boolean at each index is `true` if the number is in
    the input list, and `false` otherwise.

    Can be used during compile-time. Produces a dynamic array unless a
    `highestValueOverride` is provided, in which case it will be a static array
    sized to accomodate that value.

    If the list of numbers is known at compile-time, there is also an overload
    that, given the numbers as template arguments, also produces a static array.

    Note: This is not a sparse array and will be as large as requested.

    Example:
    ---
    const table = truthTable(1, 3, 5);
    assert(table.length == 6);
    assert(table == [ false, true, false, true, false, true ]);
    assert(table == [ 0, 1, 0, 1, 0, 1 ]);

    assert(!table[0]);
    assert( table[1]);
    assert(!table[2]);
    assert( table[3]);
    assert(!table[4]);
    assert( table[5]);

    const staticTable = truthTable!5(1, 2, 3);
    assert(staticTable.length == 6);
    assert(staticTable == [ true, true, true, false, false, false ]);
    assert(staticTable == [ 1, 1, 1, 0, 0, 0 ]);
    ---

    Params:
        highestValueOverride = (Optional) The highest value the truth table should
            size itself to accomodate for. If not set, the highest value in the
            input list is used.
        numbers = The numbers to generate a truth table from.

    Returns:
        A truth table as an array of booleans.

    Throws:
        [ArrayException] if a negative number is passed, or if a
        `highestValueOverride` is set and a number is out of bounds.
 +/
auto truthTable(int highestValueOverride = 0, Numbers...)(Numbers numbers)
if (Numbers.length &&
    allSatisfy!(isImplicitlyConvertibleToSize_t, Numbers))
{
    static if (highestValueOverride < 0)
    {
        enum message = "Negative highest value overrides are not allowed in a truth table";
        static assert(0, message);
    }

    static if (highestValueOverride > 0)
    {
        bool[highestValueOverride+1] table;
    }
    else
    {
        size_t highestValue;

        foreach (number; numbers)
        {
            if (cast(ptrdiff_t)number < 0)
            {
                enum message = "Negative values are not allowed in a truth table";
                throw new ArrayException(message);
            }

            if (number > highestValue) highestValue = number;
        }

        auto table = new bool[highestValue+1];
    }

    foreach (number; numbers)
    {
        if (cast(ptrdiff_t)number < 0)
        {
            // Duplicate of the above, but can't be helped
            enum message = "Negative values are not allowed in a truth table";
            throw new ArrayException(message);
        }

        if ((highestValueOverride > 0) && (cast(size_t)number > table.length))
        {
            enum message = "Number out of bounds in truth table due to highest value override";
            throw new ArrayException(message);
        }

        table[cast(size_t)number] = true;
    }

    return table;
}

///
unittest
{
    import lu.traits : UnqualArray;
    import std.conv : to;

    {
        static immutable table = truthTable(1, 3, 5);
        alias T = UnqualArray!(typeof(table));
        static assert(is(T == bool[]), T.stringof);
        static assert((table.length == 6), table.length.to!string);
        static assert((table == [ false, true, false, true, false, true ]), table.to!string);
        static assert((table == [ 0, 1, 0, 1, 0, 1 ]), table.to!string);

        static assert(!table[0]);
        static assert( table[1]);
        static assert(!table[2]);
        static assert( table[3]);
        static assert(!table[4]);
        static assert( table[5]);
    }
    {
        static immutable table = truthTable!5(1, 2, 3);
        static assert(is(typeof(table) : bool[6]), typeof(table).stringof);
        static assert((table == [ false, true, true, true, false, false ]), table.to!string);
        static assert((table == [ 0, 1, 1, 1, 0, 0 ]), table.to!string);

        static assert(!table[0]);
        static assert( table[1]);
        static assert( table[2]);
        static assert( table[3]);
        static assert(!table[4]);
        static assert(!table[5]);
    }
}


// truthTable
/++
    Generates a truth table from a list of runtime enum values.

    The table is an array of booleans, where each index corresponds to an enum value
    in the input list. The boolean at each index is `true` if the value is in
    the input list, and `false` otherwise.

    Can be used during compile-time. If `Yes.fullEnumRange` is passed, the returned
    table will be a static array sized to accomodate the highest value in the enum.
    If `No.fullEnumRange` is passed, the returned table will be a dynamic one
    sized to accomodate the highest value in the input list.

    If no `fullEnumRange` argument is passed, the function call resolves to the
    overload that takes compile-time numbers instead.

    Note: This is not a sparse array and will be as large as requested.
        Additionally it is stack-allocated if `Yes.fullEnumRange` is passed, so
        be mindful of the size of the enum.

    Example:
    ---
    enum E { a, b, c, d, e, f }

    const table = truthTable(E.b, E.c, E.d);
    assert(table.length == 4);
    assert(table == [ false, true, true, true]);
    assert(table == [ 0, 1, 1, 1 ]);

    assert(!table[E.a]);
    assert( table[E.b]);
    assert( table[E.c]);
    assert( table[E.d]);

    const staticTable = truthTable!(Yes.fullEnumRange)(E.b, E.c);
    assert(staticTable.length == 6);
    assert(staticTable == [ false, true, true, false, false, false ]);
    assert(staticTable == [ 0, 1, 1, 0, 0, 0 ]);
    ---

    Params:
        fullEnumRange = Whether to generate a truth table for the full enum range.
        values = The enum values to generate a truth table from.

    Returns:
        A truth table as an array of booleans.
 +/
auto truthTable(Flag!"fullEnumRange" fullEnumRange, Enums...)(Enums values)
if (Enums.length &&
    allSameType!Enums &&
    is(Enums[0] == enum) &&
    is(Enums[0] : size_t))
{
    static if (fullEnumRange)
    {
        alias ThisEnum = Enums[0];

        enum tableLength = ()
        {
            size_t highestValue;

            foreach (memberstring; __traits(allMembers, ThisEnum))
            {
                auto value = mixin("ThisEnum." ~ memberstring);

                if (cast(ptrdiff_t)value < 0)
                {
                    enum message = "Negative values are not allowed in a truth table";
                    assert(0, message);
                }

                if (value > highestValue) highestValue = value;
            }

            return highestValue;
        }() + 1;

        bool[tableLength] table;

        foreach (value; values)
        {
            table[cast(size_t)value] = true;
        }

        return table;
    }
    else
    {
        return truthTable(values);
    }
}

///
unittest
{
    import lu.traits : UnqualArray;
    import std.conv : to;

    enum E { a, b, c, d, e }

    {
        static immutable table = truthTable!(Yes.fullEnumRange)(E.b, E.d, E.c, E.b);
        static assert(is(typeof(table) : bool[5]), typeof(table).stringof);
        static assert((table == [ false, true, true, true, false ]), table.to!string);
        static assert((table == [ 0, 1, 1, 1, 0 ]), table.to!string);

        static assert(!table[E.a]);
        static assert( table[E.b]);
        static assert( table[E.c]);
        static assert( table[E.d]);
        static assert(!table[E.e]);
    }
    {
        static immutable table = truthTable!(No.fullEnumRange)(E.a, E.b);
        alias T = UnqualArray!(typeof(table));
        static assert(is(T == bool[]), T.stringof);
        static assert((table.length == 2), table.length.to!string);
        static assert((table == [ true, true ]), table.to!string);
        static assert((table == [ 1, 1 ]), table.to!string);

        static assert(table[E.a]);
        static assert(table[E.b]);
    }
}


// truthTable
/++
    Generates a static truth table from a list of compile-time numbers.

    The table is a static array of booleans, where each index corresponds to a number
    in the input list. The boolean at each index is `true` if the number is in
    the input list, and `false` otherwise.

    Note: This is not a sparse array and will be as large as requested.
        In addition it is stack-allocated, so be mindful of the values of the
        numbers passed.

    Example:
    ---
    const table = truthTable!(1, 3, 5);
    assert(is(typeof(table) : bool[6]));
    assert(table == [ false, true, false, true, false, true ]);
    assert(table == [ 0, 1, 0, 1, 0, 1 ]);

    assert(!table[0]);
    assert( table[1]);
    assert(!table[2]);
    assert( table[3]);
    assert(!table[4]);
    assert( table[5]);
    ---

    Params:
        numbers = The compile-time numbers to generate a static truth table from.

    Returns:
        A truth table as a static array of booleans.
 +/
auto truthTable(numbers...)()
if (numbers.length &&
    allSatisfy!(templateNot!isType, numbers) &&
    allSatisfy!(isImplicitlyConvertibleToSize_t, numbers))
{
    enum tableLength = ()
    {
        size_t highestValue;

        foreach (number; numbers)
        {
            if (cast(ptrdiff_t)number < 0)
            {
                enum message = "Negative values are not allowed in a truth table";
                assert(0, message);
            }

            if (number > highestValue) highestValue = number;
        }

        return highestValue;
    }() + 1;

    bool[tableLength] table;

    foreach (number; numbers)
    {
        table[cast(size_t)number] = true;
    }

    return table;
}

///
unittest
{
    import std.conv : to;

    {
        static immutable table = truthTable!(1, 3, 5);
        static assert(is(typeof(table) : bool[6]), typeof(table).stringof);
        static assert((table == [ false, true, false, true, false, true ]), table.to!string);
        static assert((table == [ 0, 1, 0, 1, 0, 1 ]), table.to!string);

        static assert(!table[0]);
        static assert( table[1]);
        static assert(!table[2]);
        static assert( table[3]);
        static assert(!table[4]);
        static assert( table[5]);
    }
    {
        enum E { a, b, c, d, e }

        static immutable table = truthTable!(E.b, E.c);
        static assert(is(typeof(table) : bool[3]), typeof(table).stringof);
        static assert((table == [ false, true, true ]), table.to!string);
        static assert((table == [ 0, 1, 1 ]), table.to!string);

        static assert(!table[E.a]);
        static assert( table[E.b]);
        static assert( table[E.c]);
    }
}


// truthTable
/++
    Generates a static truth table from a list of compile-time enum values.

    The table is a static array of booleans, where each index corresponds to a number
    in the input list. The boolean at each index is `true` if the number is in
    the input list, and `false` otherwise.

    If `Yes.fullEnumRange` is passed, the returned table will be sized to
    accomodate the highest value in the enum. If `No.fullEnumRange` is passed,
    the returned table will be sized to accomodate the highest value in the input list.

    Note: This is not a sparse array and will be as large as requested.
        In addition it is stack-allocated, so be mindful of the size of the
        numbers passed.

    Example:
    ---
    enum E { a, b, c, d, e }

    const table = truthTable!(E.b, E.c);
    assert(is(typeof(table) : bool[__traits(allMembers, E).length]));

    assert(!table[E.a]);
    assert( table[E.b]);
    assert( table[E.c]);
    assert(!table[E.d]);
    assert(!table[E.e]);

    const staticTable = truthTable!(Yes.fullEnumRange, E.c, E.d);
    assert(is(typeof(staticTable) : bool[__traits(allMembers, E).length]));
    assert(staticTable == [ false, false, true, true, false ]);
    assert(staticTable == [ 0, 0, 1, 1, 0 ]);
    ---

    Params:
        fullEnumRange = Whether to generate a truth table for the full enum range.
        values = The enum values to generate a truth table from.

    Returns:
        A truth table as an array of booleans.
 +/
auto truthTable(Flag!"fullEnumRange" fullEnumRange, values...)()
if (values.length &&
    allSatisfy!(templateNot!isType, values) &&
    allSatisfy!(isEnum, values) &&
    allSatisfy!(isImplicitlyConvertibleToSize_t, values))
{
    static if (fullEnumRange)
    {
        alias ThisEnum = typeof(values[0]);

        enum tableLength = ()
        {
            size_t highestValue;

            foreach (memberstring; __traits(allMembers, ThisEnum))
            {
                auto member = mixin("ThisEnum." ~ memberstring);

                if (cast(ptrdiff_t)member < 0)
                {
                    enum message = "Negative values are not allowed in a truth table";
                    assert(0, message);
                }

                if (member > highestValue) highestValue = member;
            }

            return highestValue;
        }() + 1;

        bool[tableLength] table;

        foreach (value; values)
        {
            table[cast(size_t)value] = true;
        }

        return table;
    }
    else
    {
        // Reuse the non-enum overload
        return truthTable!values();
    }
}

///
unittest
{
    enum E { a, b, c, d, e }

    static immutable table = truthTable!(Yes.fullEnumRange, E.b, E.c);
    static assert(is(typeof(table) : bool[__traits(allMembers, E).length]), typeof(table).stringof);
    static assert((table == [ false, true, true, false, false ]), table.to!string);
    static assert((table == [ 0, 1, 1, 0, 0 ]), table.to!string);

    static assert(!table[E.a]);
    static assert( table[E.b]);
    static assert( table[E.c]);
    static assert(!table[E.d]);
    static assert(!table[E.e]);
}


// ArrayException
/++
    Exception, to be thrown when there was an array-related error.

    It is a normal [object.Exception|Exception] but its type bears meaning
    and allows for catching only array-related exceptions.
 +/
final class ArrayException : Exception
{
    /++
        Creates a new [ArrayException].
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }
}


// pruneAA
/++
    Iterates an associative array and deletes invalid entries, either if the value
    is in a default `.init` state or as per the optionally passed predicate.

    It is undefined behaviour to remove keys from an associative array
    when foreaching through it. Use this as a separate pass to safely remove entries.

    Example:
    ---
    auto aa =
    [
        "abc" : "def",
        "ghi" : string.init;
        "mno" : "123",
        "pqr" : string.init,
    ];

    pruneAA(aa);

    assert("ghi" !in aa);
    assert("pqr" !in aa);

    pruneAA!((entry) => entry.length > 0)(aa);

    assert("abc" !in aa);
    assert("mno" !in aa);
    ---

    Params:
        pred = Optional unary or binary predicate if special logic is needed to
            determine whether an entry is to be removed or not.
        aa = Reference to the associative array to modify.
 +/
void pruneAA(alias pred = null, AA : V[K], V, K)(ref AA aa)
if (isMutable!AA)
{
    if (!aa.length) return;

    static if (!is(typeof(pred) == typeof(null)))
    {
        import std.functional : binaryFun, unaryFun;

        static if (__traits(compiles, unaryFun!pred(V.init)))
        {
            alias predicate = unaryFun!pred;
        }
        else static if (__traits(compiles, binaryFun!pred(K.init, V.init)))
        {
            enum predIsBinary = true;
            alias predicate = binaryFun!pred;
        }
        else
        {
            enum message = "Unknown predicate type passed to `pruneAA`";
            static assert(0, message);
        }
    }
    else
    {
        alias predicate = (v) => (v == V.init);
    }

    string[] toRemove;

    // Mark
    foreach (/*immutable*/ key, value; aa)
    {
        static if (__traits(compiles, { alias _ = predIsBinary; }))
        {
            if (predicate(key, value)) toRemove ~= key;
        }
        else
        {
            if (predicate(value)) toRemove ~= key;
        }
    }

    // Sweep
    foreach (/*immutable*/ key; toRemove)
    {
        aa.remove(key);
    }
}

///
unittest
{
    import std.conv : text;

    {
        auto aa =
        [
            "abc" : "def",
            "ghi" : "jkl",
            "mno" : "123",
            "pqr" : string.init,
        ];

        pruneAA!((a) => a == "def")(aa);
        assert("abc" !in aa);

        pruneAA!((a,b) => a == "pqr")(aa);
        assert("pqr" !in aa);

        pruneAA!`a == "123"`(aa);
        assert("mno" !in aa);
    }
    {
        struct Record
        {
            string name;
            int id;
        }

        auto aa =
        [
            "rhubarb"   : Record("rhubarb", 100),
            "raspberry" : Record("raspberry", 80),
            "blueberry" : Record("blueberry", 0),
            "apples"    : Record("green apples", 60),
            "yakisoba"  : Record("yakisoba", 78),
            "cabbage"   : Record.init,
        ];

        pruneAA(aa);
        assert("cabbage" !in aa);

        pruneAA!((entry) => entry.id < 80)(aa);
        assert("blueberry" !in aa);
        assert("apples" !in aa);
        assert("yakisoba" !in aa);
        assert((aa.length == 2), aa.length.text);
    }
    {
        import std.algorithm.searching : canFind;

        string[][string] aa =
        [
            "abc" : [ "a", "b", "c" ],
            "def" : [ "d", "e", "f" ],
            "ghi" : [ "g", "h", "i" ],
            "jkl" : [ "j", "k", "l" ],
        ];

        pruneAA(aa);
        assert((aa.length == 4), aa.length.text);

        pruneAA!((entry) => entry.canFind("a"))(aa);
        assert("abc" !in aa);
    }
    {
        auto aa =
        [
            "rhubarb"   : 500,
            "raspberry" : 500,
            "blueberry" : 499,
            "apples"    : 900,
            "yakisoba"  : 499,
            "cabbage"   : 999,
        ];

        pruneAA!((key, val) => (key[0] == 'r') || (val < 500))(aa);
        assert("rhubarb" !in aa);
        assert("raspberry" !in aa);
        assert("blueberry" !in aa);
        assert("apples" in aa);
        assert("yakisoba" !in aa);
        assert("cabbage" in aa);

        pruneAA!`a[0] == 'c'`(aa);
        assert("cabbage" !in aa);
    }
}
