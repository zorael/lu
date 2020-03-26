/++
 +  This module contains functions that in one way or another converts its
 +  arguments into something else.
 +
 +  Credit for `Enum` goes to Stephan Koch (https://github.com/UplinkCoder).
 +/
module lu.conv;

private:

import std.typecons : Flag, No, Yes;
import std.range.primitives : isOutputRange;

public:

@safe:

// Enum
/++
 +  Template housing optimised functions to get the string name of an enum
 +  member, or the enum member of a name string.
 +
 +  `std.conv.to` is typically the go-to for this job; however it quickly bloats
 +  the binary and is supposedly not performant on larger enums.
 +
 +  Params:
 +      E = enum to base this template on.
 +/
template Enum(E)
if (is(E == enum))
{
    // fromString
    /++
     +  Takes the member of an enum by string and returns that enum member.
     +
     +  It lowers to a big switch of the enum member strings. It is faster than
     +  `std.conv.to` and generates less template bloat. However, it does not work
     +  with enums where multiple members share the same values, as the big switch
     +  ends up getting duplicate cases.
     +
     +  Taken from: https://forum.dlang.org/post/bfnwstkafhfgihavtzsz@forum.dlang.org
     +  written by Stephan Koch (https://github.com/UplinkCoder).
     +
     +  Example:
     +  ---
     +  enum SomeEnum { one, two, three };
     +
     +  SomeEnum foo = Enum!SomeEnum.fromString("one");
     +  SomeEnum bar = Enum!SomeEnum.fromString("three");
     +
     +  assert(foo == SomeEnum.one);
     +  assert(bar == SomeEnum.three);
     +  ---
     +
     +  Params:
     +      enumstring = the string name of an enum member.
     +
     +  Returns:
     +      The enum member whose name matches the enumstring string (not whose
     +      *value* matches the string).
     +
     +  Throws: `std.conv.ConvException` if no matching enum member with the
     +      passed name could be found.
     +
     +  Bugs:
     +      Does not work with enums that have members with duplicate values.
     +/
    E fromString(const string enumstring) pure
    {
        enum enumSwitch = ()
        {
            string enumSwitch = "import std.conv : ConvException;\n";
            enumSwitch ~= "with (E) switch (enumstring)\n{\n";

            foreach (immutable memberstring; __traits(allMembers, E))
            {
                enumSwitch ~= `case "` ~ memberstring ~ `":`;
                enumSwitch ~= "return " ~ memberstring ~ ";\n";
            }

            enumSwitch ~= "default:\n" ~
                "import std.traits : fullyQualifiedName;\n" ~
                `throw new ConvException("No such " ~ fullyQualifiedName!E ~ ": " ~ enumstring);}`;

            return enumSwitch;
        }();

        mixin(enumSwitch);
    }


    // toString
    /++
     +  The inverse of `fromString`, this function takes an enum member value
     +  and returns its string identifier.
     +
     +  It lowers to a big switch of the enum members. It is faster than
     +  `std.conv.to` and generates less template bloat.
     +
     +  Taken from: https://forum.dlang.org/post/bfnwstkafhfgihavtzsz@forum.dlang.org
     +  written by Stephan Koch (https://github.com/UplinkCoder).
     +
     +  Example:
     +  ---
     +  enum SomeEnum { one, two, three };
     +
     +  string foo = Enum!SomeEnum.toString(one);
     +  assert(foo == "one");
     +  ---
     +
     +  Params:
     +      value = Enum member whose string name we want.
     +
     +  Returns:
     +      The string name of the passed enum member.
     +/
    string toString(E value) pure nothrow
    {
        switch (value)
        {

        foreach (immutable m; __traits(allMembers, E))
        {
            case mixin("E." ~ m) : return m;
        }

        default:
            string result = "cast(" ~ E.stringof ~ ")";
            uint val = value;
            enum headLength = E.stringof.length + "cast()".length;

            immutable log10Val =
                (val < 10) ? 0 :
                (val < 100) ? 1 :
                (val < 1_000) ? 2 :
                (val < 10_000) ? 3 :
                (val < 100_000) ? 4 :
                (val < 1_000_000) ? 5 :
                (val < 10_000_000) ? 6 :
                (val < 100_000_000) ? 7 :
                (val < 1_000_000_000) ? 8 : 9;

            result.length += log10Val + 1;

            for (uint i; i != log10Val + 1; ++i)
            {
                cast(char)result[headLength + log10Val - i] = cast(char)('0' + (val % 10));
                val /= 10;
            }

            return result;
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

    with (T)
    {
        assert(Enum!T.fromString("QUERY") == QUERY);
        assert(Enum!T.fromString("PRIVMSG") == PRIVMSG);
        assert(Enum!T.fromString("RPL_ENDOFMOTD") == RPL_ENDOFMOTD);
        assert(Enum!T.fromString("UNSET") == UNSET);
        assertThrown!ConvException(Enum!T.fromString("DOESNTEXIST"));  // needs @system
    }

    with (T)
    {
        assert(Enum!T.toString(QUERY) == "QUERY");
        assert(Enum!T.toString(PRIVMSG) == "PRIVMSG");
        assert(Enum!T.toString(RPL_ENDOFMOTD) == "RPL_ENDOFMOTD");
    }
}


// numFromHex
/++
 +  Returns the decimal value of a hex number in string form.
 +
 +  Example:
 +  ---
 +  int fifteen = numFromHex("F");
 +  int twofiftyfive = numFromHex("FF");
 +  ---
 +
 +  Params:
 +      acceptLowercase = Flag of whether or not to accept rrggbb in lowercase form.
 +      hex = Hexadecimal number in string form.
 +
 +  Returns:
 +      An integer equalling the value of the passed hexadecimal string.
 +
 +  Throws: `std.conv.ConvException` if the hex string was malformed.
 +/
uint numFromHex(Flag!"acceptLowercase" acceptLowercase = No.acceptLowercase)(const string hex) pure
out (total; (total < 16^^hex.length), "numFromHex output is too large")
do
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

    static if (acceptLowercase)
    {
        case 'a':
        ..
        case 'f':
            val = (c - (55+32));
            goto case 'F';
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


// numFromHex
/++
 +  Convenience wrapper that takes a hex string and maps the values to three
 +  integers passed by ref.
 +
 +  This is to be used when mapping a #RRGGBB colour to their decimal
 +  red/green/blue equivalents.
 +
 +  Params:
 +      acceptLowercase = Whether or not to accept the rrggbb string in lowercase letters.
 +      hexString = Hexadecimal number (colour) in string form.
 +      r = Out-reference integer for the red part of the hex string.
 +      g = Out-reference integer for the green part of the hex string.
 +      b = Out-reference integer for the blue part of the hex string.
 +/
void numFromHex(Flag!"acceptLowercase" acceptLowercase = No.acceptLowercase)
    (const string hexString, out int r, out int g, out int b) pure
out (; ((r >= 0) && (r <= 255)), "Red out of hex range")
out (; ((g >= 0) && (g <= 255)), "Green out of hex range")
out (; ((b >= 0) && (b <= 255)), "Blue out of hex range")
do
{
    if (!hexString.length) return;

    immutable hex = (hexString[0] == '#') ? hexString[1..$] : hexString;

    r = numFromHex!acceptLowercase(hex[0..2]);
    g = numFromHex!acceptLowercase(hex[2..4]);
    b = numFromHex!acceptLowercase(hex[4..$]);
}

///
unittest
{
    import std.conv : text;
    {
        int r, g, b;
        numFromHex("000102", r, g, b);

        assert((r == 0), r.text);
        assert((g == 1), g.text);
        assert((b == 2), b.text);
    }
    {
        int r, g, b;
        numFromHex("FFFFFF", r, g, b);

        assert((r == 255), r.text);
        assert((g == 255), g.text);
        assert((b == 255), b.text);
    }
    {
        int r, g, b;
        numFromHex("3C507D", r, g, b);

        assert((r == 60), r.text);
        assert((g == 80), g.text);
        assert((b == 125), b.text);
    }
    {
        int r, g, b;
        numFromHex!(Yes.acceptLowercase)("9a4B7c", r, g, b);

        assert((r == 154), r.text);
        assert((g == 75), g.text);
        assert((b == 124), b.text);
    }
}


// toAlphaInto
/++
 +  Translates an integer into an alphanumeric string. Assumes ASCII.
 +
 +  Overload that takes an output range sink.
 +
 +  Example:
 +  ---
 +  Appender!string sink;
 +  int num = 12345;
 +  num.toAlphaInto(sink);
 +  assert(sink.data == "12345");
 +  assert(sink.data == num.to!string);
 +  ---
 +
 +  Params:
 +      maxDigits = The maximum number of digits to expect input of.
 +      leadingZeroes = The minimum amount of leading zeroes to include in the
 +          output, mirroring the format specifier "`%0nd`".
 +      num = Integer to translate into string.
 +      sink = Output range sink.
 +/
void toAlphaInto(size_t maxDigits = 12, uint leadingZeroes = 0, Sink)
    (const int num, auto ref Sink sink)
if (isOutputRange!(Sink, char[]))
{
    import std.math : abs;

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
        uint[maxDigits] digits;
    }
    else
    {
        uint[maxDigits] digits = void;
    }

    size_t pos;

    for (uint window = abs(num); window > 0; window /= 10)
    {
        digits[pos++] = (window % 10);
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
        //sink.clear();
    }
}


// toAlpha
/++
 +  Translates an integer into an alphanumeric string. Assumes ASCII.
 +
 +  Overload that returns the string. Merely leverages `toAlphaInto`.
 +
 +  Example:
 +  ---
 +  int num = 12345;
 +  string asString = num.toAlpha;
 +  assert(asString == "12345");
 +  assert(asString == num.to!string);
 +  ---
 +
 +  Params:
 +      maxDigits = The maximum number of digits to expect input of.
 +      leadingZeroes = The minimum amount of leading zeroes to include in the
 +          output, mirroring the format specifier "`%0nd`".
 +      num = Integer to translate into string.
 +
 +  Returns:
 +      The passed integer `num` in string form.
 +/
string toAlpha(size_t maxDigits = 12, uint leadingZeroes = 0)(const int num)
{
    import std.array : Appender;

    Appender!string sink;
    sink.reserve((num >= 0) ? maxDigits : maxDigits+1);
    num.toAlphaInto!(maxDigits, leadingZeroes)(sink);
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
}
