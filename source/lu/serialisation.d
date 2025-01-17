/++
    Various functions related to serialising and deserialising structs into/from
    .ini-like files.

    Example:
    ---
    struct FooSettings
    {
        string fooasdf;
        string bar;
        string bazzzzzzz;
        @Quoted flerrp;
        double pi;
    }

    FooSettings f;

    f.fooasdf = "foo";
    f.bar = "bar";
    f.bazzzzzzz = "baz";
    f.flerrp = "hirr steff  ";
    f.pi = 3.14159;

    enum fooSerialised =
   `[Foo]
    fooasdf foo
    bar bar
    bazzzzzzz baz
    flerrp "hirr steff  "
    pi 3.14159`;

    enum fooJustified =
    `[Foo]
    fooasdf                 foo
    bar                     bar
    bazzzzzzz               baz
    flerrp                  "hirr steff  "
    pi                      3.14159`;

    Appender!(char[]) sink;

    sink.serialise(f);
    assert(sink[].justifiedEntryValueText == fooJustified);

    FooSettings mirror;
    deserialise(fooSerialised, mirror);
    assert(mirror == f);

    FooSettings mirror2;
    deserialise(fooJustified, mirror2);
    assert(mirror2 == mirror);
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.serialisation;

private:

public:

import lu.uda : CannotContainComments, Quoted, Separator, Unserialisable;


// serialise
/++
    Convenience function to call [serialise] on several objects.

    Example:
    ---
    struct Foo
    {
        // ...
    }

    struct Bar
    {
        // ...
    }

    Foo foo;
    Bar bar;

    Appender!(char[]) sink;

    sink.serialise(foo, bar);
    assert(!sink[].empty);
    ---

    Params:
        sink = Reference output range to write the serialised objects to (in
            their .ini file-like format).
        things = Variadic list of objects to serialise.
 +/
void serialise(Sink, Things...)(auto ref Sink sink, auto ref Things things)
if (Things.length > 1)
{
    import std.meta : allSatisfy;
    import std.range.primitives : isOutputRange;
    import std.traits : isAggregateType;

    static if (!isOutputRange!(Sink, char[]))
    {
        enum message = "`serialise` sink must be an output range accepting `char[]`";
        static assert(0, message);
    }

    static if (!allSatisfy!(isAggregateType, Things))
    {
        enum message = "`serialise` was passed one or more non-aggregate types";
        static assert(0, message);
    }

    foreach (immutable i, const thing; things)
    {
        if (i > 0) sink.put('\n');
        sink.serialise(thing);
    }
}


// serialise
/++
    Serialises the fields of an object into an .ini file-like format.

    It only serialises fields not annotated with
    [lu.uda.Unserialisable|Unserialisable], and it doesn't recurse into other
    structs or classes.

    Example:
    ---
    struct Foo
    {
        // ...
    }

    Foo foo;

    Appender!(char[]) sink;

    sink.serialise(foo);
    assert(!sink[].empty);
    ---

    Params:
        sink = Reference output range to write to, usually an
            [std.array.Appender|Appender].
        thing = Object to serialise.
 +/
