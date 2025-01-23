/++
    Functions used to generate strings of statements describing the differences
    (or delta) between two instances of a struct or class of the same type.
    They can be either assignment statements or assert statements.

    Example:
    ---
    struct Foo
    {
        string s;
        int i;
        bool b;
    }

    Foo altered;

    altered.s = "some string";
    altered.i = 42;
    altered.b = true;

    Appender!(char[]) sink;

    // Fill with delta between `Foo.init` and modified `altered`
    sink.putDelta!(No.asserts)(Foo.init, altered);

    assert(sink[] ==
    `s = "some string";
    i = 42;
    b = true;
    `);
    sink.clear();

    // Do the same but prepend the name "altered" to the member names
    sink.putDelta!(No.asserts)(Foo.init, altered, 0, "altered");

    assert(sink[] ==
    `altered.s = "some string";
    altered.i = 42;
    altered.b = true;
    `);
    sink.clear();

    // Generate assert statements instead, for easy copy/pasting into unittest blocks
    sink.putDelta!(Yes.asserts)(Foo.init, altered, 0, "altered");

    assert(sink[] ==
    `assert((altered.s == "some string"), altered.s);
    assert((altered.i == 42), altered.i.to!string);
    assert(altered.b, altered.b.to!string);
    `);
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.deltastrings;

private:

import std.typecons : Flag, No, Yes;

public:

import lu.uda : Hidden;

//@safe:


// putDelta
/++
    Constructs statement lines for each changed field (or the delta) between two
    instances of a struct and stores them into a passed output sink.

    Note: Renamed from [formatDeltaInto] to a name that makes sense with the
    order of arguments.

    Example:
    ---
    struct Foo
    {
        string s;
        int i;
        bool b;
    }

    Foo altered;

    altered.s = "some string";
    altered.i = 42;
    altered.b = true;

    Appender!(char[]) sink;
    sink.putDelta!(No.asserts)(Foo.init, altered);
    ---

    Params:
        asserts = Whether or not to build assert statements or assignment statements.
        sink = Output buffer to write to.
        before = Original struct object.
        after = Changed struct object.
        indents = The number of tabs to indent the lines with.
        submember = The string name of a recursing symbol, if applicable.
 +/
