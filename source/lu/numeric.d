/++
    Functions and templates that do calculations or other numeric manipulation,
    in some way or another.

    Example:
    ---
    immutable width = 15.getMultipleOf(4);
    assert(width == 16);
    immutable width2 = 16.getMultipleOf(4, alwaysOneUp: true);
    assert(width2 == 20);
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.numeric;

private:

public:

@safe:


// getMultipleOf
/++
    Given a number, calculate the largest multiple of `n` needed to reach that number.

    It rounds up, and if supplied `alwaysOneUp: true` it will always overshoot.
    This is good for when calculating format pattern widths.

    Example:
    ---
    immutable width = 15.getMultipleOf(4);
    assert(width == 16);
    immutable width2 = 16.getMultipleOf(4, alwaysOneUp: true);
    assert(width2 == 20);
    ---

    Params:
        number = Number to reach.
        n = Base value to find a multiplier for.
        alwaysOneUp = Whether or not to always overshoot.

    Returns:
        The multiple of `n` that reaches and possibly overshoots `number`.
 +/
auto getMultipleOf(Number)
    (const Number number,
    const int n,
    const bool alwaysOneUp = false) pure nothrow @nogc
in ((n > 0), "Cannot get multiple of 0 or negatives")
in ((number >= 0), "Cannot get multiples for a negative number")
{
    if (number == 0) return 0;

    if (number == n)
    {
        return alwaysOneUp ? (n + 1) : n;
    }

    immutable frac = (number / double(n));
    immutable floor_ = cast(uint)frac;
    immutable mod = alwaysOneUp ? (floor_ + 1) : ((floor_ == frac) ? floor_ : (floor_ + 1));

    return (mod * n);
}

///
unittest
{
    import std.conv : text;

    immutable n1 = 15.getMultipleOf(4);
    assert((n1 == 16), n1.text);

    immutable n2 = 16.getMultipleOf(4, alwaysOneUp: true);
    assert((n2 == 20), n2.text);

    immutable n3 = 16.getMultipleOf(4);
    assert((n3 == 16), n3.text);
    immutable n4 = 0.getMultipleOf(5);
    assert((n4 == 0), n4.text);

    immutable n5 = 1.getMultipleOf(1);
    assert((n5 == 1), n5.text);

    immutable n6 = 1.getMultipleOf(1, alwaysOneUp: true);
    assert((n6 == 2), n6.text);

    immutable n7 = 5.getMultipleOf(5, alwaysOneUp: true);
    assert((n7 == 6), n7.text);

    immutable n8 = 5L.getMultipleOf(5L, alwaysOneUp: true);
    assert((n8 == 6L), n8.text);

    immutable n9 = 5UL.getMultipleOf(5UL, alwaysOneUp: false);
    assert((n9 == 5UL), n9.text);

    immutable n10 = (5.0).getMultipleOf(5UL, alwaysOneUp: true);
    assert((n10 == (6.0)), n10.text);
}
