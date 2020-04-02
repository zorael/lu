/++
 +  This module contains functions that in some way or another manipulates
 +  struct and class instances, as well as (associative) arrays.
 +
 +  Example:
 +  ---
 +  IRCUser bot;
 +
 +  bot.setMemberByName("nickname", "kameloso");
 +  bot.setMemberByName("address", "blarbh.hlrehg.org");
 +
 +  assert(bot.nickname == "kameloso");
 +  assert(bot.address == "blarbh.hlrehg.org");
 +  ---
 +/
module lu.objmanip;

public:


// setMemberByName
/++
 +  Given a struct/class object, sets one of its members by its string name to a
 +  specified value.
 +
 +  It does not currently recurse into other struct/class members.
 +
 +  Example:
 +  ---
 +  IRCUser bot;
 +
 +  bot.setMemberByName("nickname", "kameloso");
 +  bot.setMemberByName("address", "blarbh.hlrehg.org");
 +
 +  assert(bot.nickname == "kameloso");
 +  assert(bot.address == "blarbh.hlrehg.org");
 +  ---
 +
 +  Params:
 +      thing = Reference object whose members to set.
 +      memberToSet = String name of the thing's member to set.
 +      valueToSet = String contents of the value to set the member to; string
 +          even if the member is of a different type.
 +
 +  Returns:
 +      `true` if a member was found and set, `false` if not.
 +
 +  Throws: `std.conv.ConvException` if a string could not be converted into an
 +      array, if a passed string could not be converted into a bool, or if
 +      `std.conv.to` failed to convert a string into wanted type T.
 +/
bool setMemberByName(Thing)(ref Thing thing, const string memberToSet, const string valueToSet)
in (memberToSet.length, "Tried to set member by name but no member string was given")
do
{
    import lu.string : stripSuffix, stripped, unquoted;
    import std.conv : ConvException, to;

    bool success;

    top:
    switch (memberToSet)
    {
    static foreach (immutable i; 0..thing.tupleof.length)
    {{
        import lu.traits : isSerialisable;
        import std.traits : Unqual;

        alias T = Unqual!(typeof(thing.tupleof[i]));

        static if (isSerialisable!(thing.tupleof[i]))
        {
            enum memberstring = __traits(identifier, thing.tupleof[i]);

            case memberstring:
            {
                import std.traits : isArray, isAssociativeArray, isSomeString;

                static if (is(T == struct) || is(T == class))
                {
                    static if (__traits(compiles, { thing.tupleof[i] = string.init; }))
                    {
                        thing.tupleof[i] = valueToSet.stripped.unquoted;
                        success = true;
                    }

                    // Else do nothing
                }
                else static if (!isSomeString!T && isArray!T)
                {
                    import lu.uda : Separator;
                    import std.array : replace;
                    import std.traits : getUDAs, hasUDA;

                    thing.tupleof[i].length = 0;

                    static if (hasUDA!(thing.tupleof[i], Separator))
                    {
                        alias separators = getUDAs!(thing.tupleof[i], Separator);
                    }
                    else static if ((__VERSION__ >= 2087L) && hasUDA!(thing.tupleof[i], string))
                    {
                        alias separators = getUDAs!(thing.tupleof[i], string);
                    }
                    else
                    {
                        import std.format : format;
                        static assert(0, "`%s.%s` is missing a `Separator` annotation"
                            .format(Thing.stringof, memberstring));
                    }

                    enum escapedPlaceholder = "\0\0";  // anything really
                    enum ephemeralSeparator = "\1\1";  // ditto
                    enum doubleEphemeral = ephemeralSeparator ~ ephemeralSeparator;
                    enum doubleEscapePlaceholder = "\2\2";

                    string values = valueToSet.replace("\\\\", doubleEscapePlaceholder);

                    foreach (immutable thisSeparator; separators)
                    {
                        static if (is(typeof(thisSeparator) == Separator))
                        {
                            enum escaped = '\\' ~ thisSeparator.token;
                            enum separator = thisSeparator.token;
                        }
                        else
                        {
                            enum escaped = '\\' ~ thisSeparator;
                            alias separator = thisSeparator;
                        }

                        values = values
                            .replace(escaped, escapedPlaceholder)
                            .replace(separator, ephemeralSeparator)
                            .replace(escapedPlaceholder, separator);
                    }

                    import lu.string : contains;
                    while (values.contains(doubleEphemeral))
                    {
                        values = values.replace(doubleEphemeral, ephemeralSeparator);
                    }

                    values = values.replace(doubleEscapePlaceholder, "\\");

                    import std.algorithm.iteration : splitter;
                    auto range = values.splitter(ephemeralSeparator);

                    foreach (immutable entry; range)
                    {
                        try
                        {
                            import std.range : ElementEncodingType;

                            thing.tupleof[i] ~= entry
                                .stripped
                                .unquoted
                                .to!(ElementEncodingType!T);

                            success = true;
                        }
                        catch (ConvException e)
                        {
                            import std.format : format;

                            immutable message = ("Could not convert `%s.%s` array " ~
                                "entry \"%s\" into `%s` (%s)")
                                .format(Thing.stringof.stripSuffix("Settings"),
                                memberToSet, entry, T.stringof, e.msg);
                            throw new ConvException(message);
                        }
                    }
                }
                else static if (is(T : string))
                {
                    thing.tupleof[i] = valueToSet.stripped.unquoted;
                    success = true;
                }
                else static if (isAssociativeArray!T)
                {
                    // Silently ignore AAs for now
                }
                else static if (is(T == bool))
                {
                    import std.uni : toLower;

                    switch (valueToSet.stripped.unquoted.toLower)
                    {
                    case "true":
                    case "yes":
                    case "on":
                    case "1":
                        thing.tupleof[i] = true;
                        success = true;
                        break;

                    case "false":
                    case "no":
                    case "off":
                    case "0":
                        thing.tupleof[i] = false;
                        success = true;
                        break;

                    default:
                        import std.format : format;

                        immutable message = ("Invalid value for setting `%s.%s`: " ~
                            `could not convert "%s" to a boolean value`)
                            .format(Thing.stringof.stripSuffix("Settings"),
                            memberToSet, valueToSet);
                        throw new ConvException(message);
                    }
                }
                else
                {
                    try
                    {
                        static if (is(T == enum))
                        {
                            import lu.conv : Enum;

                            immutable asString = valueToSet
                                .stripped
                                .unquoted;
                            thing.tupleof[i] = Enum!T.fromString(asString);
                        }
                        else
                        {
                            /*writefln("%s.%s = %s.to!%s", Thing.stringof,
                                memberstring, valueToSet, T.stringof);*/
                            thing.tupleof[i] = valueToSet
                                .stripped
                                .unquoted
                                .to!T;
                        }

                        success = true;
                    }
                    catch (ConvException e)
                    {
                        import std.format : format;

                        immutable message = ("Invalid value for setting `%s.%s`: " ~
                            "could not convert \"%s\" to `%s` (%s)")
                            .format(Thing.stringof.stripSuffix("Settings"),
                            memberToSet, valueToSet, T.stringof, e.msg);
                        throw new ConvException(message);
                    }
                }
                break top;
            }
        }
    }}

    default:
        break;
    }

    return success;
}