void serialise(Sink, QualThing)(auto ref Sink sink, auto ref QualThing thing)
{
    import lu.string : stripSuffix;
    import std.format : format, formattedWrite;
    import std.meta : allSatisfy;
    import std.range.primitives : isOutputRange;
    import std.traits : Unqual, isAggregateType;

    static if (!isOutputRange!(Sink, char[]))
    {
        enum message = "`serialise` sink must be an output range accepting `char[]`";
        static assert(0, message);
    }

    static if (!allSatisfy!(isAggregateType, QualThing))
    {
        enum message = "`serialise` was passed one or more non-aggregate types";
        static assert(0, message);
    }

    static if (__traits(hasMember, Sink, "data"))
    {
        // Sink is not empty, place a newline between current content and new
        if (sink[].length) sink.put("\n");
    }

    alias Thing = Unqual!QualThing;

    sink.formattedWrite("[%s]\n", Thing.stringof.stripSuffix("Settings"));

    foreach (immutable i, member; thing.tupleof)
    {
        import lu.traits : isSerialisable, udaIndexOf;
        import lu.uda : Separator, Unserialisable;
        import std.traits : isAggregateType;

        alias T = Unqual!(typeof(member));

        static if (
            isSerialisable!member &&
            (udaIndexOf!(thing.tupleof[i], Unserialisable) == -1) &&
            !isAggregateType!T)
        {
            import std.traits : isArray, isSomeString;

            enum memberstring = __traits(identifier, thing.tupleof[i]);

            static if (!isSomeString!T && isArray!T)
            {
                import lu.traits : UnqualArray;
                import std.traits : getUDAs;

                static if (udaIndexOf!(thing.tupleof[i], Separator) != -1)
                {
                    alias separators = getUDAs!(thing.tupleof[i], Separator);
                    enum separator = separators[0].token;

                    static if (!separator.length)
                    {
                        enum pattern = "`%s.%s` is annotated with an invalid `Separator` (empty)";
                        static assert(0, pattern.format(Thing.stringof, memberstring));
                    }
                }
                else static if (udaIndexOf!(thing.tupleof[i], string) != -1)
                {
                    alias separators = getUDAs!(thing.tupleof[i], string);
                    enum separator = separators[0];

                    static if (!separator.length)
                    {
                        enum pattern = "`%s.%s` is annotated with an empty separator string";
                        static assert(0, pattern.format(Thing.stringof, memberstring));
                    }
                }
                else
                {
                    enum pattern = "`%s.%s` is not annotated with a `Separator`";
                    static assert (0, pattern.format(Thing.stringof, memberstring));
                }

                alias TA = UnqualArray!(typeof(member));

                enum arrayPattern = "%-(%s" ~ separator ~ "%)";
                enum escapedSeparator = '\\' ~ separator;

                SerialisationUDAs udas;
                udas.separator = separator;
                udas.arrayPattern = arrayPattern;
                udas.escapedSeparator = escapedSeparator;

                immutable value = serialiseArrayImpl!TA(thing.tupleof[i], udas);
            }
            else static if (is(T == enum))
            {
                import lu.conv : Enum;
                immutable value = Enum!T.toString(member);
            }
            else
            {
                auto value = member;
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

            if (i > 0) sink.put('\n');

            if (comment)
            {
                // .init or otherwise disabled
                sink.put("#" ~ memberstring);
            }
            else
            {
                import lu.uda : Quoted;

                static if (isSomeString!T && (udaIndexOf!(thing.tupleof[i], Quoted) != -1))
                {
                    enum pattern = `%s "%s"`;
                }
                else
                {
                    enum pattern = "%s %s";
                }

                sink.formattedWrite(pattern, memberstring, value);
            }
        }
    }

    static if (!__traits(hasMember, Sink, "data"))
    {
        // Not an Appender, may be stdout.lockingTextWriter
        sink.put('\n');
    }
}

///
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
        @Separator(",") int[] arr = [ 1, 2, 3 ];
        @Separator(";") string[] harbl = [ "harbl;;", ";snarbl;", "dirp" ];
        @("|") string[] matey = [ "a", "b", "c" ];
    }

    struct BarSettings
    {
        string foofdsa = "foo 2";
        string bar = "bar 2";
        string bazyyyyyyy = "baz 2";
        @Quoted flarrp = "   hirrsteff";
        double pipyon = 3.0;
    }

    enum fooSerialised =
`[Foo]
fooasdf foo 1
bar foo 1
bazzzzzzz foo 1
flerrp "hirr steff  "
pi 3.14159
arr 1,2,3
harbl harbl\;\;;\;snarbl\;;dirp
matey a|b|c`;

    Appender!(char[]) fooSink;
    fooSink.reserve(64);

    fooSink.serialise(FooSettings.init);
    assert((fooSink[] == fooSerialised), '\n' ~ fooSink[]);

    enum barSerialised =
