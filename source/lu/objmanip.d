/++
    This module contains functions that in some way or another manipulates
    struct and class instances, as well as (associative) arrays.

    Example:
    ---
    struct Foo
    {
        string nickname;
        string address;
    }

    Foo foo;

    foo.setMemberByName("nickname", "foobar");
    foo.setMemberByName("address", "subdomain.address.tld");

    assert(foo.nickname == "foobar");
    assert(foo.address == "subdomain.address.tld");

    foo.replaceMembers("subdomain.address.tld", "foobar");
    assert(foo.address == "foobar");

    foo.replaceMembers("foobar", string.init);
    assert(foo.nickname.length == 0);
    assert(foo.address.length == 0);
    ---
 +/
module lu.objmanip;

private:

import std.traits : isAggregateType, isMutable;

public:


// setMemberByName
/++
    Given a struct/class object, sets one of its members by its string name to a
    specified value. Overload that takes the value as a string and tries to
    convert it into the target type.

    It does not currently recurse into other struct/class members.

    Example:
    ---
    struct Foo
    {
        string name;
        int number;
        bool alive;
    }

    Foo foo;

    foo.setMemberByName("name", "James Bond");
    foo.setMemberByName("number", "007");
    foo.setMemberByName("alive", "false");

    assert(foo.name == "James Bond");
    assert(foo.number == 7);
    assert(!foo.alive);
    ---

    Params:
        thing = Reference object whose members to set.
        memberToSet = String name of the thing's member to set.
        valueToSet = String contents of the value to set the member to; string
            even if the member is of a different type.

    Returns:
        `true` if a member was found and set, `false` if not.

    Throws: [std.conv.ConvException] if a string could not be converted into an
        array, if a passed string could not be converted into a bool, or if
        [std.conv.to] failed to convert a string into wanted type T.
 +/
