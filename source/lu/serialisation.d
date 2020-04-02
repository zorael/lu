/++
 +  Various functions related to serialising structs into .ini file-like files.
 +
 +  Example:
 +  ---
 +  struct FooSettings
 +  {
 +      string fooasdf;
 +      string bar;
 +      string bazzzzzzz;
 +      @Quoted flerrp;
 +      double pi;
 +  }
 +
 +  FooSettings f;
 +
 +  f.fooasdf = "foo";
 +  f.bar = "bar";
 +  f.bazzzzzzz = "baz";
 +  f.flerrp = "hirr steff  ";
 +  f.pi = 3.14159;
 +
 +  enum fooSerialised =
 + `[Foo]
 +  fooasdf foo
 +  bar bar
 +  bazzzzzzz baz
 +  flerrp "hirr steff  "
 +  pi 3.14159
 +  `
 +
 +  enum fooJustified =
 +  `[Foo]
 +  fooasdf                 foo
 +  bar                     bar
 +  bazzzzzzz               baz
 +  flerrp                  "hirr steff  "
 +  pi                      3.14159
 +  `;
 +
 +  Appender!string sink;
 +
 +  sink.serialise(f);
 +  assert(sink.data.justifiedConfigurationText == fooJustified);
 +
 +  FooSettings mirror;
 +  deserialise(fooSerialised, mirror);
 +  assert(mirror == f);
 +
 +  FooSettings mirror2;
 +  deserialise(fooJustified, mirror2);
 +  assert(mirror2 == mirror);
 +  ---
 +/
module lu.serialisation;

private:

import lu.traits : isStruct;
import std.meta : allSatisfy;
import std.range.primitives : isOutputRange;
import std.typecons : Flag, No, Yes;

public:

@safe:


// serialise
/++
 +  Convenience method to call `serialise` on several objects.
 +
 +  Example:
 +  ---
 +  Appender!string sink;
 +  IRCClient client;
 +  IRCServer server;
 +  sink.serialise(client, server);
 +  assert(!sink.data.empty);
 +  ---
 +
 +  Params:
 +      sink = Reference output range to write the serialised objects to (in
 +          their .ini file-like format).
 +      things = Variadic list of objects to serialise.
 +/
void serialise(Sink, Things...)(ref Sink sink, Things things)
if ((Things.length > 1) && isOutputRange!(Sink, char[]))
{
    foreach (const thing; things)
    {
        sink.serialise(thing);
    }
}


// serialise
/++
 +  Serialises the fields of an object into an .ini file-like format.
 +
 +  It only serialises fields not annotated with `lu.uda.Unconfigurable`,
 +  and it doesn't recurse into other structs or classes.
 +
 +  Example:
 +  ---
 +  Appender!string sink;
 +  IRCClient client;
 +
 +  sink.serialise(client);
 +  assert(!sink.data.empty);
 +  ---
 +
 +  Params:
 +      sink = Reference output range to write to, usually an `std.array.Appender!string`.
 +      thing = Object to serialise.
 +/