void putDelta(Flag!"asserts" asserts = No.asserts, Sink, QualThing)
    (auto ref Sink sink,
    auto ref QualThing before,
    auto ref QualThing after,
    const uint indents = 0,
    const string submember = string.init)
{
    import std.range.primitives : isOutputRange;
    import std.traits : isAggregateType;

    static if (!isAggregateType!QualThing)
    {
        enum message = "`putDelta` must be passed an aggregate type";
        static assert(0, message);
    }

    static if (!isOutputRange!(Sink, char[]))
    {
        enum message = "`putDelta` sink must be an output range accepting `char[]`";
        static assert(0, message);
    }

    immutable prefix = submember.length ? (submember ~ '.') : string.init;

    foreach (immutable i, ref member; after.tupleof)
    {
        import lu.traits : udaIndexOf;
        import lu.uda : Hidden;
        import std.traits :
            Unqual,
            isAggregateType,
            isArray,
            isSomeFunction,
            isSomeString,
            isType;

        alias T = Unqual!(typeof(member));
        enum memberstring = __traits(identifier, before.tupleof[i]);

        static if (udaIndexOf!(after.tupleof[i], Hidden) != -1)
        {
            // Member is annotated as Hidden; skip
            continue;
        }
        else static if (isAggregateType!T)
        {
            // Recurse
            sink.putDelta!asserts(before.tupleof[i], member, indents, prefix ~ memberstring);
        }
        else static if (!isType!member && !isSomeFunction!member && !__traits(isTemplate, member))
        {
            if (after.tupleof[i] != before.tupleof[i])
            {
                static if (isArray!T && !isSomeString!T)
                {
                    import std.range : ElementEncodingType;

                    // TODO: Rewrite this to recurse
                    alias E = ElementEncodingType!T;

                    static if (isSomeString!E)
                    {
                        static if (asserts)
                        {
                            enum pattern = "%sassert((%s%s[%d] == \"%s\"), %2$s%3$s[%4$d]);\n";
                        }
                        else
                        {
                            enum pattern = "%s%s%s[%d] = \"%s\";\n";
                        }
                    }
                    else static if (is(E == char))
                    {
                        static if (asserts)
                        {
                            enum pattern = "%sassert((%s%s[%d] == '%s'), %2$s%3$s[%4$d].to!string);\n";
                        }
                        else
                        {
                            enum pattern = "%s%s%s[%d] = '%s';\n";
                        }
                    }
                    else
                    {
                        static if (asserts)
                        {
                            enum pattern = "%sassert((%s%s[%d] == %s), %2$s%3$s[%4$d].to!string);\n";
                        }
                        else
                        {
                            enum pattern = "%s%s%s[%d] = %s;\n";
                        }
                    }
                }
                else static if (isSomeString!T)
                {
                    static if (asserts)
                    {
                        enum pattern = "%sassert((%s%s == \"%s\"), %2$s%3$s);\n";
                    }
                    else
                    {
                        enum pattern = "%s%s%s = \"%s\";\n";
                    }
                }
                else static if (is(T == char))
                {
                    static if (asserts)
                    {
                        enum pattern = "%sassert((%s%s == '%s'), %2$s%3$s.to!string);\n";
                    }
                    else
                    {
                        enum pattern = "%s%s%s = '%s';\n";
                    }
                }
                else static if (is(T == enum))
                {
                    enum typename = Unqual!QualThing.stringof ~ '.' ~ T.stringof;

                    static if (asserts)
                    {
                        enum pattern = "%sassert((%s%s == " ~ typename ~ ".%s), " ~
                            "%2$s%3$s.toString());\n";
                    }
                    else
                    {
                        enum pattern = "%s%s%s = " ~ typename ~ ".%s;\n";
                    }
                }
                else static if (is(T == bool))
                {
                    static if (asserts)
                    {
                        immutable pattern = member ?
                            "%sassert(%s%s);\n" :
                            "%sassert(!%s%s);\n";
                    }
                    else
                    {
                        enum pattern = "%s%s%s = %s;\n";
                    }
                }
                else
                {
                    static if (asserts)
                    {
                        enum pattern = "%sassert((%s%s == %s), %2$s%3$s.to!string);\n";
                    }
                    else
                    {
                        enum pattern = "%s%s%s = %s;\n";
                    }
                }

                import std.format : formattedWrite;
                import std.range : repeat;
                import std.string : join;

                immutable indentation = "    ".repeat(indents).join;

                static if (isSomeString!T)
                {
                    import std.array : replace;

                    immutable escaped = member
                        .replace('\\', `\\`)
                        .replace('"', `\"`);

                    sink.formattedWrite(pattern, indentation, prefix, memberstring, escaped);
                }
                else static if (isArray!T)
                {
                    foreach (n, val; member)
                    {
                        if (before.tupleof[i][n] == after.tupleof[i][n]) continue;
                        sink.formattedWrite(pattern, indentation, prefix, memberstring, n, member[n]);
                    }
                }
                else
                {
                    sink.formattedWrite(pattern, indentation, prefix, memberstring, member);
                }
            }
        }
        else
        {
            static assert(0, "Cannot produce deltastrings for type `%s`"
                .format(Unqual!QualThing.stringof));
        }
    }
}

