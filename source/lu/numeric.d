/++
 +  Functions and templates that do numeric calculations or other manipulation,
 +  in some way or another.
 +/
module lu.numeric;

private:

import std.typecons : Flag, No, Yes;

public:

@safe:


// getMultipleOf
/++
 +  Given a number, calculate the largest multiple of `n` needed to reach that number.
 +
 +  It rounds up, and if supplied `Yes.alwaysOneUp` it will always overshoot.
 +  This is good for when calculating format pattern widths.
 +
 +  Example:
 +  ---
 +  immutable width = 15.getMultipleOf(4);
 +  assert(width == 16);
 +  immutable width2 = 16.getMultipleOf!(Yes.alwaysOneUp)(4);
 +  assert(width2 == 20);
 +  ---
 +
 +  Params:
 +      oneUp = Whether or not to always overshoot.
 +      num = Number to reach.
 +      n = Base value to find a multiplier for.
 +
 +  Returns:
 +      The multiple of `n` that reaches and possibly overshoots `num`.
 +/
Number getMultipleOf(Flag!"alwaysOneUp" oneUp = No.alwaysOneUp, Number)
    (const Number num, const int n) pure nothrow @nogc
in ((n > 0), "Cannot get multiple of 0 or negatives")
in ((num >= 0), "Cannot get multiples for a negative number")
do
{
    if (num == 0) return 0;

    if (num == n)
    {
        static if (oneUp)
        {
            return (n + 1);
        }
        else
        {
            return n;
        }
    }

    immutable frac = (num / double(n));
    immutable floor_ = cast(uint)frac;

    static if (oneUp)
    {
        immutable mod = (floor_ + 1);
    }
    else
    {
        immutable mod = (floor_ == frac) ? floor_ : (floor_ + 1);
    }

    return cast(uint)(mod * n);
}

///
unittest
{
    import std.conv : text;

    immutable n1 = 15.getMultipleOf(4);
    assert((n1 == 16), n1.text);

    immutable n2 = 16.getMultipleOf!(Yes.alwaysOneUp)(4);
    assert((n2 == 20), n2.text);

    immutable n3 = 16.getMultipleOf(4);
    assert((n3 == 16), n3.text);
    immutable n4 = 0.getMultipleOf(5);
    assert((n4 == 0), n4.text);

    immutable n5 = 1.getMultipleOf(1);
    assert((n5 == 1), n5.text);

    immutable n6 = 1.getMultipleOf!(Yes.alwaysOneUp)(1);
    assert((n6 == 2), n6.text);
}