///
unittest
{
    import lu.uda : Separator;
    import std.conv : to;

    struct Foo
    {
        string bar;
        int baz;

        @Separator("|")
        @Separator(" ")
        {
            string[] arr;
            string[] matey;
        }

        @Separator(";;")
        {
            string[] parrots;
            string[] withSpaces;
        }

        static if (__VERSION__ >= 2087L)
        {
            @(`\o/`)
            {
                int[] blargh;
            }
        }
    }

    Foo foo;
    bool success;

    success = foo.setMemberByName("bar", "asdf fdsa adf");
    assert(success);
    assert((foo.bar == "asdf fdsa adf"), foo.bar);

    success = foo.setMemberByName("baz", "42");
    assert(success);
    assert((foo.baz == 42), foo.baz.to!string);

    success = foo.setMemberByName("arr", "herp|derp|dirp|darp");
    assert(success);
    assert((foo.arr == [ "herp", "derp", "dirp", "darp"]), foo.arr.to!string);

    success = foo.setMemberByName("arr", "herp derp dirp|darp");
    assert(success);
    assert((foo.arr == [ "herp", "derp", "dirp", "darp"]), foo.arr.to!string);

    success = foo.setMemberByName("matey", "this,should,not,be,separated");
    assert(success);
    assert((foo.matey == [ "this,should,not,be,separated" ]), foo.matey.to!string);

    success = foo.setMemberByName("parrots", "squaawk;;parrot sounds;;repeating");
    assert(success);
    assert((foo.parrots == [ "squaawk", "parrot sounds", "repeating"]),
        foo.parrots.to!string);

    success = foo.setMemberByName("withSpaces", `         squoonk         ;;"  spaced  ";;" "`);
    assert(success);
    assert((foo.withSpaces == [ "squoonk", `  spaced  `, " "]),
        foo.withSpaces.to!string);

    success = foo.setMemberByName("invalid", "oekwpo");
    assert(!success);

    /*success = foo.setMemberByName("", "true");
    assert(!success);*/

    success = foo.setMemberByName("matey", "hirr steff\\ stuff staff\\|stirf hooo");
    assert(success);
    assert((foo.matey == [ "hirr", "steff stuff", "staff|stirf", "hooo" ]), foo.matey.to!string);

    success = foo.setMemberByName("matey", "hirr steff\\\\ stuff staff\\\\|stirf hooo");
    assert(success);
    assert((foo.matey == [ "hirr", "steff\\", "stuff", "staff\\", "stirf", "hooo" ]), foo.matey.to!string);

    success = foo.setMemberByName("matey", "asdf\\ fdsa\\\\ hirr                                steff");
    assert(success);
    assert((foo.matey == [ "asdf fdsa\\", "hirr", "steff" ]), foo.matey.to!string);

    static if (__VERSION__ >= 2087L)
    {
        success = foo.setMemberByName("blargh", `1\o/2\o/3\o/4\o/5`);
        assert(success);
        assert((foo.blargh == [ 1, 2, 3, 4, 5 ]), foo.blargh.to!string);
    }

    class C
    {
        string abc;
        int def;
    }

    C c = new C;

    success = c.setMemberByName("abc", "this is abc");
    assert(success);
    assert((c.abc == "this is abc"), c.abc);

    success = c.setMemberByName("def", "42");
    assert(success);
    assert((c.def == 42), c.def.to!string);

    import lu.conv : Enum;

    enum E { abc, def, ghi }

    struct S
    {
        E e = E.ghi;
    }

    S s;

    assert(s.e == E.ghi);
    success = s.setMemberByName("e", "def");
    assert(success);
    assert((s.e == E.def), Enum!E.toString(s.e));

    struct StructWithOpAssign
    {
        string thing = "init";

        void opAssign(const string thing)
        {
            this.thing = thing;
        }
    }

    StructWithOpAssign assignable;
    assert((assignable.thing == "init"), assignable.thing);
    assignable = "new thing";
    assert((assignable.thing == "new thing"), assignable.thing);

    struct StructWithAssignableMember
    {
        StructWithOpAssign child;
    }

    StructWithAssignableMember parent;
    success = parent.setMemberByName("child", "flerp");
    assert(success);
    assert((parent.child.thing == "flerp"), parent.child.thing);

    class ClassWithOpAssign
    {
        string thing = "init";

        void opAssign(const string thing) //@safe pure nothrow @nogc
        {
            this.thing = thing;
        }
    }

    class ClassWithAssignableMember
    {
        ClassWithOpAssign child;

        this()
        {
            child = new ClassWithOpAssign;
        }
    }

    ClassWithAssignableMember parent2 = new ClassWithAssignableMember;
    success = parent2.setMemberByName("child", "flerp");
    assert(success);
    assert((parent2.child.thing == "flerp"), parent2.child.thing);

}