void serialise(Sink, QualThing)(ref Sink sink, QualThing thing)
if (isOutputRange!(Sink, char[]))
{
    import lu.string : stripSuffix;
    import std.format : format, formattedWrite;
    import std.traits : Unqual;

    static if (!__traits(hasMember, Sink, "put")) import std.range.primitives : put;

    static if (__traits(hasMember, Sink, "data"))
    {
        // Sink is not empty, place a newline between current content and new
        if (sink.data.length) sink.put("\n");
    }

    alias Thing = Unqual!QualThing;

    sink.formattedWrite("[%s]\n", Thing.stringof.stripSuffix("Settings"));

    foreach (immutable i, member; thing.tupleof)
    {
        import lu.traits : isAnnotated, isConfigurableVariable;
        import lu.uda : Separator, Unconfigurable;
        import std.traits : isType;

        alias T = Unqual!(typeof(member));

        static if (!isType!member &&
            isConfigurableVariable!member &&
            !isAnnotated!(thing.tupleof[i], Unconfigurable) &&
            !is(T == struct) && !is(T == class))
        {
            import std.traits : isArray, isSomeString;

            enum memberstring = __traits(identifier, thing.tupleof[i]);

            static if (!isSomeString!T && isArray!T)
            {
                import std.traits : getUDAs, hasUDA;

                // array, join it together

                static if (hasUDA!(thing.tupleof[i], Separator))
                {
                    alias separators = getUDAs!(thing.tupleof[i], Separator);
                    enum separator = separators[0].token;

                    static assert(separator.length, ("`%s.%s` is annotated with an " ~
                        "invalid `Separator` (empty)")
                        .format(Thing.stringof, memberstring));
                }
                else static if ((__VERSION__ >= 2087L) && hasUDA!(thing.tupleof[i], string))
                {
                    alias separators = getUDAs!(thing.tupleof[i], string);
                    enum separator = separators[0];

                    static assert(separator.length, ("`%s.%s` is annotated with an " ~
                        "empty separator string")
                        .format(Thing.stringof, memberstring));
                }
                else
                {
                    static assert (0, "`%s.%s` is not annotated with a `Separator`"
                        .format(Thing.stringof, memberstring));
                }

                enum arrayPattern = "%-(%s" ~ separator ~ "%)";

                static if (is(typeof(member) == string[]))
                {
                    string value;

                    if (member.length)
                    {
                        import std.algorithm.iteration : map;
                        import std.array : replace;

                        enum escaped = '\\' ~ separator;
                        enum placeholder = "\0\0";  // anything really

                        // Replace separators with a placeholder and flatten with format

                        auto separatedElements = member.map!(a => a.replace(separator, placeholder));
                        value = arrayPattern
                            .format(separatedElements)
                            .replace(placeholder, escaped);

                        static if (separators.length > 1)
                        {
                            foreach (immutable furtherSeparator; separators[1..$])
                            {
                                // We're serialising; escape any other separators
                                enum furtherEscaped = '\\' ~ furtherSeparator.token;
                                value = value.replace(furtherSeparator.token, furtherEscaped);
                            }
                        }
                    }
                }
                else
                {
                    immutable value = arrayPattern.format(member);
                }
            }
            else static if (is(T == enum))
            {
                import lu.conv : Enum;
                immutable value = Enum!T.toString(member);
            }
            else
            {
                immutable value = member;
            }

            import std.range : hasLength;

            static if (is(T == bool) || is(T == enum))
            {
                enum comment = false;
            }
            else static if (is(T == float) || is(T == double))
            {
                import std.conv : to;
                import std.math : isNaN;
                immutable comment = member.to!T.isNaN;
            }
            else static if (hasLength!T || isSomeString!T)
            {
                immutable comment = !member.length;
            }
            else
            {
                immutable comment = (member == T.init);
            }

            if (comment)
            {
                // .init or otherwise disabled
                sink.formattedWrite("#%s\n", memberstring);
            }
            else
            {
                import lu.uda : Quoted;

                static if (isSomeString!T && isAnnotated!(thing.tupleof[i], Quoted))
                {
                    sink.formattedWrite("%s \"%s\"\n", memberstring, value);
                }
                else
                {
                    sink.formattedWrite("%s %s\n", memberstring, value);
                }
            }
        }
    }
}

unittest
{
    import lu.uda : Separator, Quoted;
    import std.array : Appender;

    struct FooSettings
    {
        string fooasdf = "foo 1";
        string bar = "foo 1";
        string bazzzzzzz = "foo 1";
        @Quoted flerrp = "hirr steff  ";
        double pi = 3.14159;
        @Separator(",") arr = [ 1, 2, 3 ];

        static if (__VERSION__ >= 2087L)
        {
            @("|") matey = [ "a", "b", "c" ];
        }
    }

    struct BarSettings
    {
        string foofdsa = "foo 2";
        string bar = "bar 2";
        string bazyyyyyyy = "baz 2";
        @Quoted flarrp = "   hirrsteff";
        double pipyon = 3.0;
    }

    static if (__VERSION__ >= 2087L)
    {
        enum fooSerialised =
`[Foo]
fooasdf foo 1
bar foo 1
bazzzzzzz foo 1
flerrp "hirr steff  "
pi 3.14159
arr 1,2,3
matey a|b|c
`;
    }
    else
    {
        enum fooSerialised =
`[Foo]
fooasdf foo 1
bar foo 1
bazzzzzzz foo 1
flerrp "hirr steff  "
pi 3.14159
arr 1,2,3
`;
    }

    Appender!string fooSink;
    fooSink.reserve(64);

    fooSink.serialise(FooSettings.init);
    assert((fooSink.data == fooSerialised), '\n' ~ fooSink.data);

    enum barSerialised =
`[Bar]
foofdsa foo 2
bar bar 2
bazyyyyyyy baz 2
flarrp "   hirrsteff"
pipyon 3
`;

    Appender!string barSink;
    barSink.reserve(64);

    barSink.serialise(BarSettings.init);
    assert((barSink.data == barSerialised), '\n' ~ barSink.data);

    // try two at once
    Appender!string bothSink;
    bothSink.reserve(128);
    bothSink.serialise(FooSettings.init, BarSettings.init);
    assert(bothSink.data == fooSink.data ~ '\n' ~ barSink.data);
}


