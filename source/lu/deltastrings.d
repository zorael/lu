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
    sink.formatDeltaInto!(No.asserts)(Foo.init, altered);

    assert(sink.data ==
    `s = "some string";
    i = 42;
    b = true;
    `);
    sink.clear();

    // Do the same but prepend the name "altered" to the member names
    sink.formatDeltaInto!(No.asserts)(Foo.init, altered, 0, "altered");

    assert(sink.data ==
    `altered.s = "some string";
    altered.i = 42;
    altered.b = true;
    `);
    sink.clear();

    // Generate assert statements instead, for easy copy/pasting into unittest blocks
    sink.formatDeltaInto!(Yes.asserts)(Foo.init, altered, 0, "altered");

    assert(sink.data ==
    `assert((altered.s == "some string"), altered.s);
    assert((altered.i == 42), altered.i.to!string);
    assert(altered.b, altered.b.to!string);
    `);
    ---
 +/
module lu.deltastrings;

private:

import std.range.primitives : isOutputRange;
import std.traits : isAggregateType;
import std.typecons : Flag, No, Yes;

public:

@safe:


// formatDeltaInto
/++
    Constructs statement lines for each changed field (or the delta) between two
    instances of a struct and stores them into a passed output sink.

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
    sink.formatDeltaInto!(No.asserts)(Foo.init, altered);
    ---

    Params:
        asserts = Whether or not to build assert statements or assignment statements.
        sink = Output buffer to write to.
        before = Original struct object.
        after = Changed struct object.
        indents = The number of tabs to indent the lines with.
        submember = The string name of a recursing symbol, if applicable.
 +/
void formatDeltaInto(Flag!"asserts" asserts = No.asserts, Sink, QualThing)
    (auto ref Sink sink,
    auto ref QualThing before,
    auto ref QualThing after,
    const uint indents = 0,
    const string submember = string.init)
if (isOutputRange!(Sink, char[]) && isAggregateType!QualThing)
{
    immutable prefix = submember.length ? submember ~ '.' : string.init;

    foreach (immutable i, ref member; after.tupleof)
    {
        import lu.uda : Hidden;
        import std.traits : Unqual, hasUDA, isAggregateType, isSomeFunction, isSomeString, isType;

        alias T = Unqual!(typeof(member));
        enum memberstring = __traits(identifier, before.tupleof[i]);

        static if (hasUDA!(after.tupleof[i], Hidden))
        {
            // Member is annotated as Hidden; skip
            continue;
        }
        else static if (isAggregateType!T)
        {
            sink.formatDeltaInto!asserts(before.tupleof[i], member, indents, prefix ~ memberstring);
        }
        else static if (!isType!member && !isSomeFunction!member && !__traits(isTemplate, member))
        {
            if (after.tupleof[i] != before.tupleof[i])
            {
                static if (isSomeString!T)
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
                    import std.traits : fullyQualifiedName;

                    // We could use __traits(identifier, T) but we'd get
                    // State.connected instead of Connection.State.connected
                    enum typename = ()
                    {
                        import std.algorithm.searching : count;
                        import std.string : indexOf;

                        string typename = fullyQualifiedName!T;

                        while (typename.count('.') > 1)
                        {
                            typename = typename[typename.indexOf('.')+1..$];
                        }

                        return typename;
                    }().idup;

                    static if (asserts)
                    {
                        immutable pattern = "%sassert((%s%s == " ~ typename ~ ".%s), " ~
                            "Enum!(" ~ typename ~ ").toString(%2$s%3$s));\n";
                    }
                    else
                    {
                        immutable pattern = "%s%s%s = " ~ typename ~ ".%s;\n";
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

    sink.formatDeltaInto!(No.asserts)(Connection.init, conn, 0, "conn");

    assert(sink.data ==
`conn.state = Connection.State.connected;
conn.nickname = "NICKNAME";
conn.server.address = "address.tld";
conn.server.port = 1337;
`, '\n' ~ sink.data);

    sink = typeof(sink).init;

    sink.formatDeltaInto!(Yes.asserts)(Connection.init, conn, 0, "conn");

    assert(sink.data ==
`assert((conn.state == Connection.State.connected), Enum!(Connection.State).toString(conn.state));
assert((conn.nickname == "NICKNAME"), conn.nickname);
assert((conn.server.address == "address.tld"), conn.server.address);
assert((conn.server.port == 1337), conn.server.port.to!string);
`, '\n' ~ sink.data);

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

    sink = typeof(sink).init;

    sink.formatDeltaInto!(No.asserts)(f1, f2);
    assert(sink.data ==
`s = "yarn";
b = false;
c = '#';
`, '\n' ~ sink.data);

    sink = typeof(sink).init;

    sink.formatDeltaInto!(Yes.asserts)(f1, f2);
    assert(sink.data ==
`assert((s == "yarn"), s);
assert(!b);
assert((c == '#'), c.to!string);
`, '\n' ~ sink.data);

    sink = typeof(sink).init;

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

        sink.formatDeltaInto!(No.asserts)(c1, c2);
        assert(sink.data ==
`s = "harbl";
b = true;
child.i = 42;
`, '\n' ~ sink.data);

        sink = typeof(sink).init;

        sink.formatDeltaInto!(Yes.asserts)(c1, c2);
        assert(sink.data ==
`assert((s == "harbl"), s);
assert(b);
assert((child.i == 42), child.i.to!string);
`, '\n' ~ sink.data);
    }
}