@safe:

// replaceMembers
/++
 +  Inspects a passed struct or class for members whose values match that of the
 +  passed `token`. Matches members are set to a replacement value, which is
 +  an optional parameter that defaults to the `.init` value of the token's type.
 +
 +  Params:
 +      thing = Reference to a struct or class whose members to iterate over.
 +      token = What value to look for in members, be it a string or an integer
 +          or whatever; anything that can be compared to.
 +      replacement = What to assign matched values. Defaults to the `.init`
 +          of the matched type.
 +/
void replaceMembers(Thing, Token)(ref Thing thing, Token token,
    Token replacement = Token.init) pure nothrow @nogc
if (is(Thing == struct) || is(Thing == class))
do
{
    import std.traits : isArray, isSomeString;

    foreach (immutable i, ref member; thing.tupleof)
    {
        alias T = typeof(member);

        static if (is(T == struct) || is(T == class))
        {
            // Recurse
            member.replaceMembers(token, replacement);
        }
        else static if (is(T : Token))
        {
            if (member == token)
            {
                member = replacement;
            }
        }
    }
}

///
unittest
{
    struct Bar
    {
        string s = "content";
    }

    struct Foo
    {
        Bar b;
        string s = "more content";
    }

    Foo foo1, foo2;
    foo1.replaceMembers("-");
    assert(foo1 == foo2);

    foo2.s = "-";
    foo2.replaceMembers("-");
    assert(!foo2.s.length);
    foo2.b.s = "-";
    foo2.replaceMembers("-", "herblp");
    assert((foo2.b.s == "herblp"), foo2.b.s);

    Foo foo3;
    foo3.s = "---";
    foo3.b.s = "---";
    foo3.replaceMembers("---");
    assert(!foo3.s.length);
    assert(!foo3.b.s.length);

    class Baz
    {
        string barS = "init";
        string barT = "*";
        Foo f;
    }

    Baz b1 = new Baz;
    Baz b2 = new Baz;

    b1.replaceMembers("-");
    assert((b1.barS == b2.barS), b1.barS);
    assert((b1.barT == b2.barT), b1.barT);

    b1.replaceMembers("*");
    assert(b1.barS.length, b1.barS);
    assert(!b1.barT.length, b1.barT);
    assert(b1.f.s.length, b1.f.s);

    b1.replaceMembers("more content");
    assert(!b1.f.s.length, b1.f.s);

    import std.conv : to;

    struct Qux
    {
        int i = 42;
    }

    Qux q;

    q.replaceMembers("*");
    assert(q.i == 42);

    q.replaceMembers(43);
    assert(q.i == 42);

    q.replaceMembers(42, 99);
    assert((q.i == 99), q.i.to!string);
}