// deserialise
/++
 +  Takes an input range containing configuration text and applies the contents
 +  therein to one or more passed struct/class objects.
 +
 +  Example:
 +  ---
 +  IRCClient client;
 +  IRCServer server;
 +  string[][string] missingEntries;
 +  string[][string] invalidEntries;
 +
 +  "kameloso.conf"
 +      .configurationText
 +      .splitter("\n")
 +      .deserialise(missingEntries, invalidEntries, client, server);
 +  ---
 +
 +  Params:
 +      range = Input range from which to read the configuration text.
 +      missingEntries = Out reference of an associative array of string arrays
 +          of expected entries that were missing.
 +      invalidEntries = Out reference of an associative array of string arrays
 +          of unexpected entries that did not belong.
 +      things = Reference variadic list of one or more objects to apply the
 +          configuration to.
 +
 +  Throws: `DeserialisationException` if there were bad lines.
 +/
void deserialise(Range, Things...)(Range range, out string[][string] missingEntries,
    out string[][string] invalidEntries, ref Things things) pure
if (allSatisfy!(isStruct, Things))
{
    import lu.string : stripSuffix, stripped;
    import lu.traits : isAnnotated;
    import lu.uda : Unconfigurable;
    import std.format : format;

    string section;
    bool[Things.length] processedThings;
    bool[string][string] encounteredOptions;

    // Populate `encounteredOptions` with all the options in `Things`, but
    // set them to false. Flip to true when we encounter one.
    foreach (immutable i, thing; things)
    {
        import std.traits : Unqual, isType;

        alias Thing = typeof(thing);

        static foreach (immutable n; 0..things[i].tupleof.length)
        {{
            static if (!isType!(Things[i].tupleof[n]) &&
                !isAnnotated!(things[i].tupleof[n], Unconfigurable))
            {
                enum memberstring = __traits(identifier, Things[i].tupleof[n]);
                encounteredOptions[Thing.stringof][memberstring] = false;
            }
        }}
    }

    lineloop:
    foreach (const rawline; range)
    {
        string line = rawline.stripped;  // mutable
        if (!line.length) continue;

        switch (line[0])
        {
        case '#':
        case ';':
            // Comment
            continue;

        case '/':
            if ((line.length > 1) && (line[1] == '/'))
            {
                // Also a comment; //
                continue;
            }
            goto default;

        case '[':
            // New section. Check if there's still something to do
            immutable sectionBackup = line;
            bool stillSomethingToProcess;

            static foreach (immutable size_t i; 0..Things.length)
            {
                stillSomethingToProcess |= !processedThings[i];
            }

            if (!stillSomethingToProcess) break lineloop;  // All done, early break

            try
            {
                import std.format : formattedRead;
                line.formattedRead("[%s]", section);
            }
            catch (Exception e)
            {
                throw new DeserialisationException("Malformed section header \"%s\", %s"
                    .format(sectionBackup, e.msg));
            }
            continue;

        default:
            // entry-value line
            if (!section.length)
            {
                throw new DeserialisationException("Sectionless orphan \"%s\""
                    .format(line));
            }

            thingloop:
            foreach (immutable i, thing; things)
            {
                import lu.uda : CannotContainComments;
                import std.traits : Unqual, isType;

                alias T = Unqual!(typeof(thing));
                enum settingslessT = T.stringof.stripSuffix("Settings").idup;

                if (section != settingslessT) continue thingloop;
                processedThings[i] = true;

                immutable result = splitEntryValue(line);
                immutable entry = result.entry;
                if (!entry.length) continue;

                string value = result.value;  // mutable for later slicing

                switch (entry)
                {
                static foreach (immutable n; 0..things[i].tupleof.length)
                {{
                    static if (!isType!(Things[i].tupleof[n]) &&
                        !isAnnotated!(things[i].tupleof[n], Unconfigurable))
                    {
                        enum memberstring = __traits(identifier, Things[i].tupleof[n]);

                        case memberstring:
                            import lu.objmanip : setMemberByName;

                            static if (isAnnotated!(things[i].tupleof[n], CannotContainComments))
                            {
                                things[i].setMemberByName(entry, value);
                            }
                            else
                            {
                                import lu.string : contains, nom;

                                // Slice away any comments
                                value = value.contains('#') ? value.nom('#') : value;
                                value = value.contains(';') ? value.nom(';') : value;
                                value = value.contains("//") ? value.nom("//") : value;
                                things[i].setMemberByName(entry, value);
                            }

                            encounteredOptions[Things[i].stringof][memberstring] = true;
                            continue lineloop;
                    }
                }}

                default:
                    // Unknown setting in known section
                    invalidEntries[section] ~= entry.length ? entry : line;
                    break;
                }
            }

            break;
        }
    }

    // Compose missing entries and save them as arrays in `missingEntries`.
    foreach (immutable encounteredSection, const entryMatches; encounteredOptions)
    {
        foreach (immutable entry, immutable encountered; entryMatches)
        {
            if (!encountered) missingEntries[encounteredSection] ~= entry;
        }
    }
}