`[Bar]
foofdsa foo 2
bar bar 2
bazyyyyyyy baz 2
flarrp "   hirrsteff"
pipyon 3`;

    Appender!(char[]) barSink;
    barSink.reserve(64);

    barSink.serialise(BarSettings.init);
    assert((barSink[] == barSerialised), '\n' ~ barSink[]);

    // try two at once
    Appender!(char[]) bothSink;
    bothSink.reserve(128);
    bothSink.serialise(FooSettings.init, BarSettings.init);
    assert(bothSink[] == fooSink[] ~ "\n\n" ~ barSink[]);

    class C
    {
        int i;
        bool b;
    }

    C c = new C;
    c.i = 42;
    c.b = true;

    enum cSerialised =
`[C]
i 42
b true`;

    Appender!(char[]) cSink;
    cSink.reserve(128);
    cSink.serialise(c);
    assert((cSink[] == cSerialised), '\n' ~ cSink[]);

    enum Letters { abc, def, ghi, }

    struct Struct
    {
        Letters let = Letters.def;
    }

    enum enumTestSerialised =
`[Struct]
let def`;

    Struct st;
    Appender!(char[]) enumTestSink;
    enumTestSink.serialise(st);
    assert((enumTestSink[] == enumTestSerialised), '\n' ~ enumTestSink[]);
}


// SerialisationUDAs
/++
    Summary of UDAs that an array to be serialised is annotated with.

    UDAs do not persist across function calls, so they must be summarised
    (such as in a struct like this) and separately passed, at compile-time or runtime.
 +/
private struct SerialisationUDAs
{
    /++
        Whether or not the member was annotated [lu.uda.Unserialisable|Unserialisable].
     +/
    bool unserialisable;

    /++
        Whether or not the member was annotated with a [lu.uda.Separator|Separator].
     +/
    string separator;

    /++
        The escaped form of [separator].

        ---
        enum escapedSeparator = '\\' ~ separator;
        ---
     +/
    string escapedSeparator;

    /++
        The [std.format.format|format] pattern used to format the array this struct
        refers to. This is separator-specific.

        ---
        enum arrayPattern = "%-(%s" ~ separator ~ "%)";
        ---
     +/
    string arrayPattern;
}


// serialiseArrayImpl
/++
    Serialises a non-string array into a single row. To be used when serialising
    an aggregate with [serialise].

    Since UDAs do not persist across function calls, they must be summarised
    in a [SerialisationUDAs] struct separately so we can pass them at runtime.

    Params:
        array = Array to serialise.
        udas = Aggregate of UDAs the original array was annotated with, passed as
            a runtime value.

    Returns:
        A string, to be saved as a serialised row in an .ini file-like format.
 +/
private string serialiseArrayImpl(T)(const auto ref T array, const SerialisationUDAs udas)
{
    import std.format : format;

    static if (is(T == string[]))
    {
        /+
            Strings must be formatted differently since the specified separator
            can occur naturally in the string.
         +/
        string value;

        if (array.length)
        {
            import std.algorithm.iteration : map;
            import std.array : replace;

            enum placeholder = "\0\0";  // anything really

            // Replace separator with a placeholder and flatten with format
            // enum arrayPattern = "%-(%s" ~ separator ~ "%)";

            auto separatedElements = array.map!(a => a.replace(udas.separator, placeholder));
            value = udas.arrayPattern
                .format(separatedElements)
                .replace(placeholder, udas.escapedSeparator);
        }
    }
    else
    {
        immutable value = udas.arrayPattern.format(array);
    }

    return value;
}


@safe:


// deserialise
/++
    Takes an input range containing serialised entry-value text and applies the
    contents therein to one or more passed struct/class objects.

    Example:
    ---
    struct Foo
    {
        // ...
    }

    struct Bar
    {
        // ...
    }

    Foo foo;
    Bar bar;

    string[][string] missingEntries;
    string[][string] invalidEntries;

    string fromFile = readText("configuration.conf");

    fromFile
        .splitter("\n")
        .deserialise(missingEntries, invalidEntries, foo, bar);
    ---

    Params:
        range = Input range from which to read the serialised text.
        missingEntries = Out reference of an associative array of string arrays
            of expected entries that were missing.
        invalidEntries = Out reference of an associative array of string arrays
            of unexpected entries that did not belong.
        things = Reference variadic list of one or more objects to apply the
            deserialised values to.

    Throws: [DeserialisationException] if there were bad lines.
 +/
void deserialise(Range, Things...)
    (auto ref Range range,
    out string[][string] missingEntries,
    out string[][string] invalidEntries,
    ref Things things) pure
{
    import lu.string : stripSuffix, stripped;
    import lu.traits : isSerialisable, udaIndexOf;
    import lu.uda : Unserialisable;
    import std.format : format;
    import std.meta : allSatisfy;
    import std.traits : Unqual, isAggregateType, isMutable;

    static if (!allSatisfy!(isAggregateType, Things))
    {
        enum message = "`deserialise` was passed one or more non-aggregate types";
        static assert(0, message);
    }

    static if (!allSatisfy!(isMutable, Things))
    {
        enum message = "`serialise` was passed one or more non-mutable types";
        static assert(0, message);
    }

    string section;
    bool[Things.length] processedThings;
    bool[string][string] encounteredOptions;

    // Populate `encounteredOptions` with all the options in `Things`, but
    // set them to false. Flip to true when we encounter one.
    foreach (immutable i, thing; things)
    {
        alias Thing = Unqual!(typeof(thing));

        static foreach (immutable n; 0..things[i].tupleof.length)
        {{
            static if (
                isSerialisable!(Things[i].tupleof[n]) &&
                (udaIndexOf!(things[i].tupleof[n], Unserialisable) == -1))
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

        bool commented;

        switch (line[0])
        {
        case '#':
        case ';':
            // Comment
            if (!section.length) continue;  // e.g. banner

            while (line.length && ((line[0] == '#') || (line[0] == ';') || (line[0] == '/')))
            {
                line = line[1..$];
            }

            if (!line.length) continue;

            commented = true;
            goto default;

        case '/':
            if ((line.length > 1) && (line[1] == '/'))
            {
                // Also a comment; //
                line = line[2..$];
            }

            while (line.length && (line[0] == '/'))
            {
                // Consume extra slashes too
                line = line[1..$];
            }

            if (!line.length) continue;

            commented = true;
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

            //thingloop:
            foreach (immutable i, thing; things)
            {
                import lu.string : strippedLeft;
                import lu.traits : isSerialisable;
                import lu.uda : CannotContainComments;
                import std.traits : Unqual;

                alias T = Unqual!(typeof(thing));
                enum settingslessT = T.stringof.stripSuffix("Settings").idup;

                if (section != settingslessT) continue; // thingloop;
                processedThings[i] = true;

                immutable result = splitEntryValue(line.strippedLeft);
                immutable entry = result.entry;
                if (!entry.length) continue;

                string value = result.value;  // mutable for later slicing

                switch (entry)
                {
                static foreach (immutable n; 0..things[i].tupleof.length)
                {{
                    static if (
                        isSerialisable!(Things[i].tupleof[n]) &&
                        (udaIndexOf!(things[i].tupleof[n], Unserialisable) == -1))
                    {
                        enum memberstring = __traits(identifier, Things[i].tupleof[n]);

                        case memberstring:
                            import lu.objmanip : setMemberByName;

                            if (!commented)
                            {
                                // Entry is uncommented; set

                                static if (udaIndexOf!(things[i].tupleof[n], CannotContainComments) != -1)
                                {
                                    cast(void)things[i].setMemberByName(entry, value);
                                }
                                else
                                {
                                    import lu.string : advancePast;
                                    import std.string : indexOf;

                                    // Slice away any comments
                                    value = (value.indexOf('#') != -1)  ? value.advancePast('#')  : value;
                                    value = (value.indexOf(';') != -1)  ? value.advancePast(';')  : value;
                                    value = (value.indexOf("//") != -1) ? value.advancePast("//") : value;
                                    cast(void)things[i].setMemberByName(entry, value);
                                }
                            }

                            encounteredOptions[Unqual!(Things[i]).stringof][memberstring] = true;
                            continue lineloop;
                    }
                }}

                default:
                    // Unknown setting in known section
                    if (!commented) invalidEntries[section] ~= entry.length ? entry : line;
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
            immutable sectionName = encounteredSection.stripSuffix("Settings");
            if (!encountered) missingEntries[sectionName] ~= entry;
        }
    }
}

///
unittest
{
    import lu.uda : Separator;
    import std.algorithm.iteration : splitter;
    import std.conv : text;

    struct FooSettings
    {
        enum Bar { blaawp = 5, oorgle = -1 }
        int i;
        string s;
        bool b;
        float f;
        double d;
        Bar bar;
        string commented;
        string slashed;
        int missing;
        //bool invalid;

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

    enum serialisedFileContents =
`[Foo]
i       42
ia      1,2,-3,4,5
s       hello world!
sa      hello,world,!
b       true
ba      true,false,true
invalid name

# comment
; other type of comment
// third type of comment

f       3.14 #hirp
fa      0.0,1.1,-2.2,3.3 ;herp
d       99.9 //derp
da      99.9999,0.0001,-1
bar     oorgle
bara    blaawp,oorgle,blaawp
#commented hi
// slashed also commented
invalid ho

[DifferentSection]
ignored completely
because no DifferentSection struct was passed
nil     5
naN     !"¤%&/`;

    string[][string] missing;
    string[][string] invalid;

    FooSettings foo;
    serialisedFileContents
        .splitter("\n")
        .deserialise(missing, invalid, foo);

    with (foo)
    {
        import std.math : isClose;

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
        assert(da[0].isClose(99.9999), da[0].text);
        assert(da[1].isClose(0.0001), da[1].text);
        assert(da[2].isClose(-1.0), da[2].text);

        with (FooSettings.Bar)
        {
            assert((bar == oorgle), bar.text);
            assert((bara == [ blaawp, oorgle, blaawp ]), bara.text);
        }
    }

    import std.algorithm.searching : canFind;

    assert("Foo" in missing);
    assert(missing["Foo"].canFind("missing"));
    assert(!missing["Foo"].canFind("commented"));
    assert(!missing["Foo"].canFind("slashed"));
    assert("Foo" in invalid);
    assert(invalid["Foo"].canFind("invalid"));

    struct DifferentSection
    {
        string ignored;
        string because;
        int nil;
        string naN;
    }

    // Can read other structs from the same file

    DifferentSection diff;
    serialisedFileContents
        .splitter("\n")
        .deserialise(missing, invalid, diff);

    with (diff)
    {
        assert((ignored == "completely"), ignored);
        assert((because == "no DifferentSection struct was passed"), because);
        assert((nil == 5), nil.text);
        assert((naN == `!"¤%&/`), naN);
    }

    enum Letters { abc, def, ghi, }

    struct Struct
    {
        Letters lt = Letters.def;
    }

    enum configContents =
`[Struct]
lt ghi
`;
    Struct st;
    configContents
        .splitter("\n")
        .deserialise(missing, invalid, st);

    assert(st.lt == Letters.ghi);

    class Class
    {
        enum Bar { blaawp = 5, oorgle = -1 }
        int i;
        string s;
        bool b;
        float f;
        double d;
        Bar bar;
        string omitted;

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

    enum serialisedFileContentsClass =
`[Class]
i       42
ia      1,2,-3,4,5
s       hello world!
sa      hello,world,!
b       true
ba      true,false,true
wrong   name

# comment
; other type of comment
// third type of comment

f       3.14 #hirp
fa      0.0,1.1,-2.2,3.3 ;herp
d       99.9 //derp
da      99.9999,0.0001,-1
bar     oorgle
bara    blaawp,oorgle,blaawp`;

    Class c = new Class;
    serialisedFileContentsClass
        .splitter("\n")
        .deserialise(missing, invalid, c);

    with (c)
    {
        import std.math : isClose;

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
        assert(da[0].isClose(99.9999), da[0].text);
        assert(da[1].isClose(0.0001), da[1].text);
        assert(da[2].isClose(-1.0), da[2].text);

        with (Class.Bar)
        {
            assert((bar == oorgle), b.text);
            assert((bara == [ blaawp, oorgle, blaawp ]), bara.text);
        }
    }
}


// justifiedEntryValueText
/++
    Takes an unformatted string of serialised entry-value text and justifies it
    into two neat columns.

    It does one pass through it all first to determine the maximum width of the
    entry names, then another to format it and eventually return a flat string.

    Example:
    ---
    struct Foo
    {
        // ...
    }

    struct Bar
    {
        // ...
    }

    Foo foo;
    Bar bar;

    Appender!(char[]) sink;

    sink.serialise(foo, bar);
    immutable justified = sink[].justifiedEntryValueText;
    ---

    Params:
        origLines = Unjustified raw serialised text.

    Returns:
        .ini file-like text, justified into two columns.
 +/
string justifiedEntryValueText(const string origLines) pure
{
    import lu.numeric : getMultipleOf;
    import lu.string : stripped;
    import std.algorithm.comparison : max;
    import std.algorithm.iteration : joiner, splitter;
    import std.array : Appender;

    if (!origLines.length) return string.init;

    enum decentReserveOfLines = 256;
    enum decentReserveOfChars = 4096;

    Appender!(string[]) unjustified;
    unjustified.reserve(decentReserveOfLines);
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

    Appender!(char[]) justified;
    justified.reserve(decentReserveOfChars);

    assert((longestEntryLength > 0), "No longest entry; is the struct empty?");
    assert((unjustified[].length > 0), "Unjustified data is empty");

    enum minimumWidth = 24;
    immutable width = max(minimumWidth, longestEntryLength.getMultipleOf(4, alwaysOneUp: true));

    foreach (immutable i, immutable line; unjustified[])
    {
        if (!line.length)
        {
            // Don't add a linebreak at the top of the file
            if (justified[].length) justified.put("\n");
            continue;
        }

        if (i > 0) justified.put('\n');

        switch (line[0])
        {
        case '#':
        case ';':
        case '[':
            justified.put(line);
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
            justified.formattedWrite("%-*s%s", width, result.entry, result.value);
            break;
        }
    }

    return justified[];
}

///
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

    Appender!(char[]) sink;
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
naN !"#¤%&/`;

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
    assert((sink[] == unjustified), '\n' ~ sink[]);
    immutable configText = justifiedEntryValueText(sink[].idup);

    assert((configText == justified), '\n' ~ configText);
}


// DeserialisationException
/++
    Exception, to be thrown when the specified serialised text could not be
    parsed, for whatever reason.
 +/
final class DeserialisationException : Exception
{
    /++
        Create a new [DeserialisationException].
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }
}


// splitEntryValue
/++
    Splits a line into an entry and a value component.

    This drop-in-replaces the regex: `^(?P<entry>[^ \t]+)[ \t]+(?P<value>.+)`.

    Params:
        line = String to split up.

    Returns:
        A Voldemort struct with an `entry` and a `value` member.
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

    if (!result.entry.length) result.entry = line;

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
    {
        immutable line = "#sendAfterConnect";
        immutable result = splitEntryValue(line);
        assert((result.entry == "#sendAfterConnect"), result.entry);
        assert(!result.value.length, result.value);
    }
}