import std.traits : isAssociativeArray;

// pruneAA
/++
 +  Iterates an associative array and deletes invalid entries, either if the value
 +  is in a default `.init` state or as per the optionally passed predicate.
 +
 +  It is supposedly undefined behaviour to remove an associative array's fields
 +  when foreaching through it. So far we have been doing a simple mark-sweep
 +  garbage collection whenever we encounter this use-case in the code, so why
 +  not just make a generic solution instead and deduplicate code?
 +
 +  Example:
 +  ---
 +  auto aa =
 +  [
 +      "abc" : "def",
 +      "ghi" : string.init;
 +      "mno" : "123",
 +      "pqr" : string.init,
 +  ];
 +
 +  pruneAA(aa);
 +
 +  assert("ghi" !in aa);
 +  assert("pqr" !in aa);
 +
 +  pruneAA!((entry) => entry.length > 0)(aa);
 +
 +  assert("abc" !in aa);
 +  assert("mno" !in aa);
 +  ---
 +
 +  Params:
 +      pred = Optional predicate if special logic is needed to determine whether
 +          an entry is to be removed or not.
 +      aa = The associative array to modify.
 +/
void pruneAA(alias pred = null, T)(ref T aa)
if (isAssociativeArray!T)
{
    if (!aa.length) return;

    string[] garbage;

    // Mark
    foreach (/*immutable*/ key, value; aa)
    {
        static if (!is(typeof(pred) == typeof(null)))
        {
            import std.functional : binaryFun, unaryFun;

            alias unaryPred = unaryFun!pred;
            alias binaryPred = binaryFun!pred;

            static if (__traits(compiles, unaryPred(value)))
            {
                if (unaryPred(value)) garbage ~= key;
            }
            else static if (__traits(compiles, binaryPred(key, value)))
            {
                if (unaryPred(key, value)) garbage ~= key;
            }
            else
            {
                static assert(0, "Unknown predicate type passed to `pruneAA`");
            }
        }
        else
        {
            if (value == typeof(value).init)
            {
                garbage ~= key;
            }
        }
    }

    // Sweep
    foreach (immutable key; garbage)
    {
        aa.remove(key);
    }
}

///
unittest
{
    import std.conv : text;

    {
        auto aa =
        [
            "abc" : "def",
            "ghi" : "jkl",
            "mno" : "123",
            "pqr" : string.init,
        ];

        pruneAA!((a) => a == "def")(aa);
        assert("abc" !in aa);

        pruneAA!((a,b) => a == "pqr")(aa);
        assert("pqr" !in aa);

        pruneAA!`a == "123"`(aa);
        assert("mno" !in aa);
    }
    {
        struct Record
        {
            string name;
            int id;
        }

        auto aa =
        [
            "rhubarb" : Record("rhubarb", 100),
            "raspberry" : Record("raspberry", 80),
            "blueberry" : Record("blueberry", 0),
            "apples" : Record("green apples", 60),
            "yakisoba"  : Record("yakisoba", 78),
            "cabbage" : Record.init,
        ];

        pruneAA(aa);
        assert("cabbage" !in aa);

        pruneAA!((entry) => entry.id < 80)(aa);
        assert("blueberry" !in aa);
        assert("apples" !in aa);
        assert("yakisoba" !in aa);
        assert((aa.length == 2), aa.length.text);
    }
    {
        import std.algorithm.searching : canFind;

        string[][string] aa =
        [
            "abc" : [ "a", "b", "c" ],
            "def" : [ "d", "e", "f" ],
            "ghi" : [ "g", "h", "i" ],
            "jkl" : [ "j", "k", "l" ],
        ];

        pruneAA(aa);
        assert((aa.length == 4), aa.length.text);

        pruneAA!((entry) => entry.canFind("a"))(aa);
        assert("abc" !in aa);
    }
}