// deserialise
/++
 +  Takes an input range containing configuration text and applies the contents
 +  therein to one or more passed struct/class objects.
 +
 +  Example:
 +  ---
 +  IRCClient client;
 +  IRCServer server;
 +
 +  "kameloso.conf"
 +      .configurationText
 +      .splitter("\n")
 +      .deserialise(client, server);
 +  ---
 +
 +  Params:
 +      range = Input range from which to read the configuration text.
 +      things = Reference variadic list of one or more objects to apply the
 +          configuration to.
 +
 +  Returns:
 +      An associative array of string arrays of invalid configuration entries.
 +      The associative array key is the section the entry was found under, and
 +      the arrays merely lists of such erroneous entries thereunder.
 +
 +  Throws: `DeserialisationException` if there were bad lines.
 +/
string[][string] deserialise(Range, Things...)(Range range, ref Things things) pure
if (allSatisfy!(isStruct, Things))
{
    string[][string] missing;
    string[][string] invalid;

    deserialise(range, missing, invalid, things);
    return invalid;
}

unittest
{
    import lu.uda : Separator;
    import std.algorithm.iteration : splitter;
    import std.conv : text;

    struct Foo
    {
        enum Bar { blaawp = 5, oorgle = -1 }
        int i;
        string s;
        bool b;
        float f;
        double d;
        Bar bar;

        @Separator(",")
        {
            int[] ia;
            string[] sa;
            bool[] ba;
            float[] fa;
            double[] da;
            Bar[] bara;
        }
    }

    enum configurationFileContents = `

[Foo]
i       42
ia      1,2,-3,4,5
s       hello world!
sa      hello,world,!
b       true
ba      true,false,true

# comment
; other type of comment
// third type of comment

f       3.14 #hirp
fa      0.0,1.1,-2.2,3.3 ;herp
d       99.9 //derp
da      99.9999,0.0001,-1
bar     oorgle
bara    blaawp,oorgle,blaawp

[DifferentSection]
ignored completely
because no DifferentSection struct was passed
nil     5
naN     !"¤%&/`;

    Foo foo;
    configurationFileContents
        .splitter("\n")
        .deserialise(foo);

    with (foo)
    {
        assert((i == 42), i.text);
        assert((ia == [ 1, 2, -3, 4, 5 ]), ia.text);
        assert((s == "hello world!"), s);
        assert((sa == [ "hello", "world", "!" ]), sa.text);
        assert(b);
        assert((ba == [ true, false, true ]), ba.text);
        assert((f == 3.14f), f.text);
        assert((fa == [ 0.0f, 1.1f, -2.2f, 3.3f ]), fa.text);
        assert((d == 99.9), d.text);

        // rounding errors with LDC on Windows
        import std.math : approxEqual;
        assert(da[0].approxEqual(99.9999), da[0].text);
        assert(da[1].approxEqual(0.0001), da[1].text);
        assert(da[2].approxEqual(-1.0), da[2].text);

        with (Foo.Bar)
        {
            assert((bar == oorgle), b.text);
            assert((bara == [ blaawp, oorgle, blaawp ]), bara.text);
        }
    }

    struct DifferentSection
    {
        string ignored;
        string because;
        int nil;
        string naN;
    }

    // Can read other structs from the same file

    DifferentSection diff;
    configurationFileContents
        .splitter("\n")
        .deserialise(diff);

    with (diff)
    {
        assert((ignored == "completely"), ignored);
        assert((because == "no DifferentSection struct was passed"), because);
        assert((nil == 5), nil.text);
        assert((naN == `!"¤%&/`), naN);
    }
}