///
unittest
{
    import lu.uda : Hidden;
    import std.array : Appender;

    Appender!(char[]) sink;
    sink.reserve(1024);

    struct Server
    {
        string address;
        ushort port;
        bool connected;
    }

    struct Connection
    {
        enum State
        {
            unset,
            disconnected,
            connected,
        }

        State state;
        string nickname;
        @Hidden string user;
        @Hidden string password;
        Server server;
    }

    Connection conn;

    with (conn)
    {
        state = Connection.State.connected;
        nickname = "NICKNAME";
        user = "USER";
        password = "hunter2";
        server.address = "address.tld";
        server.port = 1337;
    }

    sink.putDelta!(No.asserts)(Connection.init, conn, 0, "conn");

    assert(sink[] ==
`conn.state = Connection.State.connected;
conn.nickname = "NICKNAME";
conn.server.address = "address.tld";
conn.server.port = 1337;
`, '\n' ~ sink[]);

    sink.clear();

    sink.putDelta!(Yes.asserts)(Connection.init, conn, 0, "conn");

    assert(sink[] ==
`assert((conn.state == Connection.State.connected), conn.state.toString());
assert((conn.nickname == "NICKNAME"), conn.nickname);
assert((conn.server.address == "address.tld"), conn.server.address);
assert((conn.server.port == 1337), conn.server.port.to!string);
`, '\n' ~ sink[]);

    struct Foo
    {
        string s;
        int i;
        bool b;
        char c;
    }

    Foo f1;
    f1.s = "string";
    f1.i = 42;
    f1.b = true;
    f1.c = '$';

    Foo f2 = f1;
    f2.s = "yarn";
    f2.b = false;
    f2.c = '#';

    sink.clear();

    sink.putDelta!(No.asserts)(f1, f2);
    assert(sink[] ==
`s = "yarn";
b = false;
c = '#';
`, '\n' ~ sink[]);

    sink.clear();

    sink.putDelta!(Yes.asserts)(f1, f2);
    assert(sink[] ==
`assert((s == "yarn"), s);
assert(!b);
assert((c == '#'), c.to!string);
`, '\n' ~ sink[]);

    sink.clear();

    {
        struct S
        {
            int i;
        }

        class C
        {
            string s;
            bool b;
            S child;
        }

        C c1 = new C;
        C c2 = new C;

        c2.s = "harbl";
        c2.b = true;
        c2.child.i = 42;

        sink.putDelta!(No.asserts)(c1, c2);
        assert(sink[] ==
`s = "harbl";
b = true;
child.i = 42;
`, '\n' ~ sink[]);

        sink.clear();

        sink.putDelta!(Yes.asserts)(c1, c2);
        assert(sink[] ==
`assert((s == "harbl"), s);
assert(b);
assert((child.i == 42), child.i.to!string);
`, '\n' ~ sink[]);
    }
    {
        struct Blah
        {
            int[5] arr;
            string[3] sarr;
            char[2] carr;
        }

        Blah b1;
        Blah b2;
        b2.arr = [ 1, 0, 3, 0, 5 ];
        b2.sarr = [ "hello", string.init, "world" ];
        b2.carr = [ 'a', char.init ];

        sink.clear();

        sink.putDelta(b1, b2);
        assert(sink[] ==
`arr[0] = 1;
arr[2] = 3;
arr[4] = 5;
sarr[0] = "hello";
sarr[2] = "world";
carr[0] = 'a';
`);

        sink.clear();

        sink.putDelta!(Yes.asserts)(b1, b2);
        assert(sink[] ==
`assert((arr[0] == 1), arr[0].to!string);
assert((arr[2] == 3), arr[2].to!string);
assert((arr[4] == 5), arr[4].to!string);
assert((sarr[0] == "hello"), sarr[0]);
assert((sarr[2] == "world"), sarr[2]);
assert((carr[0] == 'a'), carr[0].to!string);
`);
    }
}


// formatDeltaInto
/++
    Alias of [putDelta].

    [formatDeltaInto] was renamed to [putDelta] that makes more sense with its
    order of arguments.

    TODO: Deprecate this later.
 +/
//deprecated("Use `lu.deltastrings.putDelta` instead")
alias formatDeltaInto = putDelta;
