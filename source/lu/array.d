/++
    Simple array utilities.

    Example:
    ---
    string[int] aa;

    immutable key = aa.uniqueKey;

    assert(key > 0);
    assert(key in aa);
    assert(aa[key] == string.init);
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.array;

private:

import std.traits : isIntegral;

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