bool setMemberByName(Thing)(ref Thing thing, const string memberToSet, const string valueToSet)
if (isAggregateType!Thing && isMutable!Thing)
in (memberToSet.length, "Tried to set member by name but no member string was given")
{
    import lu.string : stripSuffix, stripped, unquoted;
    import std.conv : ConvException, to;

    bool success;

    top:
    switch (memberToSet)
    {
    static foreach (immutable i; 0..thing.tupleof.length)
    {{
        alias QualT = typeof(thing.tupleof[i]);

        static if (!isMutable!QualT)
        {
            // Can't set const or immutable, so just ignore and break
            enum memberstring = __traits(identifier, thing.tupleof[i]);

            case memberstring:
                break top;
        }
        else
        {
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
                            static if (is(Unqual!(typeof(thisSeparator)) == Separator))
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


// setMemberByName
/++
    Given a struct/class object, sets one of its members by its string name to a
    specified value. Overload that takes a value of the same type as the target
    member, rather than a string to convert. Integer promotion applies.

    It does not currently recurse into other struct/class members.

    Example:
    ---
    struct Foo
    {
        int i;
        double d;
    }

    Foo foo;

    foo.setMemberByName("i", 42);
    foo.setMemberByName("d", 3.14);

    assert(foo.i == 42);
    assert(foo.d = 3.14);
    ---

    Params:
        thing = Reference object whose members to set.
        memberToSet = String name of the thing's member to set.
        valueToSet = Value, of the same type as the target member.

    Returns:
        `true` if a member was found and set, `false` if not.

    Throws: [MeldException] if the passed `valueToSet` was not the same type
        (or implicitly convertible to) the member to set.
 +/
bool setMemberByName(Thing, Val)(ref Thing thing, const string memberToSet, /*const*/ Val valueToSet)
if (isAggregateType!Thing && isMutable!Thing && !is(Val : string))
in (memberToSet.length, "Tried to set member by name but no member string was given")
{
    bool success;

    top:
    switch (memberToSet)
    {
    static foreach (immutable i; 0..thing.tupleof.length)
    {{
        alias QualT = typeof(thing.tupleof[i]);

        static if (!isMutable!QualT)
        {
            // Can't set const or immutable, so just ignore and break
            enum memberstring = __traits(identifier, thing.tupleof[i]);

            case memberstring:
                break top;
        }
        else
        {
            import lu.traits : isSerialisable;
            import std.traits : Unqual;

            alias T = Unqual!(typeof(thing.tupleof[i]));

            static if (isSerialisable!(thing.tupleof[i]))
            {
                enum memberstring = __traits(identifier, thing.tupleof[i]);

                case memberstring:
                {
                    static if (is(Val : T))
                    {
                        thing.tupleof[i] = valueToSet;
                        success = true;
                        break top;
                    }
                    else
                    {
                        import std.conv : to;
                        throw new SetMemberException("A set-member action failed " ~
                            "due to type mismatch", Thing.stringof, memberToSet,
                            valueToSet.to!string);
                    }
                }
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
    import std.conv : to;
    import std.exception : assertThrown;

    struct Foo
    {
        string s;
        int i;
        bool b;
        const double d;
    }

    Foo foo;

    bool success;

    success = foo.setMemberByName("s", "harbl");
    assert(success);
    assert((foo.s == "harbl"), foo.s);

    success = foo.setMemberByName("i", 42);
    assert(success);
    assert((foo.i == 42), foo.i.to!string);

    success = foo.setMemberByName("b", true);
    assert(success);
    assert(foo.b);

    success = foo.setMemberByName("d", 3.14);
    assert(!success);

    assertThrown!SetMemberException(foo.setMemberByName("b", 3.14));
}


@safe:


// SetMemberException
/++
    Exception, to be thrown when [setMemberByName] fails for some given reason.

    It is a normal [object.Exception] but with attached strings of the type name,
    name of member and the value that was attempted to set.
 +/
final class SetMemberException : Exception
{
    /// Name of type that was attempted to set the member of.
    string typeName;

    /// Name of the member that was attempted to set.
    string memberToSet;

    /// String representation of the value that was attempted to assign.
    string valueToSet;

    /++
        Create a new [SetMemberException], without attaching anything.
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }

    /++
        Create a new [SetMemberException], attaching extra set-member information.
     +/
    this(const string message,
        const string typeName,
        const string memberToSet,
        const string valueToSet,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);

        this.typeName = typeName;
        this.memberToSet = memberToSet;
        this.valueToSet = valueToSet;
    }
}


private import std.traits : isEqualityComparable;

// replaceMembers
/++
    Inspects a passed struct or class for members whose values match that of the
    passed `token`. Matches members are set to a replacement value, which is
    an optional parameter that defaults to the `.init` value of the token's type.

    Params:
        thing = Reference to a struct or class whose members to iterate over.
        token = What value to look for in members, be it a string or an integer
            or whatever; anything that can be compared to.
        replacement = What to assign matched values. Defaults to the `.init`
            of the matched type.
 +/
void replaceMembers(Thing, Token)(ref Thing thing, Token token,
    Token replacement = Token.init) pure nothrow @nogc
if (isAggregateType!Thing && isMutable!Thing && isEqualityComparable!Token)
{
    import std.range : ElementEncodingType, ElementType;
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
        else static if (isArray!T && (is(ElementEncodingType!T : Token) ||
            is(ElementType!T : Token)))
        {
            if ((member.length == 1) && (member[0] == token))
            {
                if (replacement == typeof(replacement).init)
                {
                    member = typeof(member).init;
                }
                else
                {
                    member[0] = replacement;
                }
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

    struct Flerp
    {
        string[] arr;
    }

    Flerp flerp;
    flerp.arr = [ "-" ];
    assert(flerp.arr.length == 1);
    flerp.replaceMembers("-");
    assert(!flerp.arr.length);
}


private import std.traits : isAssociativeArray;

// pruneAA
/++
    Iterates an associative array and deletes invalid entries, either if the value
    is in a default `.init` state or as per the optionally passed predicate.

    It is supposedly undefined behaviour to remove an associative array's fields
    when foreaching through it. So far we have been doing a simple mark-sweep
    garbage collection whenever we encounter this use-case in the code, so why
    not just make a generic solution instead and deduplicate code?

    Example:
    ---
    auto aa =
    [
        "abc" : "def",
        "ghi" : string.init;
        "mno" : "123",
        "pqr" : string.init,
    ];

    pruneAA(aa);

    assert("ghi" !in aa);
    assert("pqr" !in aa);

    pruneAA!((entry) => entry.length > 0)(aa);

    assert("abc" !in aa);
    assert("mno" !in aa);
    ---

    Params:
        pred = Optional predicate if special logic is needed to determine whether
            an entry is to be removed or not.
        aa = The associative array to modify.
 +/
void pruneAA(alias pred = null, AA)(ref AA aa)
if (isAssociativeArray!AA && isMutable!AA)
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
