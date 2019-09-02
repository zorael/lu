/++
 +  String manipulation functions, used throughout the program complementing the
 +  standard library, as well as providing dumbed-down and optimised versions
 +  of existing functions therein.
 +
 +  Notable functions are `nom`, which allows for advancing a string past a
 +  supplied substring; and `contains`, which uses an educated approach to
 +  finding substrings in a string.
 +/
module lu.core.string;

import std.range.primitives : ElementEncodingType, ElementType, isOutputRange;
import std.traits : isIntegral, isMutable, isSomeString;
import std.typecons : Flag, No, Yes;

@safe:


// nom
/++
 +  Given some string, finds the supplied separator token in it, returns the
 +  string up to that point, and advances the passed string by ref to after the token.
 +
 +  The naming is in line with standard library functions such as
 +  `std.string.munch`, `std.file.slurp` and others.
 +
 +  Example:
 +  ---
 +  string foobar = "foo bar!";
 +  string foo = foobar.nom(" ");
 +  string bar = foobar.nom("!");
 +
 +  assert((foo == "foo"), foo);
 +  assert((bar == "bar"), bar);
 +  assert(!foobar.length);
 +
 +  enum line = "abc def ghi";
 +  string def = line[4..$].nom(" ");  // now with auto ref
 +  ---
 +
 +  Params:
 +      decode = Whether to use auto-decoding functions, or try to keep to non-
 +          decoding ones (when possible).
 +      line = String to walk and advance.
 +      separator = Token that deliminates what should be returned and to where to advance.
 +      callingFile = Name of the calling source file, used to pass along when
 +          throwing an exception.
 +      callingLine = Line number where in the source file this is called, used
 +          to pass along when throwing an exception.
 +
 +  Returns:
 +      The string `line` from the start up to the separator token. The original
 +      variable is advanced to after the token.
 +
 +  Throws: `object.Exception` if the separator could not be found in the string.
 +/
pragma(inline)
T nom(Flag!"decode" decode = No.decode, T, C)(auto ref T line, const C separator,
    const string callingFile = __FILE__, const size_t callingLine = __LINE__) pure
if (isMutable!T && isSomeString!T && (is(C : T) || is(C : ElementType!T) || is(C : ElementEncodingType!T)))
in
{
    static if (is(C : T))
    {
        import std.format : format;
        assert(separator.length, "Tried to nom with no separator given (at %s:%d)"
            .format(callingFile, callingLine));
    }
}
do
{
    static if (decode || is(T : dstring) || is(T : wstring))
    {
        import std.string : indexOf;
        // dstring and wstring only work with indexOf, not countUntil
        immutable index = line.indexOf(separator);
    }
    else
    {
        // Only do this if we know it's not user text
        import std.algorithm.searching : countUntil;
        import std.string : representation;

        static if (isSomeString!C)
        {
            immutable index = line.representation.countUntil(separator.representation);
        }
        else
        {
            immutable index = line.representation.countUntil(cast(ubyte)separator);
        }
    }

    if (index == -1)
    {
        import std.format : format;
        throw new Exception(`Tried to nom too much: "%s" with "%s"`
            .format(line, separator), callingFile, callingLine);
    }

    static if (isSomeString!C)
    {
        immutable separatorLength = separator.length;
    }
    else
    {
        enum separatorLength = 1;
    }

    static if (__traits(isRef, line))
    {
        scope(exit) line = line[(index+separatorLength)..$];
    }

    return line[0..index];
}

