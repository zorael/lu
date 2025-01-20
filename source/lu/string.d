/++
    String manipulation functions complementing the standard library.

    Example:
    ---
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast(" :");
        assert(lorem == "Lorem ipsum", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast(':');
        assert(lorem == "Lorem ipsum ", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum sit amet";  // mutable, will be modified by ref
        string[] words;

        while (line.length > 0)
        {
            immutable word = line.advancePast(" ", inherit: true);
            words ~= word;
        }

        assert(words == [ "Lorem", "ipsum", "sit", "amet" ]);
    }
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.string;

private:

import std.traits : allSameType;

public:

@safe:


// advancePast
/++
    Given some string, finds the supplied needle token in it, returns the
    string up to that point, and advances the passed string by ref to after the token.

    The closest equivalent in Phobos is [std.algorithm.searching.findSplit],
    which largely serves the same function but doesn't advance the input string.

    Additionally takes an optional `inherit` bool argument, to toggle
    whether the return value inherits the passed line (and clearing it) upon no
    needle match.

    Example:
    ---
    string foobar = "foo bar!";
    string foo = foobar.advancePast(" ");
    string bar = foobar.advancePast("!");

    assert((foo == "foo"), foo);
    assert((bar == "bar"), bar);
    assert(!foobar.length);

    enum line = "abc def ghi";
    string def = line[4..$].advancePast(" ");  // now with auto ref

    string foobar2 = "foo bar!";
    string foo2 = foobar2.advancePast(" ");
    string bar2 = foobar2.advancePast("?", inherit: true);

    assert((foo2 == "foo"), foo2);
    assert((bar2 == "bar!"), bar2);
    assert(!foobar2.length);

    string slice2 = "snarfl";
    string verb2 = slice2.advancePast(" ", inherit: true);

    assert((verb2 == "snarfl"), verb2);
    assert(!slice2.length, slice2);
    ---

    Params:
        haystack = Array to walk and advance.
        needle = Token that delimits what should be returned and to where to advance.
            May be another array or some individual character.
        inherit = Optional flag of whether or not the whole string should be
            returned and the haystack variable cleared on no needle match.
        callingFile = Optional file name to attach to an exception.
        callingLine = Optional line number to attach to an exception.

    Returns:
        The string `haystack` from the start up to the needle token. The original
        variable is advanced to after the token.

    Throws:
        [AdvanceException] if the needle could not be found in the string.
 +/
auto advancePast(Haystack, Needle)
    (auto ref return scope Haystack haystack,
    const scope Needle needle,
    const bool inherit = false,
    const string callingFile = __FILE__,
    const size_t callingLine = __LINE__) @safe
in
{
    import std.traits : isArray;

    static if (isArray!Needle)
    {
        if (!needle.length)
        {
            enum message = "Tried to `advancePast` with no `needle` given";
            throw new AdvanceExceptionImpl!(Haystack, Needle)
                (message,
                haystack.idup,
                needle.idup,
                callingFile,
                callingLine);
        }
    }
}
do
{
    import std.traits : isArray, isMutable, isSomeChar;

    static if (!isMutable!Haystack)
    {
        enum message = "`advancePast` only works on mutable haystacks";
        static assert(0, message);
    }
    else static if (!isArray!Haystack)
    {
        enum message = "`advancePast` only works on array-type haystacks";
        static assert(0, message);
    }
    else static if (
        !isArray!Haystack &&
        !is(Needle : ElementType!Haystack) &&
        !is(Needle : ElementEncodingType!Haystack))
    {
        enum message = "`advancePast` only works with array- or single-element-type needles";
        static assert(0, message);
    }

    static if (isArray!Needle || isSomeChar!Needle)
    {
        import std.string : indexOf;
        immutable index = haystack.indexOf(needle);
    }
    else
    {
        import std.algorithm.searching : countUntil;
        immutable index = haystack.countUntil(needle);
    }

    if (index == -1)
    {
        if (inherit)
        {
            // No needle match; inherit string and clear the original
            static if (__traits(isRef, haystack)) scope(exit) haystack = null;
            return haystack;
        }

        static if (isArray!Needle)
        {
            immutable needleIdup = needle.idup;
        }
        else
        {
            alias needleIdup = needle;
        }

        enum message = "Tried to advance a string past something that wasn't there";
        throw new AdvanceExceptionImpl!(Haystack, Needle)
            (message,
            haystack.idup,
            needleIdup,
            callingFile,
            callingLine);
    }

    static if (isArray!Needle)
    {
        immutable separatorLength = needle.length;
    }
    else
    {
        enum separatorLength = 1;
    }

    static if (__traits(isRef, haystack)) scope(exit) haystack = haystack[(index+separatorLength)..$];
    return haystack[0..index];
}


///
unittest
{
    import std.conv : to;
    import std.string : indexOf;

    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast(" :");
        assert(lorem == "Lorem ipsum", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        //immutable lorem = line.advancePast(" :");
        immutable lorem = line.advancePast(" :");
        assert(lorem == "Lorem ipsum", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast(':');
        assert(lorem == "Lorem ipsum ", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast(':');
        assert(lorem == "Lorem ipsum ", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast(' ');
        assert(lorem == "Lorem", lorem);
        assert(line == "ipsum :sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast(' ');
        assert(lorem == "Lorem", lorem);
        assert(line == "ipsum :sit amet", line);
    }
    /*{
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast("");
        assert(!lorem.length, lorem);
        assert(line == "Lorem ipsum :sit amet", line);
    }*/
    /*{
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast("");
        assert(!lorem.length, lorem);
        assert(line == "Lorem ipsum :sit amet", line);
    }*/
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast("Lorem ipsum");
        assert(!lorem.length, lorem);
        assert(line == " :sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.advancePast("Lorem ipsum");
        assert(!lorem.length, lorem);
        assert(line == " :sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable dchar dspace = ' ';
        immutable lorem = line.advancePast(dspace);
        assert(lorem == "Lorem", lorem);
        assert(line == "ipsum :sit amet", line);
    }
    {
        dstring dline = "Lorem ipsum :sit amet"d;
        immutable dspace = " "d;
        immutable lorem = dline.advancePast(dspace);
        assert((lorem == "Lorem"d), lorem.to!string);
        assert((dline == "ipsum :sit amet"d), dline.to!string);
    }
    {
        dstring dline = "Lorem ipsum :sit amet"d;
        immutable wchar wspace = ' ';
        immutable lorem = dline.advancePast(wspace);
        assert((lorem == "Lorem"d), lorem.to!string);
        assert((dline == "ipsum :sit amet"d), dline.to!string);
    }
    {
        wstring wline = "Lorem ipsum :sit amet"w;
        immutable wchar wspace = ' ';
        immutable lorem = wline.advancePast(wspace);
        assert((lorem == "Lorem"w), lorem.to!string);
        assert((wline == "ipsum :sit amet"w), wline.to!string);
    }
    {
        wstring wline = "Lorem ipsum :sit amet"w;
        immutable wspace = " "w;
        immutable lorem = wline.advancePast(wspace);
        assert((lorem == "Lorem"w), lorem.to!string);
        assert((wline == "ipsum :sit amet"w), wline.to!string);
    }
    {
        string user = "foo!bar@asdf.adsf.com";
        user = user.advancePast('!');
        assert((user == "foo"), user);
    }
    {
        immutable def = "abc def ghi"[4..$].advancePast(" ");
        assert((def == "def"), def);
    }
    {
        import std.exception : assertThrown;
        assertThrown!AdvanceException("abc def ghi"[4..$].advancePast(""));
    }
    {
        string line = "Lorem ipsum";
        immutable head = line.advancePast(" ");
        assert((head == "Lorem"), head);
        assert((line == "ipsum"), line);
    }
    {
        string line = "Lorem";
        immutable head = line.advancePast(" ", inherit: true);
        assert((head == "Lorem"), head);
        assert(!line.length, line);
    }
    {
        string slice = "verb";
        string verb;

        if (slice.indexOf(' ') != -1)
        {
            verb = slice.advancePast(' ');
        }
        else
        {
            verb = slice;
            slice = string.init;
        }

        assert((verb == "verb"), verb);
        assert(!slice.length, slice);
    }
    {
        string slice = "verb";
        immutable verb = slice.advancePast(' ', inherit: true);
        assert((verb == "verb"), verb);
        assert(!slice.length, slice);
    }
    {
        string url = "https://google.com/index.html#fragment-identifier";
        url = url.advancePast('#', inherit: true);
        assert((url == "https://google.com/index.html"), url);
    }
    {
        string url = "https://google.com/index.html";
        url = url.advancePast('#', inherit: true);
        assert((url == "https://google.com/index.html"), url);
    }
    {
        string line = "Lorem ipsum sit amet";
        string[] words;

        while (line.length > 0)
        {
            immutable word = line.advancePast(" ", inherit: true);
            words ~= word;
        }

        assert(words == [ "Lorem", "ipsum", "sit", "amet" ]);
    }
    {
        import std.exception : assertThrown;
        string url = "https://google.com/index.html#fragment-identifier";
        assertThrown!AdvanceException(url.advancePast("", inherit: true));
    }
}


// AdvanceException
/++
    Exception, to be thrown when a call to [advancePast] went wrong.

    It is a normal [object.Exception|Exception] but with an attached needle and haystack.
 +/
abstract class AdvanceException : Exception
{
    /++
        Returns a string of the original haystack the call to [advancePast] was operating on.
     +/
    string haystack() pure @safe;

    /++
        Returns a string of the original needle the call to [advancePast] was operating on.
     +/
    string needle() pure @safe;

    /++
        Create a new [AdvanceExceptionImpl], without attaching anything.
     +/
    this(
        const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }
}


// AdvanceExceptionImpl
/++
    Exception, to be thrown when a call to [advancePast] went wrong.

    This is the templated implementation, so that we can support more than one
    kind of needle and haystack combination.

    It is a normal [object.Exception|Exception] but with an attached needle and haystack.

    Params:
        Haystack = Haystack array type.
        Needle = Needle array or char-like type.
 +/
final class AdvanceExceptionImpl(Haystack, Needle) : AdvanceException
{
private:
    import std.conv : to;

    /++
        Raw haystack that `haystack` converts to string and returns.
     +/
    string _haystack;

    /++
        Raw needle that `needle` converts to string and returns.
     +/
    string _needle;

public:
    /++
        Returns a string of the original needle the call to `advancePast` was operating on.

        Returns:
            The raw haystack (be it any kind of string), converted to a `string`.
     +/
    override string haystack() pure @safe
    {
        return _haystack;
    }

    /++
        Returns a string of the original needle the call to `advancePast` was operating on.

        Returns:
            The raw needle (be it any kind of string or character), converted to a `string`.
     +/
    override string needle() pure @safe
    {
        return _needle;
    }

    /++
        Create a new `AdvanceExceptionImpl`, without attaching anything.
     +/
    this(
        const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure @safe nothrow @nogc
    {
        super(message, file, line, nextInChain);
    }

    /++
        Create a new `AdvanceExceptionImpl`, attaching a command.
     +/
    this(
        const string message,
        const Haystack haystack,
        const Needle needle,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure @safe
    {
        this._haystack = haystack.to!string;
        this._needle = needle.to!string;
        super(message, file, line, nextInChain);
    }
}


// plurality
/++
    Selects the correct singular or plural form of a word depending on the
    numerical count of it.

    Technically works with any type provided the number is some comparable integral.

    Example:
    ---
    string one = 1.plurality("one", "two");
    string two = 2.plurality("one", "two");
    string many = (-2).plurality("one", "many");
    string many0 = 0.plurality("one", "many");

    assert((one == "one"), one);
    assert((two == "two"), two);
    assert((many == "many"), many);
    assert((many0 == "many"), many0);
    ---

    Params:
        num = Numerical count.
        singular = The singular form.
        plural = The plural form.

    Returns:
        The singular if num is `1` or `-1`, otherwise the plural.
 +/
pragma(inline, true)
T plurality(Num, T)(
    const Num num,
    const return scope T singular,
    const return scope T plural) pure nothrow @nogc
{
    import std.traits : isIntegral;

    static if (!isIntegral!Num)
    {
        enum message = "`plurality` only works with integral types";
        static assert(0, message);
    }

    return ((num == 1) || (num == -1)) ? singular : plural;
}

///
unittest
{
    static assert(10.plurality("one","many") == "many");
    static assert(1.plurality("one", "many") == "one");
    static assert((-1).plurality("one", "many") == "one");
    static assert(0.plurality("one", "many") == "many");
}


// unenclosed
/++
    Removes paired preceding and trailing tokens around a string line.
    Assumes ASCII.

    You should not need to use this directly; rather see [unquoted] and
    [unsinglequoted].

    Params:
        token = Token character to strip away.
        line = String line to remove any enclosing tokens from.

    Returns:
        A slice of the passed string line without enclosing tokens.
 +/
private auto unenclosed(char token = '"')(/*const*/ return scope string line) pure nothrow @nogc
{
    enum escaped = "\\" ~ token;

    if (line.length < 2)
    {
        return line;
    }
    else if ((line[0] == token) && (line[$-1] == token))
    {
        if ((line.length >= 3) && (line[$-2..$] == escaped))
        {
            // End quote is escaped
            return line;
        }

        return line[1..$-1].unenclosed!token;
    }
    else
    {
        return line;
    }
}


// unquoted
/++
    Removes paired preceding and trailing double quotes, unquoting a word.
    Assumes ASCII.

    Does not decode the string and may thus give weird results on weird inputs.

    Example:
    ---
    string quoted = `"This is a quote"`;
    string unquotedLine = quoted.unquoted;
    assert((unquotedLine == "This is a quote"), unquotedLine);
    ---

    Params:
        line = The (potentially) quoted string.

    Returns:
        A slice of the `line` argument that excludes the quotes.
 +/
pragma(inline, true)
auto unquoted(/*const*/ return scope string line) pure nothrow @nogc
{
    return unenclosed!'"'(line);
}

///
unittest
{
    assert(`"Lorem ipsum sit amet"`.unquoted == "Lorem ipsum sit amet");
    assert(`"""""Lorem ipsum sit amet"""""`.unquoted == "Lorem ipsum sit amet");
    // Unbalanced quotes are left untouched
    assert(`"Lorem ipsum sit amet`.unquoted == `"Lorem ipsum sit amet`);
    assert(`"Lorem \"`.unquoted == `"Lorem \"`);
    assert("\"Lorem \\\"".unquoted == "\"Lorem \\\"");
    assert(`"\"`.unquoted == `"\"`);
}


// unsinglequoted
/++
    Removes paired preceding and trailing single quotes around a line.
    Assumes ASCII.

    Does not decode the string and may thus give weird results on weird inputs.

    Example:
    ---
    string quoted = `'This is single-quoted'`;
    string unquotedLine = quoted.unsinglequoted;
    assert((unquotedLine == "This is single-quoted"), unquotedLine);
    ---

    Params:
        line = The (potentially) single-quoted string.

    Returns:
        A slice of the `line` argument that excludes the single-quotes.
 +/
pragma(inline, true)
auto unsinglequoted(/*const*/ return scope string line) pure nothrow @nogc
{
    return unenclosed!'\''(line);
}

///
unittest
{
    assert(`'Lorem ipsum sit amet'`.unsinglequoted == "Lorem ipsum sit amet");
    assert(`''''Lorem ipsum sit amet''''`.unsinglequoted == "Lorem ipsum sit amet");
    // Unbalanced quotes are left untouched
    assert(`'Lorem ipsum sit amet`.unsinglequoted == `'Lorem ipsum sit amet`);
    assert(`'Lorem \'`.unsinglequoted == `'Lorem \'`);
    assert("'Lorem \\'".unsinglequoted == "'Lorem \\'");
    assert(`'`.unsinglequoted == `'`);
}


// stripSuffix
/++
    Strips the supplied string from the end of a string.

    Example:
    ---
    string suffixed = "Kameloso";
    string stripped = suffixed.stripSuffix("oso");
    assert((stripped == "Kamel"), stripped);
    ---

    Params:
        line = Original line to strip the suffix from.
        suffix = Suffix string to strip.

    Returns:
        `line` with `suffix` sliced off the end.
 +/
auto stripSuffix(
    /*const*/ return scope string line,
    const scope string suffix) pure nothrow @nogc
{
    if (line.length < suffix.length) return line;
    return (line[($-suffix.length)..$] == suffix) ? line[0..($-suffix.length)] : line;
}

///
unittest
{
    immutable line = "harblsnarbl";
    assert(line.stripSuffix("snarbl") == "harbl");
    assert(line.stripSuffix("") == "harblsnarbl");
    assert(line.stripSuffix("INVALID") == "harblsnarbl");
    assert(!line.stripSuffix("harblsnarbl").length);
}


// tabs
/++
    Returns a range of *spaces* equal to that of `num` tabs (\t).

    Use [std.conv.to] or [std.conv.text] or similar to flatten to a string.

    Example:
    ---
    string indentation = 2.tabs.text;
    assert((indentation == "        "), `"` ~  indentation ~ `"`);
    string smallIndent = 1.tabs!2.text;
    assert((smallIndent == "  "), `"` ~  smallIndent ~ `"`);
    ---

    Params:
        spaces = How many spaces make up a tab.
        num = How many tabs we want.

    Returns:
        A range of whitespace equalling (`num` * `spaces`) spaces.
 +/
auto tabs(uint spaces = 4)(const int num) pure nothrow @nogc
in ((num >= 0), "Negative number of tabs passed to `tabs`")
{
    import std.range : repeat, takeExactly;
    import std.algorithm.iteration : joiner;
    import std.array : array;

    static immutable char[spaces] tab = ' '.repeat.takeExactly(spaces).array;
    return tab[].repeat.takeExactly(num).joiner;
}

///
@system
unittest
{
    import std.array : Appender;
    import std.conv : to;
    import std.exception : assertThrown;
    import std.format : formattedWrite;
    import std.algorithm.comparison : equal;
    import core.exception : AssertError;

    auto one = 1.tabs!4;
    auto two = 2.tabs!3;
    auto three = 3.tabs!2;
    auto zero = 0.tabs;

    assert(one.equal("    "), one.to!string);
    assert(two.equal("      "), two.to!string);
    assert(three.equal("      "), three.to!string);
    assert(zero.equal(string.init), zero.to!string);

    assertThrown!AssertError((-1).tabs);

    Appender!(char[]) sink;
    sink.formattedWrite("%sHello world", 2.tabs!2);
    assert((sink[] == "    Hello world"), sink[]);
}


// indentInto
/++
    Indents lines in a string into an output range sink with the supplied number of tabs.

    Params:
        spaces = How many spaces in an indenting tab.
        wallOfText = String to indent the individual lines of.
        sink = Output range to fill with the indented lines.
        numTabs = Optional amount of tabs to indent with, default 1.
        skip = How many lines to skip indenting.
 +/
void indentInto(uint spaces = 4, Sink)
    (const string wallOfText,
    auto ref Sink sink,
    const uint numTabs = 1,
    const uint skip = 0)
{
    import std.algorithm.iteration : splitter;
    import std.range : enumerate;
    import std.range : isOutputRange;

    static if (!isOutputRange!(Sink, char[]))
    {
        enum message = "`indentInto` only works with output ranges of `char[]`";
        static assert(0, message);
    }

    if (numTabs == 0)
    {
        sink.put(wallOfText);
        return;
    }

    // Must be mutable to work with formattedWrite. That or .to!string
    auto indent = numTabs.tabs!spaces;

    foreach (immutable i, immutable line; wallOfText.splitter("\n").enumerate)
    {
        if (i > 0) sink.put("\n");

        if (!line.length)
        {
            sink.put("\n");
            continue;
        }

        if (skip > i)
        {
            sink.put(line);
        }
        else
        {
            // Cannot just put(indent), put(line) because indent is a joiner Result
            import std.format : formattedWrite;
            sink.formattedWrite("%s%s", indent, line);
        }
    }
}

///
unittest
{
    import std.array : Appender;

    Appender!(char[]) sink;

    immutable string_ =
"Lorem ipsum
sit amet
I don't remember
any more offhand
so shrug";

    string_.indentInto(sink);
    assert((sink[] ==
"    Lorem ipsum
    sit amet
    I don't remember
    any more offhand
    so shrug"), '\n' ~ sink[]);

    sink.clear();
    string_.indentInto!3(sink, 2);
    assert((sink[] ==
"      Lorem ipsum
      sit amet
      I don't remember
      any more offhand
      so shrug"), '\n' ~ sink[]);

    sink.clear();
    string_.indentInto(sink, 0);
    assert((sink[] ==
"Lorem ipsum
sit amet
I don't remember
any more offhand
so shrug"), '\n' ~ sink[]);
}


// indent
/++
    Indents lines in a string with the supplied number of tabs. Returns a newly
    allocated string.

    Params:
        spaces = How many spaces make up a tab.
        wallOfText = String to indent the lines of.
        numTabs = Amount of tabs to indent with, default 1.
        skip = How many lines to skip indenting.

    Returns:
        A string with all the lines of the original string indented.
 +/
string indent(uint spaces = 4)
    (const string wallOfText,
    const uint numTabs = 1,
    const uint skip = 0) pure
{
    import std.array : Appender;

    Appender!(char[]) sink;
    sink.reserve(wallOfText.length + 10*spaces*numTabs);  // Extra room for 10 indents
    wallOfText.indentInto!spaces(sink, numTabs, skip);
    return sink[];
}

///
unittest
{
    immutable string_ =
"Lorem ipsum
sit amet
I don't remember
any more offhand
so shrug";

    immutable indentedOne = string_.indent;
    assert((indentedOne ==
"    Lorem ipsum
    sit amet
    I don't remember
    any more offhand
    so shrug"), '\n' ~ indentedOne);

    immutable indentedTwo = string_.indent(2);
    assert((indentedTwo ==
"        Lorem ipsum
        sit amet
        I don't remember
        any more offhand
        so shrug"), '\n' ~ indentedTwo);

    immutable indentedZero = string_.indent(0);
    assert((indentedZero ==
"Lorem ipsum
sit amet
I don't remember
any more offhand
so shrug"), '\n' ~ indentedZero);

    immutable indentedSkipTwo = string_.indent(1, 2);
    assert((indentedSkipTwo ==
"Lorem ipsum
sit amet
    I don't remember
    any more offhand
    so shrug"), '\n' ~ indentedSkipTwo);
}


// strippedRight
/++
    Returns a slice of the passed string with any trailing whitespace and/or
    linebreaks sliced off. Overload that implicitly strips `" \n\r\t"`.

    Duplicates [std.string.stripRight], which we can no longer trust not to
    assert on unexpected input.

    Params:
        line = Line to strip the right side of.

    Returns:
        The passed line without any trailing whitespace or linebreaks.
 +/
auto strippedRight(/*const*/ return scope string line) pure nothrow @nogc
{
    if (!line.length) return line;
    return strippedRight(line, " \n\r\t");
}

///
unittest
{
    static if (!is(typeof("blah".strippedRight) == string))
    {
        enum message = "`lu.string.strippedRight` should return a mutable string";
        static assert(0, message);
    }

    {
        immutable trailing = "abc  ";
        immutable stripped = trailing.strippedRight;
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "  ";
        immutable stripped = trailing.strippedRight;
        assert((stripped == ""), stripped);
    }
    {
        immutable empty = "";
        immutable stripped = empty.strippedRight;
        assert((stripped == ""), stripped);
    }
    {
        immutable noTrailing = "abc";
        immutable stripped = noTrailing.strippedRight;
        assert((stripped == "abc"), stripped);
    }
    {
        immutable linebreak = "abc\r\n  \r\n";
        immutable stripped = linebreak.strippedRight;
        assert((stripped == "abc"), stripped);
    }
}


// strippedRight
/++
    Returns a slice of the passed string with any trailing passed characters.
    Implementation template capable of handling both individual characters and
    string of tokens to strip.

    Duplicates [std.string.stripRight], which we can no longer trust not to
    assert on unexpected input.

    Params:
        line = Line to strip the right side of.
        chaff = Character or string of characters to strip away.

    Returns:
        The passed line without any trailing passed characters.
 +/
auto strippedRight(Line, Chaff)
    (/*const*/ return scope Line line,
    const scope Chaff chaff) pure nothrow @nogc
{
    import std.traits : isArray;
    import std.range : ElementEncodingType, ElementType;

    static if (!isArray!Line)
    {
        enum message = "`strippedRight` only works on strings and arrays";
        static assert(0, message);
    }
    else static if (
        !is(Chaff : Line) &&
        !is(Chaff : ElementType!Line) &&
        !is(Chaff : ElementEncodingType!Line))
    {
        enum message = "`strippedRight` only works with array- or single-element-type chaff";
        static assert(0, message);
    }

    if (!line.length) return line;

    static if (isArray!Chaff)
    {
        if (!chaff.length) return line;
    }

    size_t pos = line.length;

    loop:
    while (pos > 0)
    {
        static if (isArray!Chaff)
        {
            import std.string : representation;

            immutable currentChar = line[pos-1];

            foreach (immutable c; chaff.representation)
            {
                if (currentChar == c)
                {
                    // Found a char we should strip
                    --pos;
                    continue loop;
                }
            }
        }
        else
        {
            if (line[pos-1] == chaff)
            {
                --pos;
                continue loop;
            }
        }

        break loop;
    }

    return line[0..pos];
}

///
unittest
{
    {
        immutable trailing = "abc,";
        immutable stripped = trailing.strippedRight(',');
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "abc!!!";
        immutable stripped = trailing.strippedRight('!');
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "abc";
        immutable stripped = trailing.strippedRight(' ');
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "";
        immutable stripped = trailing.strippedRight(' ');
        assert(!stripped.length, stripped);
    }
    {
        immutable trailing = "abc,!.-";
        immutable stripped = trailing.strippedRight("-.!,");
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "abc!!!";
        immutable stripped = trailing.strippedRight("!");
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "abc";
        immutable stripped = trailing.strippedRight(" ABC");
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "";
        immutable stripped = trailing.strippedRight(" ");
        assert(!stripped.length, stripped);
    }
}


// strippedLeft
/++
    Returns a slice of the passed string with any preceding whitespace and/or
    linebreaks sliced off. Overload that implicitly strips `" \n\r\t"`.

    Duplicates [std.string.stripLeft], which we can no longer trust not to
    assert on unexpected input.

    Params:
        line = Line to strip the left side of.

    Returns:
        The passed line without any preceding whitespace or linebreaks.
 +/
auto strippedLeft(/*const*/ return scope string line) pure nothrow @nogc
{
    if (!line.length) return line;
    return strippedLeft(line, " \n\r\t");
}

///
unittest
{
    static if (!is(typeof("blah".strippedLeft) == string))
    {
        enum message = "`lu.string.strippedLeft` should return a mutable string";
        static assert(0, message);
    }

    {
        immutable preceded = "   abc";
        immutable stripped = preceded.strippedLeft;
        assert((stripped == "abc"), stripped);
    }
    {
        immutable preceded = "   ";
        immutable stripped = preceded.strippedLeft;
        assert((stripped == ""), stripped);
    }
    {
        immutable empty = "";
        immutable stripped = empty.strippedLeft;
        assert((stripped == ""), stripped);
    }
    {
        immutable noPreceded = "abc";
        immutable stripped = noPreceded.strippedLeft;
        assert((stripped == noPreceded), stripped);
    }
    {
        immutable linebreak  = "\r\n\r\n  abc";
        immutable stripped = linebreak.strippedLeft;
        assert((stripped == "abc"), stripped);
    }
}


// strippedLeft
/++
    Returns a slice of the passed string with any preceding passed characters
    sliced off. Implementation capable of handling both individual characters
    and strings of tokens to strip.

    Duplicates [std.string.stripLeft], which we can no longer trust not to
    assert on unexpected input.

    Params:
        line = Line to strip the left side of.
        chaff = Character or string of characters to strip away.

    Returns:
        The passed line without any preceding passed characters.
 +/
auto strippedLeft(Line, Chaff)
    (/*const*/ return scope Line line,
    const scope Chaff chaff) pure nothrow @nogc
{
    import std.traits : isArray;
    import std.range : ElementEncodingType, ElementType;

    static if (!isArray!Line)
    {
        enum message = "`strippedLeft` only works on strings and arrays";
        static assert(0, message);
    }
    else static if (
        !is(Chaff : Line) &&
        !is(Chaff : ElementType!Line) &&
        !is(Chaff : ElementEncodingType!Line))
    {
        enum message = "`strippedLeft` only works with array- or single-element-type chaff";
        static assert(0, message);
    }

    if (!line.length) return line;

    static if (isArray!Chaff)
    {
        if (!chaff.length) return line;
    }

    size_t pos;

    loop:
    while (pos < line.length)
    {
        static if (isArray!Chaff)
        {
            import std.string : representation;

            immutable currentChar = line[pos];

            foreach (immutable c; chaff.representation)
            {
                if (currentChar == c)
                {
                    // Found a char we should strip
                    ++pos;
                    continue loop;
                }
            }
        }
        else
        {
            if (line[pos] == chaff)
            {
                ++pos;
                continue loop;
            }
        }

        break loop;
    }

    return line[pos..$];
}

///
unittest
{
    {
        immutable trailing = ",abc";
        immutable stripped = trailing.strippedLeft(',');
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "!!!abc";
        immutable stripped = trailing.strippedLeft('!');
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "abc";
        immutable stripped = trailing.strippedLeft(' ');
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "";
        immutable stripped = trailing.strippedLeft(' ');
        assert(!stripped.length, stripped);
    }
    {
        immutable trailing = ",abc";
        immutable stripped = trailing.strippedLeft(",");
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "!!!abc";
        immutable stripped = trailing.strippedLeft(",1!");
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "abc";
        immutable stripped = trailing.strippedLeft(" ");
        assert((stripped == "abc"), stripped);
    }
    {
        immutable trailing = "";
        immutable stripped = trailing.strippedLeft(" ");
        assert(!stripped.length, stripped);
    }
}


// stripped
/++
    Returns a slice of the passed string with any preceding or trailing
    whitespace or linebreaks sliced off both ends. Overload that implicitly
    strips `" \n\r\t"`.

    It merely calls both [strippedLeft] and [strippedRight]. As such it
    duplicates [std.string.strip], which we can no longer trust not to assert
    on unexpected input.

    Params:
        line = Line to strip both the right and left side of.

    Returns:
        The passed line, stripped of surrounding whitespace.
 +/
auto stripped(/*const*/ return scope string line) pure nothrow @nogc
{
    return line.strippedLeft.strippedRight;
}

///
unittest
{
    static if (!is(typeof("blah".stripped) == string))
    {
        enum message = "`lu.string.stripped` should return a mutable string";
        static assert(0, message);
    }

    {
        immutable line = "   abc   ";
        immutable stripped_ = line.stripped;
        assert((stripped_ == "abc"), stripped_);
    }
    {
        immutable line = "   ";
        immutable stripped_ = line.stripped;
        assert((stripped_ == ""), stripped_);
    }
    {
        immutable line = "";
        immutable stripped_ = line.stripped;
        assert((stripped_ == ""), stripped_);
    }
    {
        immutable line = "abc";
        immutable stripped_ = line.stripped;
        assert((stripped_ == "abc"), stripped_);
    }
    {
        immutable line = " \r\n  abc\r\n\r\n";
        immutable stripped_ = line.stripped;
        assert((stripped_ == "abc"), stripped_);
    }
}


// stripped
/++
    Returns a slice of the passed string with any preceding or trailing
    passed characters sliced off. Implementation template capable of handling both
    individual characters and strings of tokens to strip.

    It merely calls both [strippedLeft] and [strippedRight]. As such it
    duplicates [std.string.strip], which we can no longer trust not to assert
    on unexpected input.

    Params:
        line = Line to strip both the right and left side of.
        chaff = Character or string of characters to strip away.

    Returns:
        The passed line, stripped of surrounding passed characters.
 +/
auto stripped(Line, Chaff)
    (/*const*/ return scope Line line,
    const scope Chaff chaff) pure nothrow @nogc
{
    import std.traits : isArray;
    import std.range : ElementEncodingType, ElementType;

    static if (!isArray!Line)
    {
        enum message = "`stripped` only works on strings and arrays";
        static assert(0, message);
    }
    else static if (
        !is(Chaff : Line) &&
        !is(Chaff : ElementType!Line) &&
        !is(Chaff : ElementEncodingType!Line))
    {
        enum message = "`stripped` only works with array- or single-element-type chaff";
        static assert(0, message);
    }

    return line.strippedLeft(chaff).strippedRight(chaff);
}

///
unittest
{
    {
        immutable line = "   abc   ";
        immutable stripped_ = line.stripped(' ');
        assert((stripped_ == "abc"), stripped_);
    }
    {
        immutable line = "!!!";
        immutable stripped_ = line.stripped('!');
        assert((stripped_ == ""), stripped_);
    }
    {
        immutable line = "";
        immutable stripped_ = line.stripped('_');
        assert((stripped_ == ""), stripped_);
    }
    {
        immutable line = "abc";
        immutable stripped_ = line.stripped('\t');
        assert((stripped_ == "abc"), stripped_);
    }
    {
        immutable line = " \r\n  abc\r\n\r\n  ";
        immutable stripped_ = line.stripped(' ');
        assert((stripped_ == "\r\n  abc\r\n\r\n"), stripped_);
    }
    {
        immutable line = "   abc   ";
        immutable stripped_ = line.stripped(" \t");
        assert((stripped_ == "abc"), stripped_);
    }
    {
        immutable line = "!,!!";
        immutable stripped_ = line.stripped("!,");
        assert((stripped_ == ""), stripped_);
    }
    {
        immutable line = "";
        immutable stripped_ = line.stripped("_");
        assert((stripped_ == ""), stripped_);
    }
    {
        immutable line = "abc";
        immutable stripped_ = line.stripped("\t\r\n");
        assert((stripped_ == "abc"), stripped_);
    }
    {
        immutable line = " \r\n  abc\r\n\r\n  ";
        immutable stripped_ = line.stripped(" _");
        assert((stripped_ == "\r\n  abc\r\n\r\n"), stripped_);
    }
}


// encode64
/++
    Base64-encodes a string.

    Merely wraps [std.base64.Base64.encode|Base64.encode] and
    [std.string.representation] into one function that will work with strings.

    Params:
        line = String line to encode.

    Returns:
        An encoded Base64 string.

    See_Also:
        - https://en.wikipedia.org/wiki/Base64
 +/
string encode64(const string line) pure nothrow
{
    import std.base64 : Base64;
    import std.string : representation;

    return Base64.encode(line.representation);
}

///
unittest
{
    {
        immutable password = "harbl snarbl 12345";
        immutable encoded = encode64(password);
        assert((encoded == "aGFyYmwgc25hcmJsIDEyMzQ1"), encoded);
    }
    {
        immutable string password;
        immutable encoded = encode64(password);
        assert(!encoded.length, encoded);
    }
}


// decode64
/++
    Base64-decodes a string.

    Merely wraps [std.base64.Base64.decode|Base64.decode] and
    [std.string.representation] into one function that will work with strings.

    Params:
        encoded = Encoded string to decode.

    Returns:
        A decoded normal string.

    See_Also:
        - https://en.wikipedia.org/wiki/Base64
 +/
string decode64(const string encoded) pure
{
    import std.base64 : Base64;
    return (cast(char[])Base64.decode(encoded)).idup;
}

///
unittest
{
    {
        immutable password = "base64:aGFyYmwgc25hcmJsIDEyMzQ1";
        immutable decoded = decode64(password[7..$]);
        assert((decoded == "harbl snarbl 12345"), decoded);
    }
    {
        immutable password = "base64:";
        immutable decoded = decode64(password[7..$]);
        assert(!decoded.length, decoded);
    }
}


// splitLineAtPosition
/++
    Splits a string with on boundary as delimited by a supplied separator, into
    one or more more lines not longer than the passed maximum length.

    If a line cannot be split due to the line being too short or the separator
    not occurring in the text, it is added to the returned array as-is and no
    more splitting is done.

    Example:
    ---
    string line = "I am a fish in a sort of long sentence~";
    enum maxLineLength = 20;
    auto splitLines = line.splitLineAtPosition(' ', maxLineLength);

    assert(splitLines[0] == "I am a fish in a");
    assert(splitLines[1] == "sort of a long");
    assert(splitLines[2] == "sentence~");
    ---

    Params:
        line = String line to split.
        separator = Separator character with which to split the `line`.
        maxLength = Maximum length of the separated lines.

    Returns:
        A `T[]` array with lines split out of the passed `line`.
 +/
auto splitLineAtPosition(Line, Separator)
    (const Line line,
    const Separator separator,
    const size_t maxLength) pure //nothrow
in
{
    static if (is(Separator : Line))
    {
        enum message = "Tried to `splitLineAtPosition` but no " ~
            "`separator` was supplied";
        assert(separator.length, message);
    }
}
do
{
    import std.traits : isArray;
    import std.range : ElementEncodingType, ElementType;

    static if (!isArray!Line)
    {
        enum message = "`splitLineAtPosition` only works on strings and arrays";
        static assert(0, message);
    }
    else static if (
        !is(Separator : Line) &&
        !is(Separator : ElementType!Line) &&
        !is(Separator : ElementEncodingType!Line))
    {
        enum message = "`splitLineAtPosition` only works on strings and arrays of characters";
        static assert(0, message);
    }

    string[] lines;
    if (!line.length) return lines;

    string slice = line;  // mutable
    lines.reserve(cast(int)(line.length / maxLength) + 1);

    whileloop:
    while(true)
    {
        import std.algorithm.comparison : min;

        for (size_t i = min(maxLength, slice.length); i > 0; --i)
        {
            if (slice[i-1] == separator)
            {
                lines ~= slice[0..i-1];
                slice = slice[i..$];
                continue whileloop;
            }
        }
        break;
    }

    if (slice.length)
    {
        // Remnant

        if (lines.length)
        {
            lines[$-1] ~= separator ~ slice;
        }
        else
        {
            // Max line was too short to fit anything. Returning whole line
            lines ~= slice;
        }
    }

    return lines;
}

///
unittest
{
    import std.conv : text;

    {
        immutable prelude = "PRIVMSG #garderoben :";
        immutable maxLength = 250 - prelude.length;

        immutable rawLine = "Lorem ipsum dolor sit amet, ea has velit noluisse, " ~
            "eos eius appetere constituto no, ad quas natum eos. Perpetua " ~
            "electram mnesarchum usu ne, mei vero dolorem no. Ea quando scripta " ~
            "quo, minim legendos ut vel. Ut usu graece equidem posidonium. Ius " ~
            "denique ponderum verterem no, quo te mentitum officiis referrentur. " ~
            "Sed an dolor iriure vocibus. " ~
            "Lorem ipsum dolor sit amet, ea has velit noluisse, " ~
            "eos eius appetere constituto no, ad quas natum eos. Perpetua " ~
            "electram mnesarchum usu ne, mei vero dolorem no. Ea quando scripta " ~
            "quo, minim legendos ut vel. Ut usu graece equidem posidonium. Ius " ~
            "denique ponderum verterem no, quo te mentitum officiis referrentur. " ~
            "Sed an dolor iriure vocibus. ssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "ssssssssssssssssssssssssssssssssssssssssssssssssssssssss";
        const splitLines = rawLine.splitLineAtPosition(' ', maxLength);
        assert((splitLines.length == 4), splitLines.length.text);
    }
    {
        immutable prelude = "PRIVMSG #garderoben :";
        immutable maxLength = 250 - prelude.length;

        immutable rawLine = "ssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" ~
            "ssssssssssssssssssssssssssssssssssssssssssssssssssssssss";
        const splitLines = rawLine.splitLineAtPosition(' ', maxLength);
        assert((splitLines.length == 1), splitLines.length.text);
        assert(splitLines[0] == rawLine);
    }
}


// escapeControlCharacters
/++
    Replaces the control characters '\n', '\t', '\r' and '\0' with the escaped
    "\\n", "\\t", "\\r" and "\\0". Does not allocate a new string if there
    was nothing to escape.

    Params:
        line = String line to escape characters in.

    Returns:
        A new string with control characters escaped, or the original one unchanged.
 +/
string escapeControlCharacters(/*const*/ return scope string line) pure nothrow
{
    import std.array : Appender;
    import std.string : representation;

    if (!line.length) return line;

    Appender!(char[]) sink;
    size_t lastEnd;
    bool reserved;

    immutable asBytes = line.representation;

    void commitUpTo(const size_t i)
    {
        if (!reserved)
        {
            sink.reserve(asBytes.length + 16);  // guesstimate
            reserved = true;
        }
        sink.put(asBytes[lastEnd..i]);
    }

    for (size_t i; i<asBytes.length; ++i)
    {
        import std.algorithm.comparison : among;

        if (asBytes[i].among!('\n', '\t', '\r', '\0'))
        {
            commitUpTo(i);
            lastEnd = i+1;

            switch (asBytes[i])
            {
            case '\n': sink.put(`\n`); break;
            case '\t': sink.put(`\t`); break;
            case '\r': sink.put(`\r`); break;
            case '\0': sink.put(`\0`); break;
            default: break;
            }
        }
    }

    if (!sink[].length) return line;

    sink.put(asBytes[lastEnd..$]);
    return sink[];
}

///
unittest
{
    {
        immutable line = "abc\ndef";
        immutable expected = "abc\\ndef";
        immutable actual = escapeControlCharacters(line);
        assert((actual == expected), actual);
    }
    {
        immutable line = "\n\t\r\0";
        immutable expected = "\\n\\t\\r\\0";
        immutable actual = escapeControlCharacters(line);
        assert((actual == expected), actual);
    }
    {
        immutable line = "";
        immutable expected = "";
        immutable actual = escapeControlCharacters(line);
        assert((actual == expected), actual);
        assert(actual is line);  // No string allocated
    }
    {
        immutable line = "nothing to escape";
        immutable expected = "nothing to escape";
        immutable actual = escapeControlCharacters(line);
        assert((actual == expected), actual);
        assert(actual is line);  // No string allocated
    }
}


// removeControlCharacters
/++
    Removes the control characters `'\n'`, `'\t'`, `'\r'` and `'\0'` from a string.
    Does not allocate a new string if there was nothing to remove.

    Params:
        line = String line to "remove" characters from.

    Returns:
        A new string with control characters removed, or the original one unchanged.
 +/
string removeControlCharacters(/*const*/ return scope string line) pure nothrow
{
    import std.array : Appender;
    import std.string : representation;

    if (!line.length) return line;

    Appender!(char[]) sink;
    size_t lastEnd;
    bool reserved;

    immutable asBytes = line.representation;

    void commitUpTo(const size_t i)
    {
        if (!reserved)
        {
            sink.reserve(asBytes.length);
            reserved = true;
        }
        sink.put(asBytes[lastEnd..i]);
    }

    for (size_t i; i<asBytes.length; ++i)
    {
        import std.algorithm.comparison : among;

        if (asBytes[i].among!('\n', '\t', '\r', '\0'))
        {
            commitUpTo(i);
            lastEnd = i+1;
        }
    }

    if (lastEnd == 0) return line;

    sink.put(asBytes[lastEnd..$]);
    return sink[];
}

///
unittest
{
    {
        immutable line = "abc\ndef";
        immutable expected = "abcdef";
        immutable actual = removeControlCharacters(line);
        assert((actual == expected), actual);
    }
    {
        immutable line = "\n\t\r\0";
        immutable expected = "";
        immutable actual = removeControlCharacters(line);
        assert((actual == expected), actual);
    }
    {
        immutable line = "";
        immutable expected = "";
        immutable actual = removeControlCharacters(line);
        assert((actual == expected), actual);
    }
    {
        immutable line = "nothing to escape";
        immutable expected = "nothing to escape";
        immutable actual = removeControlCharacters(line);
        assert((actual == expected), actual);
        assert(line is actual);  // No new string was allocated
    }
}


// SplitResults
/++
    The result of a call to [splitInto].
 +/
enum SplitResults
{
    /++
        The number of arguments passed the number of separated words in the input string.
     +/
    match,

    /++
        The input string did not have enough words to match the passed arguments.
     +/
    underrun,

    /++
        The input string had too many words and could not fit into the passed arguments.
     +/
    overrun,
}


// splitInto
/++
    Splits a string by a passed separator and assign the delimited words to the
    passed strings by ref.

    Note: Does *not* take quoted substrings into consideration.

    Params:
        separator = What token to separate the input string into words with.
        slice = Input string of words separated by `separator`.
        strings = Variadic list of strings to assign the split words in `slice`.

    Returns:
        A [SplitResults] with the results of the split attempt.
 +/
auto splitInto(string separator = " ", Strings...)
    (auto ref string slice,
    scope ref Strings strings)
if (Strings.length && is(Strings[0] == string) && allSameType!Strings)
{
    if (!slice.length)
    {
        return Strings.length ? SplitResults.underrun : SplitResults.match;
    }

    foreach (immutable i, ref thisString; strings)
    {
        import std.string : indexOf;

        ptrdiff_t pos = slice.indexOf(separator);  // mutable

        if ((pos == 0) && (separator.length < slice.length))
        {
            while (slice[0..separator.length] == separator)
            {
                slice = slice[separator.length..$];
            }

            pos = slice.indexOf(separator);
        }

        if (pos == -1)
        {
            thisString = slice;
            static if (__traits(isRef, slice)) slice = string.init;
            return (i+1 == Strings.length) ? SplitResults.match : SplitResults.underrun;
        }

        thisString = slice[0..pos];
        slice = slice[pos+separator.length..$];
    }

    return SplitResults.overrun;
}

///
unittest
{
    import lu.conv : Enum;

    {
        string line = "abc def ghi";
        string abc, def, ghi;
        immutable results = line.splitInto(abc, def, ghi);

        assert((abc == "abc"), abc);
        assert((def == "def"), def);
        assert((ghi == "ghi"), ghi);
        assert(!line.length, line);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc            def                                 ghi";
        string abc, def, ghi;
        immutable results = line.splitInto(abc, def, ghi);

        assert((abc == "abc"), abc);
        assert((def == "def"), def);
        assert((ghi == "ghi"), ghi);
        assert(!line.length, line);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc_def ghi";
        string abc, def, ghi;
        immutable results = line.splitInto!"_"(abc, def, ghi);

        assert((abc == "abc"), abc);
        assert((def == "def ghi"), def);
        assert(!ghi.length, ghi);
        assert(!line.length, line);
        assert((results == SplitResults.underrun), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc def ghi";
        string abc, def;
        immutable results = line.splitInto(abc, def);

        assert((abc == "abc"), abc);
        assert((def == "def"), def);
        assert((line == "ghi"), line);
        assert((results == SplitResults.overrun), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc///def";
        string abc, def;
        immutable results = line.splitInto!"//"(abc, def);

        assert((abc == "abc"), abc);
        assert((def == "/def"), def);
        assert(!line.length, line);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc 123 def I am a fish";
        string abc, a123, def;
        immutable results = line.splitInto(abc, a123, def);

        assert((abc == "abc"), abc);
        assert((a123 == "123"), a123);
        assert((def == "def"), def);
        assert((line == "I am a fish"), line);
        assert((results == SplitResults.overrun), Enum!SplitResults.toString(results));
    }
    {
        string line;
        string abc, def;
        immutable results = line.splitInto(abc, def);
        assert((results == SplitResults.underrun), Enum!SplitResults.toString(results));
    }
}


// splitInto
/++
    Splits a string by a passed separator and assign the delimited words to the
    passed strings by ref. Overload that stores overflow strings into a passed array.

    Note: *Does* take quoted substrings into consideration.

    Params:
        separator = What token to separate the input string into words with.
        slice = Input string of words separated by `separator`.
        strings = Variadic list of strings to assign the split words in `slice`.
        overflow = Overflow array.

    Returns:
        A [SplitResults] with the results of the split attempt.
 +/
auto splitInto(string separator = " ", Strings...)
    (const string slice,
    ref Strings strings,
    out string[] overflow)
if (!Strings.length || (is(Strings[0] == string) && allSameType!Strings))
{
    if (!slice.length)
    {
        return Strings.length ? SplitResults.underrun : SplitResults.match;
    }

    auto chunks = splitWithQuotes!separator(slice);

    foreach (immutable i, ref thisString; strings)
    {
        if (chunks.length > i)
        {
            thisString = chunks[i];
        }
    }

    if (strings.length < chunks.length)
    {
        overflow = chunks[strings.length..$];
        return SplitResults.overrun;
    }
    else if (strings.length == chunks.length)
    {
        return SplitResults.match;
    }
    else /*if (strings.length > chunks.length)*/
    {
        return SplitResults.underrun;
    }
}

///
unittest
{
    import lu.conv : Enum;
    import std.conv : text;

    {
        string line = "abc def ghi";
        string abc, def, ghi;
        string[] overflow;
        immutable results = line.splitInto(abc, def, ghi, overflow);

        assert((abc == "abc"), abc);
        assert((def == "def"), def);
        assert((ghi == "ghi"), ghi);
        assert(!overflow.length, overflow.text);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc##def##ghi";
        string abc, def, ghi;
        string[] overflow;
        immutable results = line.splitInto!"##"(abc, def, ghi, overflow);

        assert((abc == "abc"), abc);
        assert((def == "def"), def);
        assert((ghi == "ghi"), ghi);
        assert(!overflow.length, overflow.text);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc  def  ghi";
        string abc, def, ghi;
        string[] overflow;
        immutable results = line.splitInto(abc, def, ghi, overflow);

        assert((abc == "abc"), abc);
        assert((def == "def"), def);
        assert((ghi == "ghi"), ghi);
        assert(!overflow.length, overflow.text);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc_def ghi";
        string abc, def, ghi;
        string[] overflow;
        immutable results = line.splitInto!"_"(abc, def, ghi, overflow);

        assert((abc == "abc"), abc);
        assert((def == "def ghi"), def);
        assert(!ghi.length, ghi);
        assert(!overflow.length, overflow.text);
        assert((results == SplitResults.underrun), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc def ghi";
        string abc, def;
        string[] overflow;
        immutable results = line.splitInto(abc, def, overflow);

        assert((abc == "abc"), abc);
        assert((def == "def"), def);
        assert((overflow == [ "ghi" ]), overflow.text);
        assert((results == SplitResults.overrun), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc///def";
        string abc, def;
        string[] overflow;
        immutable results = line.splitInto!"//"(abc, def, overflow);

        assert((abc == "abc"), abc);
        assert((def == "/def"), def);
        assert(!overflow.length, overflow.text);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc 123 def I am a fish";
        string abc, a123, def;
        string[] overflow;
        immutable results = line.splitInto(abc, a123, def, overflow);

        assert((abc == "abc"), abc);
        assert((a123 == "123"), a123);
        assert((def == "def"), def);
        assert((overflow == [ "I", "am", "a", "fish" ]), overflow.text);
        assert((results == SplitResults.overrun), Enum!SplitResults.toString(results));
    }
    {
        string line = `abc 123 def "I am a fish"`;
        string abc, a123, def;
        string[] overflow;
        immutable results = line.splitInto(abc, a123, def, overflow);

        assert((abc == "abc"), abc);
        assert((a123 == "123"), a123);
        assert((def == "def"), def);
        assert((overflow == [ "I am a fish" ]), overflow.text);
        assert((results == SplitResults.overrun), Enum!SplitResults.toString(results));
    }
    {
        string line;
        string abc, def;
        string[] overflow;
        immutable results = line.splitInto(abc, def, overflow);
        assert((results == SplitResults.underrun), Enum!SplitResults.toString(results));
    }
    {
        string line = "abchonkelonkhonkelodef";
        string abc, def;
        string[] overflow;
        immutable results = line.splitInto!"honkelonk"(abc, def, overflow);

        assert((abc == "abc"), abc);
        assert((def == "honkelodef"), def);
        assert(!overflow.length, overflow.text);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "honkelonkhonkelodef";
        string abc, def;
        string[] overflow;
        immutable results = line.splitInto!"honkelonk"(abc, def, overflow);

        assert((abc == "honkelodef"), abc);
        assert((def == string.init), def);
        assert(!overflow.length, overflow.text);
        assert((results == SplitResults.underrun), Enum!SplitResults.toString(results));
    }
    {
        string line = "###########hirrsteff#snabel";
        string abc, def;
        string[] overflow;
        immutable results = line.splitInto!"#"(abc, def, overflow);

        assert((abc == "hirrsteff"), abc);
        assert((def == "snabel"), def);
        assert(!overflow.length, overflow.text);
        assert((results == SplitResults.match), Enum!SplitResults.toString(results));
    }
    {
        string line = "abc def ghi";
        string[] overflow;
        immutable results = line.splitInto(overflow);
        immutable expectedOverflow = [ "abc", "def", "ghi" ];

        assert((overflow == expectedOverflow), overflow.text);
        assert((results == SplitResults.overrun), Enum!SplitResults.toString(results));
    }
}


// splitWithQuotes
/++
    Splits a string into an array of strings by whitespace, but honours quotes.

    Intended to be used with ASCII strings; may or may not work with more
    elaborate UTF-8 strings.

    Example:
    ---
    string s = `title "this is my title" author "john doe"`;
    immutable splitUp = splitWithQuotes(s);
    assert(splitUp == [ "title", "this is my title", "author", "john doe" ]);
    ---

    Params:
        separator = Separator string. May be more than one character.
        line = Input string.

    Returns:
        A `string[]` composed of the input string split up into substrings,
        delimited by whitespace. Quoted sections are treated as one substring.
 +/
auto splitWithQuotes(string separator = " ")(const string line)
{
    import std.array : Appender;
    import std.string : representation;

    static if (!separator.length)
    {
        enum message = "`splitWithQuotes` only works with non-empty separators";
        static assert(0, message);
    }

    if (!line.length) return null;

    Appender!(string[]) sink;
    sink.reserve(8);  // guesstimate

    size_t start;
    bool betweenQuotes;
    bool escaping;
    bool escapedAQuote;
    bool escapedABackslash;

    string replaceEscaped(const string line)
    {
        import std.array : replace;

        string slice = line;  // mutable
        if (escapedABackslash) slice = slice.replace(`\\`, "\1\1");
        if (escapedAQuote) slice = slice.replace(`\"`, `"`);
        if (escapedABackslash) slice = slice.replace("\1\1", `\`);
        return slice;
    }

    immutable asUbytes = line.representation;
    size_t separatorStep;

    for (size_t i; i < asUbytes.length; ++i)
    {
        immutable c = asUbytes[i];

        if (escaping)
        {
            if (c == '\\')
            {
                escapedABackslash = true;
            }
            else if (c == '"')
            {
                escapedAQuote = true;
            }

            escaping = false;
        }
        else if (separatorStep >= separator.length)
        {
            separatorStep = 0;
        }
        else if (!betweenQuotes && (c == separator[separatorStep]))
        {
            static if (separator.length > 1)
            {
                if (i == 0)
                {
                    ++separatorStep;
                    continue;
                }
                else if (++separatorStep >= separator.length)
                {
                    // Full separator
                    immutable end = i-separator.length+1;
                    if (start != end) sink.put(line[start..end]);
                    start = i+1;
                }
            }
            else
            {
                // Full separator
                if (start != i) sink.put(line[start..i]);
                start = i+1;
            }
        }
        else if (c == '\\')
        {
            escaping = true;
        }
        else if (c == '"')
        {
            if (betweenQuotes)
            {
                if (escapedAQuote || escapedABackslash)
                {
                    sink.put(replaceEscaped(line[start+1..i]));
                    escapedAQuote = false;
                    escapedABackslash = false;
                }
                else if (i > start+1)
                {
                    sink.put(line[start+1..i]);
                }

                betweenQuotes = false;
                start = i+1;
            }
            else if (i > start+1)
            {
                sink.put(line[start+1..i]);
                betweenQuotes = true;
                start = i+1;
            }
            else
            {
                betweenQuotes = true;
            }
        }
    }

    if (line.length > start+1)
    {
        if (betweenQuotes)
        {
            if (escapedAQuote || escapedABackslash)
            {
                sink.put(replaceEscaped(line[start+1..$]));
            }
            else
            {
                sink.put(line[start+1..$]);
            }
        }
        else
        {
            sink.put(line[start..$]);
        }
    }

    return sink[];
}

///
unittest
{
    import std.conv : text;

    {
        enum input = `title "this is my title" author "john doe"`;
        immutable splitUp = splitWithQuotes(input);
        immutable expected =
        [
            "title",
            "this is my title",
            "author",
            "john doe"
        ];
        assert(splitUp == expected, splitUp.text);
    }
    {
        enum input = `string without quotes`;
        immutable splitUp = splitWithQuotes(input);
        immutable expected =
        [
            "string",
            "without",
            "quotes",
        ];
        assert(splitUp == expected, splitUp.text);
    }
    {
        enum input = string.init;
        immutable splitUp = splitWithQuotes(input);
        immutable expected = (string[]).init;
        assert(splitUp == expected, splitUp.text);
    }
    {
        enum input = `title "this is \"my\" title" author "john\\" doe`;
        immutable splitUp = splitWithQuotes(input);
        immutable expected =
        [
            "title",
            `this is "my" title`,
            "author",
            `john\`,
            "doe"
        ];
        assert(splitUp == expected, splitUp.text);
    }
    {
        enum input = `title "this is \"my\" title" author "john\\\" doe`;
        immutable splitUp = splitWithQuotes(input);
        immutable expected =
        [
            "title",
            `this is "my" title`,
            "author",
            `john\" doe`
        ];
        assert(splitUp == expected, splitUp.text);
    }
    {
        enum input = `this has "unbalanced quotes`;
        immutable splitUp = splitWithQuotes(input);
        immutable expected =
        [
            "this",
            "has",
            "unbalanced quotes"
        ];
        assert(splitUp == expected, splitUp.text);
    }
    {
        enum input = `""`;
        immutable splitUp = splitWithQuotes(input);
        immutable expected = (string[]).init;
        assert(splitUp == expected, splitUp.text);
    }
    {
        enum input = `"`;
        immutable splitUp = splitWithQuotes(input);
        immutable expected = (string[]).init;
        assert(splitUp == expected, splitUp.text);
    }
    {
        enum input = `"""""""""""`;
        immutable splitUp = splitWithQuotes(input);
        immutable expected = (string[]).init;
        assert(splitUp == expected, splitUp.text);
    }
}


// replaceFromAA
/++
    Replaces space-separated tokens (that begin with a token character) in a
    string with values from a supplied associative array.

    The AA values are of some type of function or delegate returning strings.

    Example:
    ---
    const @safe string delegate()[string] aa =
    [
        "$foo"  : () => "bar",
        "$baz"  : () => "quux"
        "$now"  : () => Clock.currTime.toISOExtString(),
        "$rng"  : () => uniform(0, 100).to!string,
        "$hirr" : () => 10.to!string,
    ];

    immutable line = "first $foo second $baz third $hirr end";
    enum expected = "first bar second quux third 10 end";
    immutable actual = line.replaceFromAA(aa);
    assert((actual == expected), actual);
    ---

    Params:
        tokenCharacter = What character to use to denote tokens, defaults to '`$`'
            but may be any `char`.
        line = String to replace tokens in.
        aa = Associative array of token keys and replacement callable values.

    Returns:
        A new string with occurrences of any passed tokens replaced, or the
        original string as-is if there were no changes made.
 +/
auto replaceFromAA(char tokenCharacter = '$', Fn)
    (const string line,
    const Fn[string] aa)
{
    import std.array : Appender;
    import std.string : indexOf;
    import std.traits : isSomeFunction;

    static if (!isSomeFunction!Fn)
    {
        enum message = "`replaceFromAA` only works with functions and delegates";
        static assert(0, message);
    }

    Appender!(char[]) sink;
    sink.reserve(line.length + 32);  // guesstimate
    size_t previousEnd;

    for (size_t i = 0; i < line.length; ++i)
    {
        if (line[i] == tokenCharacter)
        {
            immutable spacePos = line.indexOf(' ', i);
            immutable end = (spacePos == -1) ? line.length : spacePos;
            immutable key = line[i..end];

            if (const replacement = key in aa)
            {
                sink.put(line[previousEnd..i]);
                sink.put((*replacement)());
                i += key.length;
                previousEnd = i;
            }
        }
    }

    if (previousEnd == 0) return line;

    sink.put(line[previousEnd..$]);
    return sink[].idup;
}

///
unittest
{
    static auto echo(const string what) { return what; }

    immutable hello = "hello";

    @safe string delegate()[string] aa =
    [
        "$foo" : () => hello,
        "$bar" : () => echo("I was one"),
        "$baz" : () => "BAZ",
    ];

    enum line = "I thought what I'd $foo was, I'd pretend $bar of those deaf-$baz";
    enum expected = "I thought what I'd hello was, I'd pretend I was one of those deaf-BAZ";
    immutable actual = line.replaceFromAA(aa);
    assert((actual == expected), actual);
}