// justifiedConfigurationText
/++
 +  Takes an unformatted string of configuration text and justifies it to neat columns.
 +
 +  It does one pass through it all first to determine the maximum width of the
 +  entry names, then another to format it and eventually return a flat string.
 +
 +  Example:
 +  ---
 +  IRCClient client;
 +  IRCServer server;
 +  Appender!string sink;
 +
 +  sink.serialise(client, server);
 +  immutable justified = sink.data.justifiedConfigurationText;
 +  ---
 +
 +  Params:
 +      origLines = Unjustified raw configuration text.
 +
 +  Returns:
 +      .ini file-like configuration text, justified into two columns.
 +/
auto justifiedConfigurationText(const string origLines) pure
{
    import lu.string : stripped;
    import std.algorithm.comparison : max;
    import std.algorithm.iteration : splitter;
    import std.array : Appender;

    enum decentReserve = 4096;

    Appender!(string[]) unjustified;
    unjustified.reserve(decentReserve);
    size_t longestEntryLength;

    foreach (immutable rawline; origLines.splitter("\n"))
    {
        immutable line = rawline.stripped;

        if (!line.length)
        {
            unjustified.put("");
            continue;
        }

        switch (line[0])
        {
        case '#':
        case ';':
        case '[':
            // comment or section header
            unjustified.put(line);
            continue;

        case '/':
            if ((line.length > 1) && (line[1] == '/'))
            {
                // Also a comment
                goto case '#';
            }
            goto default;

        default:
            import std.format : format;

            immutable result = splitEntryValue(line);
            longestEntryLength = max(longestEntryLength, result.entry.length);
            unjustified.put("%s %s".format(result.entry, result.value));
            break;
        }
    }

    import lu.numeric : getMultipleOf;
    import std.algorithm.iteration : joiner;

    Appender!string justified;
    justified.reserve(decentReserve);

    assert((longestEntryLength > 0), "No longest entry; is the struct empty?");
    assert((unjustified.data.length > 0), "Unjustified data is empty");

    enum minimumWidth = 24;
    immutable width = max(minimumWidth, longestEntryLength.getMultipleOf!(Yes.alwaysOneUp)(4));

    foreach (immutable line; unjustified.data)
    {
        if (!line.length)
        {
            // Don't add a linebreak at the top of the file
            if (justified.data.length) justified.put("\n");
            continue;
        }

        switch (line[0])
        {
        case '#':
        case ';':
        case '[':
            justified.put(line);
            justified.put("\n");
            continue;

        case '/':
            if ((line.length > 1) && (line[1] == '/'))
            {
                // Also a comment
                goto case '#';
            }
            goto default;

        default:
            import std.format : formattedWrite;

            immutable result = splitEntryValue(line);
            justified.formattedWrite("%-*s%s\n", width, result.entry, result.value);
            break;
        }
    }

    return justified.data.stripped;
}