///
unittest
{
    import std.conv : to;

    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom(" :");
        assert(lorem == "Lorem ipsum", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom!(Yes.decode)(" :");
        assert(lorem == "Lorem ipsum", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom(':');
        assert(lorem == "Lorem ipsum ", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom!(Yes.decode)(':');
        assert(lorem == "Lorem ipsum ", lorem);
        assert(line == "sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom(' ');
        assert(lorem == "Lorem", lorem);
        assert(line == "ipsum :sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom!(Yes.decode)(' ');
        assert(lorem == "Lorem", lorem);
        assert(line == "ipsum :sit amet", line);
    }
    /*{
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom("");
        assert(!lorem.length, lorem);
        assert(line == "Lorem ipsum :sit amet", line);
    }*/
    /*{
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom!(Yes.decode)("");
        assert(!lorem.length, lorem);
        assert(line == "Lorem ipsum :sit amet", line);
    }*/
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom("Lorem ipsum");
        assert(!lorem.length, lorem);
        assert(line == " :sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable lorem = line.nom!(Yes.decode)("Lorem ipsum");
        assert(!lorem.length, lorem);
        assert(line == " :sit amet", line);
    }
    {
        string line = "Lorem ipsum :sit amet";
        immutable dchar dspace = ' ';
        immutable lorem = line.nom(dspace);
        assert(lorem == "Lorem", lorem);
        assert(line == "ipsum :sit amet", line);
    }
    {
        dstring dline = "Lorem ipsum :sit amet"d;
        immutable dspace = " "d;
        immutable lorem = dline.nom(dspace);
        assert((lorem == "Lorem"d), lorem.to!string);
        assert((dline == "ipsum :sit amet"d), dline.to!string);
    }
    {
        dstring dline = "Lorem ipsum :sit amet"d;
        immutable wchar wspace = ' ';
        immutable lorem = dline.nom(wspace);
        assert((lorem == "Lorem"d), lorem.to!string);
        assert((dline == "ipsum :sit amet"d), dline.to!string);
    }
    {
        wstring wline = "Lorem ipsum :sit amet"w;
        immutable wchar wspace = ' ';
        immutable lorem = wline.nom(wspace);
        assert((lorem == "Lorem"w), lorem.to!string);
        assert((wline == "ipsum :sit amet"w), wline.to!string);
    }
    {
        wstring wline = "Lorem ipsum :sit amet"w;
        immutable wspace = " "w;
        immutable lorem = wline.nom(wspace);
        assert((lorem == "Lorem"w), lorem.to!string);
        assert((wline == "ipsum :sit amet"w), wline.to!string);
    }
    {
        string user = "foo!bar@asdf.adsf.com";
        user = user.nom('!');
        assert((user == "foo"), user);
    }
    {
        immutable def = "abc def ghi"[4..$].nom(" ");
        assert((def == "def"), def);
    }
}


// nom
/++
 +  Given some string, finds the supplied separator token in it, returns the
 +  string up to that point, and advances the passed string by ref to after the token.
 +
 +  The naming is in line with standard library functions such as
 +  `std.string.munch`, `std.file.slurp` and others.
 +
 +  Overload that takes an extra `Flag!"inherit"` template parameter, to toggle
 +  whether the return value inherits the passed line (and clearing it) upon no
 +  separator match.
 +
 +  Example:
 +  ---
 +  string foobar = "foo bar!";
 +  string foo = foobar.nom(" ");
 +  string bar = foobar.nom!(Yes.inherit)("?");
 +
 +  assert((foo == "foo"), foo);
 +  assert((bar == "bar!"), bar);
 +  assert(!foobar.length);
 +
 +  string slice = "snarfl";
 +  string verb = slice.nom!(Yes.inherit)(" ");
 +
 +  assert((verb == "snarfl"), verb);
 +  assert(!slice.length, slice);
 +  ---
 +
 +  Params:
 +      inherit = Whether or not to have the returned string inherit (and clear)
 +          the passed line by ref.
 +      decode = Whether to use auto-decoding functions, or try to keep to non-
 +          decoding ones (when possible).
 +      line = String to walk and advance.
 +      separator = Token that deliminates what should be returned and to where to advance.
 +      callingFile = Name of the calling source file, used to pass along when
 +          throwing an exception.
 +      callingLine = Line number where in the source file this is called, used
 +          to pass along when throwing an exception.
 +
 +  Returns:
 +      The string `line` from the start up to the separator token, if it exists.
 +      If so, the original variable is advanced to after the token.
 +      If it doesn't exist, the string in `line` is inherited into the return
 +      value and returned, while the `line` symbol itself is cleared.
 +/
pragma(inline)
T nom(Flag!"inherit" inherit, Flag!"decode" decode = No.decode, T, C)
    (ref T line, const C separator, const string callingFile = __FILE__,
    const size_t callingLine = __LINE__) pure
if (isMutable!T && isSomeString!T && (is(C : T) || is(C : ElementType!T) || is(C : ElementEncodingType!T)))
in
{
    static if (is(C : T))
    {
        import std.format : format;
        assert(separator.length, "Tried to nom with no separator given (at %s:%d)"
            .format(callingFile, callingLine));
    }
}
do
{
    static if (inherit)
    {
        if (line.contains!decode(separator))
        {
            // Separator exists, no inheriting will take place, call original nom
            return line.nom!decode(separator, callingFile, callingLine);
        }
        else
        {
            // No separator match; inherit string and clear the original
            scope(exit) line = string.init;
            return line;
        }
    }
    else
    {
        // Not inheriting due to argument No.inherit, so just pass onto original nom
        return line.nom!decode(separator, callingFile, callingLine);
    }
}

///
unittest
{
    {
        string line = "Lorem ipsum";
        immutable head = line.nom(" ");
        assert((head == "Lorem"), head);
        assert((line == "ipsum"), line);
    }
    {
        string line = "Lorem";
        immutable head = line.nom!(Yes.inherit)(" ");
        assert((head == "Lorem"), head);
        assert(!line.length, line);
    }
    {
        string slice = "verb";
        string verb;

        if (slice.contains(' '))
        {
            verb = slice.nom(' ');
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
        immutable verb = slice.nom!(Yes.inherit)(' ');
        assert((verb == "verb"), verb);
        assert(!slice.length, slice);
    }
    {
        string url = "https://google.com/index.html#fragment-identifier";
        url = url.nom!(Yes.inherit)('#');
        assert((url == "https://google.com/index.html"), url);
    }
    {
        string url = "https://google.com/index.html";
        url = url.nom!(Yes.inherit)('#');
        assert((url == "https://google.com/index.html"), url);
    }
}


// plurality
/++
 +  Selects the correct singular or plural form of a word depending on the
 +  numerical count of it.
 +
 +  Example:
 +  ---
 +  string one = 1.plurality("one", "two");
 +  string two = 2.plurality("one", "two");
 +  string many = (-2).plurality("one", "many");
 +  string many0 = 0.plurality("one", "many");
 +
 +  assert((one == "one"), one);
 +  assert((two == "two"), two);
 +  assert((many == "many"), many);
 +  assert((many0 == "many"), many0);
 +  ---
 +
 +  Params:
 +      num = Numerical count of the noun.
 +      singular = The noun in singular form.
 +      plural = The noun in plural form.
 +
 +  Returns:
 +      The singular string if num is `1` or `-1`, otherwise the plural string.
 +/
pragma(inline)
T plurality(Num, T)(const Num num, const T singular, const T plural) pure nothrow @nogc
if (isIntegral!Num && isSomeString!T)
{
    return ((num == 1) || (num == -1)) ? singular : plural;
}

///
unittest
{
    assert(10.plurality("one","many") == "many");
    assert(1.plurality("one", "many") == "one");
    assert((-1).plurality("one", "many") == "one");
    assert(0.plurality("one", "many") == "many");
}


// unenclosed
/++
 +  Removes paired preceding and trailing tokens around a string line.
 +
 +  You should not need to use this directly; rather see `unquoted` and `unsinglequoted`.
 +
 +  Params:
 +      token = Token character to strip away.
 +      line = String line to remove any enclosing tokens from.
 +
 +  Returns:
 +      A slice of the passed string line without enclosing tokens.
 +/
private T unenclosed(char token = '"', T)(const T line) pure nothrow @nogc
if (isSomeString!T)
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
 +  Removes paired preceding and trailing double quotes, unquoting a word.
 +
 +  Does not decode the string and may thus give weird results on weird inputs.
 +
 +  Example:
 +  ---
 +  string quoted = `"This is a quote"`;
 +  string unquotedLine = quoted.unquoted;
 +  assert((unquotedLine == "This is a quote"), unquotedLine);
 +  ---
 +
 +  Params:
 +      line = The (potentially) quoted string.
 +
 +  Returns:
 +      A slice of the `line` argument that excludes the quotes.
 +/
pragma(inline)
T unquoted(T)(const T line) pure nothrow @nogc
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
 +  Removes paired preceding and trailing single quotes around a line.
 +
 +  Does not decode the string and may thus give weird results on weird inputs.
 +
 +  Example:
 +  ---
 +  string quoted = `'This is single-quoted'`;
 +  string unquotedLine = quoted.unsinglequoted;
 +  assert((unquotedLine == "This is single-quoted"), unquotedLine);
 +  ---
 +
 +  Params:
 +      line = The (potentially) single-quoted string.
 +
 +  Returns:
 +      A slice of the `line` argument that excludes the single-quotes.
 +/
pragma(inline)
T unsinglequoted(T)(const T line) pure nothrow @nogc
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


// beginsWith
/++
 +  A cheaper variant of `std.algorithm.searching.startsWith`, since this is
 +  such a hotspot.
 +
 +  Merely slices; does not decode the string and may thus give weird results on
 +  weird inputs.
 +
 +  Example:
 +  ---
 +  assert("Lorem ipsum sit amet".beginsWith("Lorem ip"));
 +  assert(!"Lorem ipsum sit amet".beginsWith("ipsum sit amet"));
 +  ---
 +
 +  Params:
 +      haystack = Original line to examine.
 +      needle = Snippet of text to check if `haystack` begins with.
 +
 +  Returns:
 +      `true` if `haystack` begins with `needle`, `false` if not.
 +/
bool beginsWith(T)(const T haystack, const T needle) pure nothrow @nogc
if (isSomeString!T)
{
    if ((needle.length > haystack.length) || !haystack.length)
    {
        return false;
    }

    if (needle.length && (haystack[0] != needle[0])) return false;

    return (haystack[0..needle.length] == needle);
}

///
unittest
{
    assert("Lorem ipsum sit amet".beginsWith("Lorem ip"));
    assert(!"Lorem ipsum sit amet".beginsWith("ipsum sit amet"));
    assert("Lorem ipsum sit amet".beginsWith(""));
}


// beginsWith
/++
 +  A cheaper variant of `std.algorithm.searching.startsWith`, since this is
 +  such a hotspot.
 +
 +  Merely slices; does not decode the string and may thus give weird results on
 +  weird inputs.
 +
 +  Overload that takes a `char` or `ubyte` as beginning character, instead of
 +  a full string like the primary overload.
 +
 +  Example:
 +  ---
 +  assert("Lorem ipsum sit amet".beginsWith('L'));
 +  assert(!"Lorem ipsum sit amet".beginsWith('o'));
 +  ---
 +
 +  Params:
 +      haystack = Original line to examine.
 +      needle = The `char` (or technically `ubyte`) to check if `haystack` begins with.
 +
 +  Returns:
 +      `true` if `haystack` begins with `needle`, `false` if not.
 +/
bool beginsWith(T)(const T haystack, const ubyte needle) pure nothrow @nogc
if (isSomeString!T)
{
    if (!haystack.length) return false;

    return (haystack[0] == needle);
}

///
unittest
{
    assert(":Lorem ipsum".beginsWith(':'));
    assert(!":Lorem ipsum".beginsWith(';'));
}


// beginsWithOneOf
/++
 +  Checks whether or not the first letter of a string begins with any of the
 +  passed string of characters.
 +
 +  Wraps `contains`.
 +
 +  Merely slices; does not decode the string and may thus give weird results on
 +  weird inputs.
 +
 +  Params:
 +      haystack = String line to check the beginning of.
 +      needles = String of characters to test and see whether or not `haystack`
 +          begins with any of them.
 +
 +  Returns:
 +      `true` if the first character of `haystack` is also in `characters`,
 +      `false` if not.
 +/
pragma(inline)
bool beginsWithOneOf(T)(const T haystack, const T needles) pure nothrow @nogc
if (isSomeString!T)
{
    version(Windows)
    {
        // Windows workaround for memchr segfault
        // See https://forum.dlang.org/post/qgzznkhvvozadnagzudu@forum.dlang.org
        if ((needles.ptr is null) || !needles.length) return true;
    }
    else
    {
        // All strings begin with an empty string
        if (!needles.length) return true;
    }

    // An empty line begins with nothing
    if (!haystack.length) return false;

    return needles.contains(haystack[0]);
}

///
unittest
{
    assert("#channel".beginsWithOneOf("#%+"));
    assert(!"#channel".beginsWithOneOf("~%+"));
    assert("".beginsWithOneOf(""));
    assert("abc".beginsWithOneOf(string.init));
    assert(!"".beginsWithOneOf("abc"));
}


// beginsWithOneOf
/++
 +  Checks whether or not the first letter of a string begins with any of the
 +  passed string of characters.
 +
 +  Overload that takes a single `char` or `ubyte` as "string" to identify the
 +  "beginning" of, which in this case translates to the `char`/`ubyte` itself.
 +
 +  Wraps `contains`.
 +
 +  Merely slices; does not decode the string and may thus give weird results on
 +  weird inputs.
 +
 +  Params:
 +      haystraw = Single character to evaluate whether or not it exists in `needles`.
 +      needles = String of characters to test and see whether or not `haystraw`
 +          equals any of them.
 +
 +  Returns:
 +      `true` if the `haystraw` is in `needles`, `false` if not.
 +/
pragma(inline)
bool beginsWithOneOf(T)(const ubyte haystraw, const T needles) pure nothrow @nogc
if (isSomeString!T)
{
    // All strings begin with an empty string, even if we're only looking at one character
    if (!needles.length) return true;

    return needles.contains(haystraw);
}

///
unittest
{
    assert('#'.beginsWithOneOf("#%+"));
    assert(!'#'.beginsWithOneOf("~%+"));
    assert('a'.beginsWithOneOf(string.init));
    assert(!'d'.beginsWithOneOf("abc"));
}


// stripSeparatedPrefix
/++
 +  Strips a prefix word from a string, optionally also stripping away some
 +  non-word characters (`:?! `).
 +
 +  This is to make a helper for stripping away bot prefixes, where such may be
 +  "`kameloso:`".
 +
 +  Example:
 +  ---
 +  string prefixed = "kameloso: sudo MODE +o #channel :user";
 +  string command = prefixed.stripSeparatedPrefix("kameloso");
 +  assert((command == "sudo MODE +o #channel :user"), command);
 +  ---
 +
 +  Params:
 +      demandSeparatingChars = Makes it a necessity that `line` is followed
 +          by one of the prefix letters `:?! `. If it isn't, the `line` string
 +          will be returned as is.
 +      line = String line prefixed with `prefix`, potentially including separating characters.
 +      prefix = Prefix to strip.
 +
 +  Returns:
 +      The passed line with the `prefix` sliced away.
 +/
string stripSeparatedPrefix(Flag!"demandSeparatingChars" demandSeparatingChars = Yes.demandSeparatingChars)
    (const string line, const string prefix) pure
in (prefix.length, "Tried to strip separated prefix but no prefix was given")
do
{
    import std.algorithm.searching : skipOver, startsWith;
    import std.meta : AliasSeq;

    alias separatingChars = AliasSeq!(':', ' ', '!', '?');

    string slice = line.strippedLeft;  // mutable

    // the onus is on the caller that slice begins with prefix, else this will throw
    slice.nom!(Yes.decode)(prefix);

    static if (demandSeparatingChars)
    {
        // Return the whole line, a non-match, if there are no separating characters
        // (at least one of the chars in separatingChars
        if (!slice.startsWith(separatingChars)) return line;
        slice = slice[1..$];
    }

    bool strippedSomething;

    do
    {
        strippedSomething = slice.skipOver(separatingChars);
    }
    while (strippedSomething);

    return slice;
}

///
unittest
{
    immutable lorem = "say: lorem ipsum".stripSeparatedPrefix("say");
    assert((lorem == "lorem ipsum"), lorem);

    immutable notehello = "note!!!! zorael hello".stripSeparatedPrefix("note");
    assert((notehello == "zorael hello"), notehello);

    immutable sudoquit = "sudo quit :derp".stripSeparatedPrefix("sudo");
    assert((sudoquit == "quit :derp"), sudoquit);

    /*immutable eightball = "8ball predicate?".stripSeparatedPrefix("");
    assert((eightball == "8ball predicate?"), eightball);*/

    immutable isnotabot = "kamelosois a bot".stripSeparatedPrefix("kameloso");
    assert((isnotabot == "kamelosois a bot"), isnotabot);

    immutable isabot = "kamelosois a bot".stripSeparatedPrefix!(No.demandSeparatingChars)("kameloso");
    assert((isabot == "is a bot"), isabot);
}


// stripSuffix
/++
 +  Strips the supplied string from the end of a string.
 +
 +  Example:
 +  ---
 +  string suffixed = "Kameloso";
 +  string stripped = suffixed.stripSuffix("oso");
 +  assert((stripped == "Kamel"), stripped);
 +  ---
 +
 +  Params:
 +      fullStrip = Whether or not to allow for the stripping to clear the entire string.
 +      line = Original line to strip the suffix from.
 +      suffix = Suffix string to strip.
 +
 +  Returns:
 +      `line` with `suffix` sliced off.
 +/
string stripSuffix(Flag!"allowFullStrip" fullStrip = No.allowFullStrip)
    (const string line, const string suffix) pure nothrow @nogc
{
    static if (fullStrip)
    {
        if (line.length < suffix.length) return line;
    }
    else
    {
        if (line.length <= suffix.length) return line;
    }

    return (line[($-suffix.length)..$] == suffix) ? line[0..($-suffix.length)] : line;
}

///
unittest
{
    immutable line = "harblsnarbl";
    assert(line.stripSuffix("snarbl") == "harbl");
    assert(line.stripSuffix("") == "harblsnarbl");
    assert(line.stripSuffix("INVALID") == "harblsnarbl");
    assert(!line.stripSuffix!(Yes.allowFullStrip)("harblsnarbl").length);
    assert(line.stripSuffix("harblsnarbl") == "harblsnarbl");
}


// sharedDomains
/++
 +  Calculates how many dot-separated suffixes two strings share.
 +
 +  This is useful to see to what extent two addresses are similar.
 +
 +  Example:
 +  ---
 +  int numDomains = sharedDomains("irc.freenode.net", "leguin.freenode.net");
 +  assert(numDomains == 2);  // freenode.net
 +  ---
 +
 +  Params:
 +      rawOne = First domain string.
 +      rawOther = Second domain string.
 +
 +  Returns:
 +      The number of domains the two strings share.
 +
 +  TODO:
 +      Support partial globs.
 +/
auto sharedDomains(const string rawOne, const string rawOther) pure nothrow
{
    uint dots;
    bool doubleDots;

    // If both strings are the same, act as if there's an extra dot.
    // That gives (.)rizon.net and (.)rizon.net two suffixes.
    if (rawOne.length && (rawOne == rawOther)) ++dots;

    immutable one = (rawOne != rawOther) ? '.' ~ rawOne : rawOne;
    immutable other = (rawOne != rawOther) ? '.' ~ rawOther : rawOther;

    foreach (immutable i; 0..one.length)
    {
        if (i == other.length)
        {
            // The first string was longer than the second
            break;
        }

        if (one[$-i-1] != other[$-i-1])
        {
            // There was a character mismatch
            break;
        }

        if (one[$-i-1] == '.')
        {
            if (!doubleDots)
            {
                ++dots;
                doubleDots = true;
            }
        }
        else
        {
            doubleDots = false;
        }
    }

    return dots;
}

///
unittest
{
    import std.conv : text;

    immutable n1 = sharedDomains("irc.freenode.net", "help.freenode.net");
    assert((n1 == 2), n1.text);

    immutable n2 = sharedDomains("irc.rizon.net", "services.rizon.net");
    assert((n2 == 2), n2.text);

    immutable n3 = sharedDomains("www.google.com", "www.yahoo.com");
    assert((n3 == 1), n3.text);

    immutable n4 = sharedDomains("www.google.se", "www.google.co.uk");
    assert((n4 == 0), n4.text);

    /*immutable n5 = sharedDomains("", string.init);
    assert((n5 == 0), n5.text);*/

    immutable n6 = sharedDomains("irc.rizon.net", "rizon.net");
    assert((n6 == 2), n6.text);

    immutable n7 = sharedDomains("rizon.net", "rizon.net");
    assert((n7 == 2), n7.text);

    immutable n8 = sharedDomains("net", "net");
    assert((n8 == 1), n8.text);

    immutable n9 = sharedDomains("forum.dlang.org", "...");
    assert((n9 == 0), n8.text);
}


// tabs
/++
 +  Returns *spaces* equal to that of `num` tabs (\t).
 +
 +  Example:
 +  ---
 +  string indentation = 2.tabs;
 +  assert((indentation == "        "), `"` ~  indentation ~ `"`);
 +  string smallIndent = 1.tabs!2;
 +  assert((smallIndent == "  "), `"` ~  smallIndent ~ `"`);
 +  ---
 +
 +  Params:
 +      spaces = How many spaces make up a tab.
 +      num = How many tabs we want.
 +
 +  Returns:
 +      Whitespace equalling (`num` * `spaces`) spaces.
 +/
auto tabs(uint spaces = 4)(const int num) pure nothrow @nogc
in ((num >= 0), "Negative number of tabs")
do
{
    import std.range : repeat, takeExactly;
    import std.algorithm.iteration : joiner;
    import std.array : array;


    enum char[spaces] tab = ' '.repeat.takeExactly(spaces).array;

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

    Appender!string sink;
    sink.formattedWrite("%sHello world", 2.tabs!2);
    assert((sink.data == "    Hello world"), sink.data);
}


// indented
/++
 +  Indents a string, line by line, with the supplied number of tabs.
 +
 +  Tab length is hardcoded to the defaults in `tabs` for now.
 +
 +  Params:
 +      numTabs = Amount of tabs to indent with, default 1.
 +      string_ = String to indent the lines of.
 +      sink = Output range to fill with the indented lines.
 +/
void indented(uint numTabs = 1, Sink)(const string string_, auto ref Sink sink)
if (isOutputRange!(Sink, char[]))
{
    import std.algorithm.iteration : splitter;

    enum indent = numTabs.tabs;
    uint n;

    foreach (immutable l; string_.splitter("\n"))
    {
        if (n++ > 0) sink.put("\n");

        if (!l.length)
        {
            sink.put("\n");
            continue;
        }

        import std.format : formattedWrite;
        sink.formattedWrite("%s%s", indent, l);
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

    string_.indented!1(sink);
    assert((sink.data ==
"    Lorem ipsum
    sit amet
    I don't remember
    any more offhand
    so shrug"), '\n' ~ sink.data);

    sink.clear();
    string_.indented!2(sink);
    assert((sink.data ==
"        Lorem ipsum
        sit amet
        I don't remember
        any more offhand
        so shrug"), '\n' ~ sink.data);

    sink.clear();
    string_.indented!0(sink);
    assert((sink.data ==
"Lorem ipsum
sit amet
I don't remember
any more offhand
so shrug"), '\n' ~ sink.data);
}


// indent
/++
 +  Indents a string, line by line, with the supplied number of tabs.
 +  Returns a string.
 +
 +  Merely wraps the output range overload, using an `std.array.Appender` as sink.
 +
 +  Tab length is hardcoded to the defaults in `tabs` for now.
 +
 +  Params:
 +      numTabs = Amount of tabs to indent with, default 1.
 +      string_ = String to indent the lines of.
 +
 +  Returns:
 +      A string with all the lines of the original string indented.
 +/
string indent(uint numTabs = 1)(const string string_)
{
    import std.array : Appender;

    Appender!string sink;
    sink.reserve(string_.length + 4*numTabs);

    string_.indented!numTabs(sink);
    return sink.data;
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

    immutable indentedOne = string_.indent!1;
    assert((indentedOne ==
"    Lorem ipsum
    sit amet
    I don't remember
    any more offhand
    so shrug"), '\n' ~ indentedOne);

    immutable indentedTwo = string_.indent!2;
    assert((indentedTwo ==
"        Lorem ipsum
        sit amet
        I don't remember
        any more offhand
        so shrug"), '\n' ~ indentedTwo);

    immutable indentedZero = string_.indent!0;
    assert((indentedZero ==
"Lorem ipsum
sit amet
I don't remember
any more offhand
so shrug"), '\n' ~ indentedTwo);
}


// contains
/++
 +  Checks a string to see if it contains a given substring or character.
 +
 +  Merely slices; this is not UTF-8 safe. It is naive in how it thinks a string
 +  always correspond to one set of codepoints and one set only.
 +
 +  Example:
 +  ---
 +  assert("Lorem ipsum".contains("Lorem"));
 +  assert(!"Lorem ipsum".contains('l'));
 +  assert("Lorem ipsum".contains!(Yes.decode)(" "));
 +  ---
 +
 +  Params:
 +      decode = Whether to use auto-decoding functions, or try to keep to non-
 +          decoding ones (when possible).
 +      haystack = String to search for `needle`.
 +      needle = Substring to search `haystack` for.
 +
 +  Returns:
 +      Whether or not the passed `haystack` string contained the passed `needle`
 +      substring or token.
 +/
bool contains(Flag!"decode" decode = No.decode, T, C)(const T haystack, const C needle) pure
if (isSomeString!T && (isSomeString!C || (is(C : T) || is(C : ElementType!T) ||
    is(C : ElementEncodingType!T))))
{
    static if (is(C : T)) if (haystack == needle) return true;

    static if (decode || is(T : dstring) || is(T : wstring) ||
        is(C : ElementType!T) || is(C : ElementEncodingType!T))
    {
        import std.string : indexOf;
        // dstring and wstring only work with indexOf, not countUntil
        return haystack.indexOf(needle) != -1;
    }
    else
    {
        // Only do this if we know it's not user text
        import std.algorithm.searching : canFind;
        import std.string : representation;

        static if (isSomeString!C)
        {
            return haystack.representation.canFind(needle.representation);
        }
        else
        {
            return haystack.representation.canFind(cast(ubyte)needle);
        }
    }
}

///
unittest
{
    assert("Lorem ipsum sit amet".contains("sit"));
    assert("".contains(""));
    assert(!"Lorem ipsum".contains("sit amet"));
    assert("Lorem ipsum".contains(' '));
    assert(!"Lorem ipsum".contains('!'));
    assert("Lorem ipsum"d.contains("m"d));
    assert("Lorem ipsum".contains(['p', 's', 'u', 'm' ]));
    assert([ 'L', 'o', 'r', 'e', 'm' ].contains([ 'L' ]));
    assert([ 'L', 'o', 'r', 'e', 'm' ].contains("Lor"));
    assert([ 'L', 'o', 'r', 'e', 'm' ].contains(cast(char[])[]));
}

/// Legacy alias to `contains`.
alias has = contains;

///
unittest
{
    assert("Lorem ipsum sit amet".has("sit"));
}


// strippedRight
/++
 +  Returns a slice of the passed string with any trailing whitespace and/or
 +  linebreaks sliced off.
 +
 +  Duplicates `std.string.stripRight`, which we can no longer trust not to
 +  assert on unexpected input.
 +
 +  Params:
 +      line = Line to strip the right side of.
 +
 +  Returns:
 +      The passed line without any trailing whitespace or linebreaks.
 +/
string strippedRight(const string line) pure nothrow @nogc
{
    if (!line.length) return line;

    return strippedRight(line, " \n\r\t");
}

///
unittest
{
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
 +  Returns a slice of the passed string with any trailing passed characters.
 +  Implementation capable of handling both individual characters and string of
 +  tokens to strip.
 +
 +  Duplicates `std.string.stripRight`, which we can no longer trust not to
 +  assert on unexpected input.
 +
 +  Params:
 +      line = Line to strip the right side of.
 +      chaff = Character or string of characters to strip away.
 +
 +  Returns:
 +      The passed line without any trailing passed characters.
 +/
T strippedRight(T, C)(T line, C chaff)
if (isSomeString!T && (is(C : T) || is(C : ElementType!T) || is(C : ElementEncodingType!T)))
{
    import std.traits : isSomeString;
    import std.range : hasLength;

    if (!line.length) return line;

    size_t pos = line.length;

    loop:
    while (pos > 0)
    {
        static if (isSomeString!C || hasLength!C)
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
 +  Returns a slice of the passed string with any preceding whitespace and/or
 +  linebreaks sliced off.
 +
 +  Duplicates `std.string.stripLeft`, which we can no longer trust not to
 +  assert on unexpected input.
 +
 +  Params:
 +      line = Line to strip the left side of.
 +
 +  Returns:
 +      The passed line without any preceding whitespace or linebreaks.
 +/
string strippedLeft(const string line) pure nothrow @nogc
{
    if (!line.length) return line;

    return strippedLeft(line, " \n\r\t");
}

///
unittest
{
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
 +  Returns a slice of the passed string with any preceding passed characters
 +  sliced off. Implementation capable of handling both individual characters
 +  and strings of tokens to strip.
 +
 +  Duplicates `std.string.stripLeft`, which we can no longer trust not to
 +  assert on unexpected input.
 +
 +  Params:
 +      line = Line to strip the left side of.
 +      chaff = Character or string of characters to strip away.
 +
 +  Returns:
 +      The passed line without any preceding passed characters.
 +/
T strippedLeft(T, C)(T line, C chaff)
if (isSomeString!T && (is(C : T) || is(C : ElementType!T) || is(C : ElementEncodingType!T)))
{
    import std.traits : isSomeString;
    import std.range : hasLength;

    if (!line.length) return line;

    size_t pos;

    loop:
    while (pos < line.length)
    {
        static if (isSomeString!C || hasLength!C)
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
 +  Returns a slice of the passed string with any preceding or trailing
 +  whitespace or linebreaks sliced off.
 +
 +  It merely calls both `strippedLeft` and `strippedRight`. As such it
 +  duplicates `std.string.strip`, which we can no longer trust not to assert
 +  on unexpected input.
 +
 +  Params:
 +      line = Line to strip both the right and left side of.
 +
 +  Returns:
 +      The passed line, stripped of surrounding whitespace.
 +/
T stripped(T)(T line)
{
    return line.strippedLeft.strippedRight;
}

///
unittest
{
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
 +  Returns a slice of the passed string with any preceding or trailing
 +  passed characters sliced off. Implementation capable of handling both
 +  individual characters and strings of tokens to strip.
 +
 +  It merely calls both `strippedLeft` and `strippedRight`. As such it
 +  duplicates `std.string.strip`, which we can no longer trust not to assert
 +  on unexpected input.
 +
 +  Params:
 +      line = Line to strip both the right and left side of.
 +      chaff = Character or string of characters to strip away.
 +
 +  Returns:
 +      The passed line, stripped of surrounding passed characters.
 +/
T stripped(T, C)(T line, C chaff)
if (isSomeString!T && (is(C : T) || is(C : ElementType!T) || is(C : ElementEncodingType!T)))
{
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
 +  Base64-encodes a string.
 +
 +  Merely wraps `std.base64.Base64.encode` and `std.string.representation`
 +  into one function that will work with strings.
 +
 +  Params:
 +      line = String line to encode.
 +
 +  Returns:
 +      An encoded Base64 string.
 +
 +  See_Also:
 +      - https://en.wikipedia.org/wiki/Base64
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
 +  Base64-decodes a string.
 +
 +  Merely wraps `std.base64.Base64.decode` and `std.string.representation`
 +  into one function that will work with strings.
 +
 +  Params:
 +      encoded = Encoded string to decode.
 +
 +  Returns:
 +      A decoded normal string.
 +
 +  See_Also:
 +      - https://en.wikipedia.org/wiki/Base64
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


// splitOnWord
/++
 +  Splits a string with on word boundary by a supplied separator, into one or
 +  more lines not longer than the passed maximum length.
 +
 +  If a line cannot be split due to the line being too short or the separator
 +  not occurring in the text, it is added to the returned array as-is and no
 +  more splitting is done.
 +
 +  Example:
 +  ---
 +  string line = "I am a fish in a sort of long sentence~";
 +  enum maxLineLength = 20;
 +  auto splitLines = line.splitOnWord(' ', maxLineLength);
 +
 +  assert(splitLines[0] == "I am a fish in a");
 +  assert(splitLines[1] == "sort of a long");
 +  assert(splitLines[2] == "sentence~");
 +  ---
 +
 +  Params:
 +      line = String line to split.
 +      separator = Separator character with which to split the `line`.
 +      maxLength = Maximum length of the separated lines.
 +
 +  Returns:
 +      A `string[]` array with lines split out of the passed `line`.
 +/
T[] splitOnWord(T, C)(const T line, const C separator, const size_t maxLength)
if (isSomeString!T && (is(C : ElementType!T) || is(C : ElementEncodingType!T)))
in
{
    static if (is(C : T))
    {
        assert(separator.length, "Tried to split on word but no word was given");
    }
}
do
{
    string[] lines;

    if (!line.length) return lines;

    string slice = line;
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
        const splitLines = rawLine.splitOnWord(' ', maxLength);
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
        const splitLines = rawLine.splitOnWord(' ', maxLength);
        assert((splitLines.length == 1), splitLines.length.text);
        assert(splitLines[0] == rawLine);
    }
}


// escapeControlCharacters
/++
 +  Replaces the control characters '\n', '\t', '\r' and '\0' with escaped
 +  "\\n", "\\t", "\\r" and "\\0".
 +
 +  Overload that takes an output range sink to save the output into.
 +
 +  If `Yes.remove` is passed, instead exclude the characters from the output.
 +
 +  Params:
 +      remove = Whether or not to remove said characters and not replace them
 +          with escaped variants.
 +      sink = Output range sink to store the output into.
 +      line = String line to escape characters in.
 +/
void escapeControlCharacters(Flag!"remove" remove = No.remove, Sink)
    (auto ref Sink sink, const string line)
if (isOutputRange!(Sink, char[]))
{
    import std.string : representation;

    foreach (immutable c; line.representation)
    {
        switch (c)
        {
        case '\n':
            static if (!remove) sink.put("\\n");
            break;

        case '\t':
            static if (!remove) sink.put("\\t");
            break;

        case '\r':
            static if (!remove) sink.put("\\r");
            break;

        case '\0':
            static if (!remove) sink.put("\\0");
            break;

        default:
            sink.put(c);
            break;
        }
    }
}

///
unittest
{
    import std.array : Appender;

    Appender!(char[]) sink;

    {
        immutable line = "abc\ndef";
        immutable expected = "abc\\ndef";
        escapeControlCharacters(sink, line);
        assert((sink.data == expected), sink.data);
        sink.clear();
    }
    {
        immutable line = "\n\t\r\0";
        immutable expected = "\\n\\t\\r\\0";
        escapeControlCharacters(sink, line);
        assert((sink.data == expected), sink.data);
        sink.clear();
    }
    {
        immutable line = "";
        immutable expected = "";
        escapeControlCharacters(sink, line);
        assert((sink.data == expected), sink.data);
        sink.clear();
    }
    {
        immutable line = "nothing to escape";
        immutable expected = "nothing to escape";
        escapeControlCharacters(sink, line);
        assert((sink.data == expected), sink.data);
        sink.clear();
    }

    {
        immutable line = "abc\ndef";
        immutable expected = "abcdef";
        escapeControlCharacters!(Yes.remove)(sink, line);
        assert((sink.data == expected), sink.data);
        sink.clear();
    }
    {
        immutable line = "\n\t\r\0";
        immutable expected = "";
        escapeControlCharacters!(Yes.remove)(sink, line);
        assert((sink.data == expected), sink.data);
        sink.clear();
    }
    {
        immutable line = "";
        immutable expected = "";
        escapeControlCharacters!(Yes.remove)(sink, line);
        assert((sink.data == expected), sink.data);
        sink.clear();
    }
    {
        immutable line = "nothing to escape";
        immutable expected = "nothing to escape";
        escapeControlCharacters!(Yes.remove)(sink, line);
        assert((sink.data == expected), sink.data);
        //sink.clear();
    }
}


// escapeControlCharacters
/++
 +  Replaces the control characters '\n', '\t', '\r' and '\0' with escaped
 +  "\\n", "\\t", "\\r" and "\\0".
 +
 +  Overload that doesn't take an output range and just constructs its own string.
 +
 +  If `Yes.remove` is passed, instead exclude the characters from the output.
 +
 +  Params:
 +      remove = Whether or not to remove said characters and not replace them
 +          with escaped variants.
 +      line = String line to escape characters in.
 +
 +  Returns:
 +      A new string with no such control characters, either due to replacements
 +      or due to removal.
 +/
string escapeControlCharacters(Flag!"remove" remove = No.remove)(const string line)
{
    import std.array : Appender;

    Appender!string sink;
    sink.reserve(line.length + 8);  // Just in case

    escapeControlCharacters!remove(sink, line);
    return sink.data;
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
    }
    {
        immutable line = "nothing to escape";
        immutable expected = "nothing to escape";
        immutable actual = escapeControlCharacters(line);
        assert((actual == expected), actual);
    }

    {
        immutable line = "abc\ndef";
        immutable expected = "abcdef";
        immutable actual = escapeControlCharacters!(Yes.remove)(line);
        assert((actual == expected), actual);
    }
    {
        immutable line = "\n\t\r\0";
        immutable expected = "";
        immutable actual = escapeControlCharacters!(Yes.remove)(line);
        assert((actual == expected), actual);
    }
    {
        immutable line = "";
        immutable expected = "";
        immutable actual = escapeControlCharacters!(Yes.remove)(line);
        assert((actual == expected), actual);
    }
    {
        immutable line = "nothing to escape";
        immutable expected = "nothing to escape";
        immutable actual = escapeControlCharacters!(Yes.remove)(line);
        assert((actual == expected), actual);
    }
}
