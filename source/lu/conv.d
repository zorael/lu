/++
    This module contains functions that in one way or another converts its
    arguments into something else.

    Credit for [Enum] goes to Stephan Koch (https://github.com/UplinkCoder).

    Example:
    ---
    enum SomeEnum { one, two, three };

    SomeEnum foo = Enum!SomeEnum.fromString("one");
    SomeEnum bar = Enum!SomeEnum.fromString("three");

    assert(foo == SomeEnum.one);
    assert(bar == SomeEnum.three);
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.conv;

private:

import std.typecons : Flag, No, Yes;

public:

@safe:


// Enum
/++
    Template housing optimised functions to get the string name of an enum
    member, or the enum member of a name string.

    [std.conv.to] is typically the go-to for this job; however it quickly bloats
    the binary and is not performant on larger enums.

    Params:
        E = enum to base this template on.
 +/
template Enum(E)
if (is(E == enum))
{
    // fromString
    /++
        Takes the member of an enum by string and returns that enum member.

        It lowers to a big switch of the enum member strings. It is faster than
        [std.conv.to] and generates less template bloat. However, it does not work
        with enums where multiple members share the same values, as the big switch
        ends up getting duplicate cases.

        Taken from: https://forum.dlang.org/post/bfnwstkafhfgihavtzsz@forum.dlang.org
        written by Stephan Koch (https://github.com/UplinkCoder).
        Used with permission.

        Example:
        ---
        enum SomeEnum { one, two, three };

        SomeEnum foo = Enum!SomeEnum.fromString("one");
        SomeEnum bar = Enum!SomeEnum.fromString("three");

        assert(foo == SomeEnum.one);
        assert(bar == SomeEnum.three);
        ---

        Params:
            enumstring = the string name of an enum member.

        Returns:
            The enum member whose name matches the enumstring string (not whose
            *value* matches the string).

        Throws: [std.conv.ConvException|ConvException] if no matching enum member with the
            passed name could be found.

        Bugs:
            Does not work with enums that have members with duplicate values.
     +/
    E fromString(const string enumstring) pure
    {
        enum enumSwitch = ()
        {
            string enumSwitch = "import std.conv : ConvException;\n" ~
                "with (E) switch (enumstring)\n{\n";

            foreach (immutable memberstring; __traits(allMembers, E))
            {
                enumSwitch ~= `case "` ~ memberstring ~ `": return ` ~ memberstring ~ ";\n";
            }

            enumSwitch ~= "default:\n" ~
                "    //import std.traits : fullyQualifiedName;\n" ~
                `    throw new ConvException("No such " ~ E.stringof ~ ": " ~ enumstring);` ~ "\n}";

            return enumSwitch;
        }();

        mixin(enumSwitch);
    }


    // toString
    /++
        The inverse of [fromString], this function takes an enum member value
        and returns its string identifier.

        It lowers to a big switch of the enum members. It is faster than
        [std.conv.to] and generates less template bloat.

        Taken from: https://forum.dlang.org/post/bfnwstkafhfgihavtzsz@forum.dlang.org
        written by Stephan Koch (https://github.com/UplinkCoder).
        Used with permission.

        Example:
        ---
        enum SomeEnum { one, two, three };

        string foo = Enum!SomeEnum.toString(SomeEnum.one);
        assert(foo == "one");
        ---

        Params:
            value = Enum member whose string name we want.

        Returns:
            The string name of the passed enum member, or (for instance)
            `cast(E)1234` if an invalid value of `1234` was passed, cast to type `E`.

        See_Also:
            [enumToString]
     +/
    string toString(E value) pure nothrow
    {
        switch (value)
        {

        foreach (immutable m; __traits(allMembers, E))
        {
            case mixin("E." ~ m): return m;
        }

        default:
            /+
                This only happens if an invalid enum member value was passed,
                cast to type `E`.

                Format it into a string like "cast(E)1234" and return that.
             +/
            immutable log10Value =
                (value < 10) ? 0 :
                (value < 100) ? 1 :
                (value < 1_000) ? 2 :
                (value < 10_000) ? 3 :
                (value < 100_000) ? 4 :
                (value < 1_000_000) ? 5 :
                (value < 10_000_000) ? 6 :
                (value < 100_000_000) ? 7 :
                (value < 1_000_000_000) ? 8 : 9;

            enum head = "cast(" ~ E.stringof ~ ')';
            auto result = head.dup;
            result.length += log10Value + 1;
            uint val = value;

            foreach (immutable i; 0..log10Value+1)
            {
                result[head.length + log10Value-i] = cast(char)('0' + (val % 10));
                val /= 10;
            }

            return result; //.idup;
        }
    }
}

///
@system
unittest
{
    import std.conv : ConvException;
    import std.exception  : assertThrown;

    enum T
    {
        UNSET,
        QUERY,
        PRIVMSG,
        RPL_ENDOFMOTD
    }

    static assert(Enum!T.fromString("QUERY") == T.QUERY);
    static assert(Enum!T.fromString("PRIVMSG") == T.PRIVMSG);
    static assert(Enum!T.fromString("RPL_ENDOFMOTD") == T.RPL_ENDOFMOTD);
    static assert(Enum!T.fromString("UNSET") == T.UNSET);
    assertThrown!ConvException(Enum!T.fromString("DOESNTEXIST"));  // needs @system

    static assert(Enum!T.toString(T.QUERY) == "QUERY");
    static assert(Enum!T.toString(T.PRIVMSG) == "PRIVMSG");
    static assert(Enum!T.toString(T.RPL_ENDOFMOTD) == "RPL_ENDOFMOTD");
    static assert(Enum!T.toString(cast(T)1234) == "cast(T)1234");
}


// enumToString
/++
    Convenience wrapper around [Enum] that infers the type of the passed enum member.

    Params:
        value = Enum member whose string name we want.

    Returns:
        The string name of the passed enum member.

    See_Also:
        [Enum]
 +/
auto enumToString(E)(const E value)
if (is(E == enum))
{
    return Enum!E.toString(value);
}

///
unittest
{
    enum T
    {
        UNSET,
        QUERY,
        PRIVMSG,
        RPL_ENDOFMOTD
    }

    with (T)
    {
        static assert(enumToString(QUERY) == "QUERY");
        static assert(enumToString(PRIVMSG) == "PRIVMSG");
        static assert(enumToString(RPL_ENDOFMOTD) == "RPL_ENDOFMOTD");
    }
}


// numFromHex
/++
    Returns the decimal value of a hex number in string form.

    Example:
    ---
    int fifteen = numFromHex("F");
    int twofiftyfive = numFromHex("FF");
    ---

    Params:
        hex = Hexadecimal number in string form.
        acceptLowercase = Flag of whether or not to accept `rrggbb` in lowercase form.

    Returns:
        An integer equalling the value of the passed hexadecimal string.

    Throws: [std.conv.ConvException|ConvException] if the hex string was malformed.
 +/
auto numFromHex(
    const string hex,
    const Flag!"acceptLowercase" acceptLowercase = Yes.acceptLowercase) pure
out (total; (total < 16^^hex.length), "`numFromHex` output is too large")
{
    import std.string : representation;

    int val = -1;
    int total;

    foreach (immutable c; hex.representation)
    {
        switch (c)
        {
        case '0':
        ..
        case '9':
            val = (c - 48);
            goto case 'F';

        case 'a':
        ..
        case 'f':
            if (acceptLowercase)
            {
                val = (c - (55+32));
                goto case 'F';
            }
            else
            {
                goto default;
            }

        case 'A':
        ..
        case 'F':
            if (val < 0) val = (c - 55);
            total *= 16;
            total += val;
            val = -1;
            break;

        default:
            import std.conv : ConvException;
            throw new ConvException("Invalid hex string: " ~ hex);
        }
    }

    return total;
}


// rgbFromHex
/++
    Convenience wrapper that takes a hex string and populates a Voldemort
    struct with its RR, GG and BB components.

    This is to be used when mapping a `#RRGGBB` colour to their decimal
    red/green/blue equivalents.

    Params:
        hexString = Hexadecimal number (colour) in string form.
        acceptLowercase = Whether or not to accept the `rrggbb` string in
            lowercase letters.

    Returns:
        A Voldemort struct with `r`, `g` and `b` members,
 +/
auto rgbFromHex(
    const string hexString,
    const Flag!"acceptLowercase" acceptLowercase = No.acceptLowercase)
{
    struct RGB
    {
        int r;
        int g;
        int b;
    }

    RGB rgb;
    immutable hex = (hexString[0] == '#') ? hexString[1..$] : hexString;

    rgb.r = numFromHex(hex[0..2], acceptLowercase);
    rgb.g = numFromHex(hex[2..4], acceptLowercase);
    rgb.b = numFromHex(hex[4..$], acceptLowercase);

    return rgb;
}

///
unittest
{
    import std.conv : text;
    {
        auto rgb = rgbFromHex("000102");

        assert((rgb.r == 0), rgb.r.text);
        assert((rgb.g == 1), rgb.g.text);
        assert((rgb.b == 2), rgb.b.text);
    }
    {
        auto rgb = rgbFromHex("#FFFFFF");

        assert((rgb.r == 255), rgb.r.text);
        assert((rgb.g == 255), rgb.g.text);
        assert((rgb.b == 255), rgb.b.text);
    }
    {
        auto rgb = rgbFromHex("#3C507D");

        assert((rgb.r == 60), rgb.r.text);
        assert((rgb.g == 80), rgb.b.text);
        assert((rgb.b == 125), rgb.b.text);
    }
    {
        auto rgb = rgbFromHex("9a4B7c", Yes.acceptLowercase);

        assert((rgb.r == 154), rgb.r.text);
        assert((rgb.g == 75), rgb.g.text);
        assert((rgb.b == 124), rgb.b.text);
    }
}


// toAlphaInto
/++
    Translates an integer into an alphanumeric string. Assumes ASCII.
    Overload that takes an output range sink.

    Example:
    ---
    Appender!(char[]) sink;
    int num = 12345;
    num.toAlphaInto(sink);
    assert(sink.data == "12345");
    assert(sink.data == num.to!string);
    ---

    Params:
        maxDigits = The maximum number of digits to expect input of.
        leadingZeroes = The minimum amount of leading zeroes to include in the
            output, mirroring the format specifier "`%0nd`".
        num = Integer to translate into string.
        sink = Output range sink.
 +/
void toAlphaInto(size_t maxDigits = 19, uint leadingZeroes = 0, Num, Sink)
    (const Num num, auto ref Sink sink)
{
    import std.range.primitives : isOutputRange;
    import std.traits : isIntegral;

    static if (!isIntegral!Num)
    {
        enum message = "`toAlphaInto` must be passed an integral type";
        static assert(0, message);
    }

    static if (!isOutputRange!(Sink, char[]))
    {
        enum message = "`toAlphaInto` sink must be an output range accepting `char[]`";
        static assert(0, message);
    }

    static if (leadingZeroes > maxDigits)
    {
        enum message = "Cannot pass more leading zeroes than max digits to `toAlphaInto`";
        static assert(0, message);
    }

    if (num == 0)
    {
        static if (leadingZeroes > 0)
        {
            foreach (immutable i; 0..leadingZeroes)
            {
                sink.put('0');
            }
        }
        else
        {
            sink.put('0');
        }
        return;
    }
    else if (num < 0)
    {
        sink.put('-');
    }

    static if (leadingZeroes > 0)
    {
        // Need default-initialised fields to be zeroes
        ubyte[maxDigits] digits;
    }
    else
    {
        ubyte[maxDigits] digits = void;
    }

    size_t pos;

    for (Num window = num; window != 0; window /= 10)
    {
        import std.math : abs;
        digits[pos++] = cast(ubyte)abs(window % 10);
    }

    static if (leadingZeroes > 0)
    {
        import std.algorithm.comparison : max;
        size_t startingPos = max(leadingZeroes, pos);
    }
    else
    {
        alias startingPos = pos;
    }

    foreach_reverse (immutable digit; digits[0..startingPos])
    {
        sink.put(cast(char)(digit + '0'));
    }
}

///
unittest
{
    import std.array : Appender;

    Appender!(char[]) sink;

    {
        enum num = 123_456;
        num.toAlphaInto(sink);
        assert((sink.data == "123456"), sink.data);
        sink.clear();
    }
    {
        enum num = 0;
        num.toAlphaInto(sink);
        assert((sink.data == "0"), sink.data);
        sink.clear();
    }
    {
        enum num = 999;
        num.toAlphaInto(sink);
        assert((sink.data == "999"), sink.data);
        sink.clear();
    }
    {
        enum num = -987;
        num.toAlphaInto(sink);
        assert((sink.data == "-987"), sink.data);
        sink.clear();
    }
    {
        enum num = 123;
        num.toAlphaInto!(12, 6)(sink);
        assert((sink.data == "000123"), sink.data);
        sink.clear();
    }
    {
        enum num = -1;
        num.toAlphaInto!(3, 3)(sink);
        assert((sink.data == "-001"), sink.data);
        sink.clear();
    }
    {
        enum num = -123_456_789_012_345L;
        num.toAlphaInto!15(sink);
        assert((sink.data == "-123456789012345"), sink.data);
        sink.clear();
    }
    {
        enum num = long.min;
        num.toAlphaInto(sink);
        assert((sink.data == "-9223372036854775808"), sink.data);
        //sink.clear();
    }
}


// toAlpha
/++
    Translates an integer into an alphanumeric string. Assumes ASCII.
    Overload that returns the string.

    Merely leverages [toAlphaInto].

    Example:
    ---
    int num = 12345;
    string asString = num.toAlpha;
    assert(asString == "12345");
    assert(asString == num.to!string);
    ---

    Params:
        maxDigits = The maximum number of digits to expect input of.
        leadingZeroes = The minimum amount of leading zeroes to include in the
            output, mirroring the format specifier "`%0nd`".
        num = Integer to translate into string.

    Returns:
        The passed integer `num` in string form.
 +/
string toAlpha(size_t maxDigits = 19, uint leadingZeroes = 0, Num)(const Num num) pure
{
    import std.array : Appender;

    Appender!(char[]) sink;
    sink.reserve((num >= 0) ? maxDigits : maxDigits+1);
    num.toAlphaInto!(maxDigits, leadingZeroes, Num)(sink);
    return sink.data;
}

///
unittest
{
    {
        enum num = 123_456;
        immutable translated = num.toAlpha;
        assert((translated == "123456"), translated);
    }
    {
        enum num = 0;
        immutable translated = num.toAlpha;
        assert((translated == "0"), translated);
    }
    {
        enum num = 999;
        immutable translated = num.toAlpha;
        assert((translated == "999"), translated);
    }
    {
        enum num = -987;
        immutable translated = num.toAlpha;
        assert((translated == "-987"), translated);
    }
    {
        enum num = 123;
        immutable translated = num.toAlpha!(12, 6);
        assert((translated == "000123"), translated);
    }
    {
        enum num = -1;
        immutable translated = num.toAlpha!(3, 3);
        assert((translated == "-001"), translated);
    }
    {
        enum num = -123_456_789_012_345L;
        immutable translated = num.toAlpha!15;
        assert((translated == "-123456789012345"), translated);
    }
    {
        enum num = long.min;
        immutable translated = num.toAlpha;
        assert((translated == "-9223372036854775808"), translated);
    }
}
