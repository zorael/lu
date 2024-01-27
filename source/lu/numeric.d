/++
    Functions and templates that do numeric calculations or other manipulation,
    in some way or another.

    Example:
    ---
    immutable width = 15.getMultipleOf(4);
    assert(width == 16);
    immutable width2 = 16.getMultipleOf(4, Yes.alwaysOneUp);
    assert(width2 == 20);
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.numeric;

private:

import std.typecons : Flag, No, Yes;

public:

@safe:


// getMultipleOf
/++
    Given a number, calculate the largest multiple of `n` needed to reach that number.

    It rounds up, and if supplied `Yes.alwaysOneUp` it will always overshoot.
    This is good for when calculating format pattern widths.

    Example:
    ---
    immutable width = 15.getMultipleOf(4);
    assert(width == 16);
    immutable width2 = 16.getMultipleOf(4, Yes.alwaysOneUp);
    assert(width2 == 20);
    ---

    Params:
        num = Number to reach.
        n = Base value to find a multiplier for.
        oneUp = Whether or not to always overshoot.

    Returns:
        The multiple of `n` that reaches and possibly overshoots `num`.
 +/
auto getMultipleOf(Number)
    (const Number num,
    const int n,
    const Flag!"alwaysOneUp" oneUp = No.alwaysOneUp) pure nothrow @nogc
in ((n > 0), "Cannot get multiple of 0 or negatives")
in ((num >= 0), "Cannot get multiples for a negative number")
{
    if (num == 0) return 0;

    if (num == n)
    {
        return oneUp ? (n + 1) : n;
    }

    immutable frac = (num / double(n));
    immutable floor_ = cast(uint)frac;
    immutable mod = oneUp ? (floor_ + 1) : ((floor_ == frac) ? floor_ : (floor_ + 1));

    return (mod * n);
}

///
unittest
{
    import std.conv : text;

    immutable n1 = 15.getMultipleOf(4);
    assert((n1 == 16), n1.text);

    immutable n2 = 16.getMultipleOf(4, Yes.alwaysOneUp);
    assert((n2 == 20), n2.text);

    immutable n3 = 16.getMultipleOf(4);
    assert((n3 == 16), n3.text);
    immutable n4 = 0.getMultipleOf(5);
    assert((n4 == 0), n4.text);

    immutable n5 = 1.getMultipleOf(1);
    assert((n5 == 1), n5.text);

    immutable n6 = 1.getMultipleOf(1, Yes.alwaysOneUp);
    assert((n6 == 2), n6.text);

    immutable n7 = 5.getMultipleOf(5, Yes.alwaysOneUp);
    assert((n7 == 6), n7.text);

    immutable n8 = 5L.getMultipleOf(5L, Yes.alwaysOneUp);
    assert((n8 == 6L), n8.text);

    immutable n9 = 5UL.getMultipleOf(5UL, No.alwaysOneUp);
    assert((n9 == 5UL), n9.text);

    immutable n10 = (5.0).getMultipleOf(5UL, Yes.alwaysOneUp);
    assert((n10 == (6.0)), n10.text);
}