unittest
{
    import std.algorithm.iteration : splitter;
    import std.array : Appender;
    import lu.uda : Separator;

    struct Foo
    {
        enum Bar { blaawp = 5, oorgle = -1 }
        int someInt = 42;
        string someString = "hello world!";
        bool someBool = true;
        float someFloat = 3.14f;
        double someDouble = 99.9;
        Bar someBars = Bar.oorgle;
        string harbl;

        @Separator(",")
        {
            int[] intArray = [ 1, 2, -3, 4, 5 ];
            string[] stringArrayy = [ "hello", "world", "!" ];
            bool[] boolArray = [ true, false, true ];
            float[] floatArray = [ 0.0, 1.1, -2.2, 3.3 ];
            double[] doubleArray = [ 99.9999, 0.0001, -1.0 ];
            Bar[] barArray = [ Bar.blaawp, Bar.oorgle, Bar.blaawp ];
            string[] yarn;
        }
    }

    struct DifferentSection
    {
        string ignored = "completely";
        string because = "   no DifferentSection struct was passed";
        int nil = 5;
        string naN = `!"#¤%&/`;
    }

    Appender!string sink;
    sink.reserve(512);
    Foo foo;
    DifferentSection diff;
    enum unjustified =
`[Foo]
someInt 42
someString hello world!
someBool true
someFloat 3.14
someDouble 99.9
someBars oorgle
#harbl
intArray 1,2,-3,4,5
stringArrayy hello,world,!
boolArray true,false,true
floatArray 0,1.1,-2.2,3.3
doubleArray 99.9999,0.0001,-1
barArray blaawp,oorgle,blaawp
#yarn

[DifferentSection]
ignored completely
because    no DifferentSection struct was passed
nil 5
naN !"#¤%&/
`;

    enum justified =
`[Foo]
someInt                 42
someString              hello world!
someBool                true
someFloat               3.14
someDouble              99.9
someBars                oorgle
#harbl
intArray                1,2,-3,4,5
stringArrayy            hello,world,!
boolArray               true,false,true
floatArray              0,1.1,-2.2,3.3
doubleArray             99.9999,0.0001,-1
barArray                blaawp,oorgle,blaawp
#yarn

[DifferentSection]
ignored                 completely
because                 no DifferentSection struct was passed
nil                     5
naN                     !"#¤%&/`;

    sink.serialise(foo, diff);
    assert((sink.data == unjustified), '\n' ~ sink.data);
    immutable configText = justifiedConfigurationText(sink.data);

    assert((configText == justified), '\n' ~ configText);
}


// DeserialisationException
/++
 +  Exception, to be thrown when the specified configuration file could not be
 +  parsed, for whatever reason.
 +/
final class DeserialisationException : Exception
{
@safe:
    /++
     +  Create a new `DeserialisationException`.
     +/
    this(const string message, const string file = __FILE__, const size_t line = __LINE__) pure nothrow @nogc
    {
        super(message, file, line);
    }
}


// splitEntryValue
/++
 +  Splits a line into an entry and a value component.
 +
 +  This drop-in-replaces the regex: `"^(?P<entry>[^ \t]+)[ \t]+(?P<value>.+)"`.
 +
 +  Params:
 +      line = String to split up.
 +
 +  Returns:
 +      A Voldemort struct with an `entry` and a `value` member.
 +/
auto splitEntryValue(const string line) pure nothrow @nogc
{
    import std.string : representation;
    import std.ascii : isWhite;

    struct EntryValue
    {
        string entry;
        string value;
    }

    EntryValue result;

    foreach (immutable i, immutable c; line.representation)
    {
        if (!c.isWhite)
        {
            if (result.entry.length)
            {
                result.value = line[i..$];
                break;
            }
        }
        else if (!result.entry.length)
        {
            result.entry = line[0..i];
        }
    }

    return result;
}

///
unittest
{
    {
        immutable line = "monochrome            true";
        immutable result = splitEntryValue(line);
        assert((result.entry == "monochrome"), result.entry);
        assert((result.value == "true"), result.value);
    }
    {
        immutable line = "monochrome\tfalse";
        immutable result = splitEntryValue(line);
        assert((result.entry == "monochrome"), result.entry);
        assert((result.value == "false"), result.value);
    }
    {
        immutable line = "harbl                  ";
        immutable result = splitEntryValue(line);
        assert((result.entry == "harbl"), result.entry);
        assert(!result.value.length, result.value);
    }
    {
        immutable line = "ha\t \t \t\t  \t  \t      \tha";
        immutable result = splitEntryValue(line);
        assert((result.entry == "ha"), result.entry);
        assert((result.value == "ha"), result.value);
    }
}
