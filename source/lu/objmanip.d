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

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.objmanip;

private:

import std.traits : isAggregateType, isEqualityComparable, isMutable;
import std.typecons : Flag, No, Yes;

public:


// Separator
/++
    Public import of [lu.uda.Separator].
 +/
/*public*/ import lu.uda : Separator;


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
        thing = Reference to object whose members to set.
        memberToSet = String name of member to set.
        valueToSet = Value to set the member to, in string form.

    Returns:
        `true` if a member was found and set, `false` if nothing was done.

    Throws: [std.conv.ConvException|ConvException] if a string could not be
        converted into an array, if a passed string could not be converted into
        a bool, or if [std.conv.to] failed to convert a string into wanted type `T`.
        [SetMemberException] if an unexpected exception was thrown.
 +/
auto setMemberByName(Thing)
    (ref Thing thing,
    const string memberToSet,
    const string valueToSet)
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

            alias T = Unqual!QualT;

            static if (isSerialisable!(thing.tupleof[i]))
            {
                enum memberstring = __traits(identifier, thing.tupleof[i]);

                case memberstring:
                {
                    import std.traits :
                        isAggregateType,
                        isArray,
                        isAssociativeArray,
                        isPointer,
                        isSomeString;

                    static if (isAggregateType!T)
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
                        import lu.traits : udaIndexOf;
                        import lu.uda : Separator;
                        import std.algorithm.iteration : splitter;
                        import std.array : replace;
                        import std.traits : getUDAs;

                        thing.tupleof[i].length = 0;

                        static if (udaIndexOf!(thing.tupleof[i], Separator) != -1)
                        {
                            alias separators = getUDAs!(thing.tupleof[i], Separator);
                        }
                        else static if (udaIndexOf!(thing.tupleof[i], string) != -1)
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

                        string values = valueToSet.replace("\\\\", doubleEscapePlaceholder);  // mutable

                        foreach (immutable thisSeparator; separators)
                        {
                            static if (is(Unqual!(typeof(thisSeparator)) == Separator))
                            {
                                enum escapedSeparator = '\\' ~ thisSeparator.token;
                                enum separator = thisSeparator.token;
                            }
                            else
                            {
                                enum escapedSeparator = '\\' ~ thisSeparator;
                                alias separator = thisSeparator;
                            }

                            values = values
                                .replace(escapedSeparator, escapedPlaceholder)
                                .replace(separator, ephemeralSeparator)
                                .replace(escapedPlaceholder, separator);
                        }

                        values = values
                            .replace(doubleEphemeral, ephemeralSeparator)
                            .replace(doubleEscapePlaceholder, "\\");

                        auto range = values.splitter(ephemeralSeparator);

                        foreach (immutable entry; range)
                        {
                            if (!entry.length) continue;

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

                                enum pattern = "Could not convert `%s.%s` array " ~
                                    "entry \"%s\" into `%s` (%s)";
                                immutable message = pattern.format(
                                    Thing.stringof.stripSuffix("Settings"),
                                    memberToSet,
                                    entry,
                                    T.stringof,
                                    e.msg);

                                throw new ConvException(message);
                            }
                            catch (Exception e)
                            {
                                import std.format : format;

                                enum pattern = "A set-member action failed: %s";
                                immutable message = pattern.format(e.msg);

                                throw new SetMemberException(message, Thing.stringof,
                                    memberToSet, values);
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
                        static if (__traits(compiles, valueToSet.to!T))
                        {
                            try
                            {
                                thing.tupleof[i] = valueToSet.stripped.unquoted.to!T;
                                success = true;
                            }
                            catch (ConvException e)
                            {
                                import std.format : format;

                                enum pattern = "Could not convert `%s.%s` text \"%s\" " ~
                                    "to a `%s` associative array (%s)";
                                immutable message = pattern.format(
                                    Thing.stringof.stripSuffix("Settings"),
                                    memberToSet,
                                    valueToSet.stripped.unquoted,
                                    T.stringof,
                                    e.msg);

                                throw new ConvException(message);
                            }
                            catch (Exception e)
                            {
                                import std.format : format;

                                enum pattern = "A set-member action failed (AA): %s";
                                immutable message = pattern.format(e.msg);

                                throw new SetMemberException(message, Thing.stringof,
                                    memberToSet, valueToSet.stripped.unquoted);
                            }
                        }
                        else
                        {
                            // Inconvertible AA, silently ignore
                        }
                    }
                    else static if (isPointer!T)
                    {
                        // Ditto for pointers
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
                            break;

                        case "false":
                        case "no":
                        case "off":
                        case "0":
                            thing.tupleof[i] = false;
                            break;

                        default:
                            import std.format : format;

                            enum pattern = "Invalid value for setting `%s.%s`: " ~
                                `could not convert "%s" to a boolean value`;
                            immutable message = pattern.format(
                                Thing.stringof.stripSuffix("Settings"),
                                memberToSet,
                                valueToSet);

                            throw new ConvException(message);
                        }

                        success = true;
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

                            enum pattern = "Invalid value for setting `%s.%s`: " ~
                                "could not convert \"%s\" to `%s` (%s)";
                            immutable message = pattern.format(
                                Thing.stringof.stripSuffix("Settings"),
                                memberToSet,
                                valueToSet,
                                T.stringof,
                                e.msg);

                            throw new ConvException(message);
                        }
                        catch (Exception e)
                        {
                            import std.format : format;

                            enum pattern = "A set-member action failed: %s";
                            immutable message = pattern.format(e.msg);

                            throw new SetMemberException(message, Thing.stringof,
                                memberToSet, valueToSet);
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

    {
        struct Foo
        {
            string bar;
            int baz;
            float* f;
            string[string] aa;

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

            @Separator(`\o/`)
            {
                string[] blurgh;
            }

            @(`\o/`)
            {
                int[] blargh;
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

        success = foo.setMemberByName("aa", `["abc":"def", "ghi":"jkl"]`);
        assert(success);
        assert((foo.aa == [ "abc":"def", "ghi":"jkl" ]), foo.aa.to!string);

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

        success = foo.setMemberByName("blurgh", "asdf\\\\o/fdsa\\\\\\o/hirr\\o/\\o/\\o/\\o/\\o/\\o/\\o/\\o/steff");
        assert(success);
        assert((foo.blurgh == [ "asdf\\o/fdsa\\", "hirr", "steff" ]), foo.blurgh.to!string);

        success = foo.setMemberByName("blargh", `1\o/2\o/3\o/4\o/5`);
        assert(success);
        assert((foo.blargh == [ 1, 2, 3, 4, 5 ]), foo.blargh.to!string);
    }
    {
        class C
        {
            string abc;
            int def;
        }

        C c = new C;
        bool success;

        success = c.setMemberByName("abc", "this is abc");
        assert(success);
        assert((c.abc == "this is abc"), c.abc);

        success = c.setMemberByName("def", "42");
        assert(success);
        assert((c.def == 42), c.def.to!string);
    }
    {
        import lu.conv : Enum;

        enum E { abc, def, ghi }

        struct S
        {
            E e = E.ghi;
        }

        S s;
        bool success;

        assert(s.e == E.ghi);
        success = s.setMemberByName("e", "def");
        assert(success);
        assert((s.e == E.def), Enum!E.toString(s.e));
    }
    {
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
        bool success;

        success = parent.setMemberByName("child", "flerp");
        assert(success);
        assert((parent.child.thing == "flerp"), parent.child.thing);
    }
    {
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

        ClassWithAssignableMember parent = new ClassWithAssignableMember;
        bool success;

        success = parent.setMemberByName("child", "flerp");
        assert(success);
        assert((parent.child.thing == "flerp"), parent.child.thing);
    }
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
    assert(foo.d == 3.14);
    ---

    Params:
        thing = Reference to object whose members to set.
        memberToSet = String name of member to set.
        valueToSet = Value, of the same type as the target member.

    Returns:
        `true` if a member was found and set, `false` if not.

    Throws: [SetMemberException] if the passed `valueToSet` was not the same type
        (or implicitly convertible to) the member to set.
 +/
auto setMemberByName(Thing, Val)
    (ref Thing thing,
    const string memberToSet,
    /*const*/ Val valueToSet)
if (isAggregateType!Thing &&
    isMutable!Thing &&
    !is(Val : string))
in (memberToSet.length, "Tried to set member by name but no member string was given")
{
    bool success;

    top:
    switch (memberToSet)
    {
    static foreach (immutable i; 0..thing.tupleof.length)
    {{
        alias QualT = typeof(thing.tupleof[i]);
        enum memberstring = __traits(identifier, thing.tupleof[i]);

        static if (!isMutable!QualT)
        {
            // Can't set const or immutable, so just ignore and break
            case memberstring:
                break top;
        }
        else
        {
            import lu.traits : isSerialisable;
            import std.traits : Unqual;

            alias T = Unqual!QualT;

            static if (isSerialisable!(thing.tupleof[i]))
            {
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
                        enum message = "A set-member action failed due to type mismatch";
                        throw new SetMemberException(message, Thing.stringof,
                            memberToSet, valueToSet.to!string);
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

    It is a normal [object.Exception|Exception] but with attached strings of
    the type name, name of member and the value that was attempted to set.
 +/
final class SetMemberException : Exception
{
    /++
        Name of type that was attempted to set the member of.
     +/
    string typeName;

    /++
        Name of the member that was attempted to set.
     +/
    string memberToSet;

    /++
        String representation of the value that was attempted to assign.
     +/
    string valueToSet;

    /++
        Creates a new [SetMemberException], without attaching anything.
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }

    /++
        Creates a new [SetMemberException], attaching extra set-member information.
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


// replaceMembers
/++
    Inspects a passed struct or class for members whose values match that of the
    passed `token`. Matches members are set to a replacement value, which is
    an optional parameter that defaults to the `.init` value of the token's type.

    Params:
        recurse = Whether or not to recurse into aggregate members.
        thing = Reference to a struct or class whose members to iterate over.
        token = What value to look for in members to determine if they should be
            replaced, be it a string or an integer or whatever; anything that
            can be compared to.
        replacement = What to assign matched values. Defaults to the `.init`
            of the matched type.
 +/
void replaceMembers(Flag!"recurse" recurse = No.recurse, Thing, Token)
    (ref Thing thing,
    Token token,
    Token replacement = Token.init) pure nothrow @nogc
if (isAggregateType!Thing &&
    isMutable!Thing &&
    isEqualityComparable!Token)
{
    import std.range : ElementEncodingType, ElementType;
    import std.traits : isAggregateType, isArray, isSomeString;

    foreach (immutable i, ref member; thing.tupleof)
    {
        alias T = typeof(member);

        static if (isAggregateType!T)
        {
            static if (recurse)
            {
                // Recurse
                member.replaceMembers!recurse(token, replacement);
            }
        }
        else static if (is(T : Token))
        {
            if (member == token)
            {
                member = replacement;
            }
        }
        else static if (
            isArray!T &&
            (is(ElementEncodingType!T : Token) || is(ElementType!T : Token)))
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
    import std.conv : to;

    struct Bar
    {
        string s = "content";
    }

    struct Foo
    {
        Bar b;
        string s = "more content";
    }

    {
        Foo foo1;
        Foo foo2;

        foo1.replaceMembers("-");
        assert(foo1 == foo2);

        foo2.s = "-";
        foo2.replaceMembers("-");
        assert(!foo2.s.length);

        foo2.b.s = "-";
        foo2.replaceMembers!(Yes.recurse)("-", "herblp");
        assert((foo2.b.s == "herblp"), foo2.b.s);
    }
    {
        Foo foo;
        foo.s = "---";
        foo.b.s = "---";

        foo.replaceMembers!(No.recurse)("---");
        assert(!foo.s.length);
        assert((foo.b.s == "---"), foo.b.s);

        foo.replaceMembers!(Yes.recurse)("---");
        assert(!foo.b.s.length);
    }
    {
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

        b1.replaceMembers!(Yes.recurse)("more content");
        assert(!b1.f.s.length, b1.f.s);
    }
    {
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
    {
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
}


// pruneAA
/++
    Deprecated public import of [lu.array.pruneAA]. Import it directly instead.
 +/
deprecated("Import `lu.array.pruneAA` directly")
/*public*/ import lu.array : pruneAA;
