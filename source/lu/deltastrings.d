/++
 +  Functions used to generate strings of statements describing the differences
 +  (or delta) between two instances of a struct. They can be either assignment
 +  statements or assert statements.
 +
 +  See the unit tests of `formatDeltaInto` for examples.
 +/
module lu.deltastrings;

private:

import std.typecons : Flag, No, Yes;
import std.range.primitives : isOutputRange;

public:

@safe:


// formatDeltaInto
/++
 +  Constructs statement lines for each changed field (or the delta) between two
 +  instances of a struct and stores them into a passed output sink.
 +
 +  Params:
 +      asserts = Whether or not to build assert statements or assignment statements.
 +      sink = Output buffer to write to.
 +      before = Original struct object.
 +      after = Changed struct object.
 +      indents = The number of tabs to indent the lines with.
 +      submember = The string name of a recursing symbol, if applicable.
 +/
void formatDeltaInto(Flag!"asserts" asserts = No.asserts, Sink, QualThing)
    (auto ref Sink sink, QualThing before, QualThing after,
    const uint indents = 0, const string submember = string.init)
if (isOutputRange!(Sink, char[]) && is(QualThing == struct))
{
    immutable prefix = submember.length ? submember ~ '.' : string.init;

    foreach (immutable i, ref member; after.tupleof)
    {
        import lu.uda : Hidden;
        import std.functional : unaryFun;
        import std.traits : Unqual, hasUDA, isSomeFunction, isSomeString, isType;

        alias Thing = Unqual!QualThing;
        alias T = Unqual!(typeof(member));
        enum memberstring = __traits(identifier, before.tupleof[i]);

        static if (hasUDA!(Thing.tupleof[i], Hidden))
        {
            // Member is annotated as Hidden; skip
            continue;
        }
        else static if (is(T == struct))
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
                    import lu.string : nom;
                    import std.algorithm.searching : count;
                    import std.traits : fullyQualifiedName;

                    string typename = fullyQualifiedName!T;
                    while (typename.count('.') > 1) typename.nom('.');

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

                import lu.string : tabs;
                import std.format : formattedWrite;

                static if (isSomeString!T)
                {
                    import std.array : replace;

                    immutable escaped = member
                        .replace('\\', `\\`)
                        .replace('"', `\"`);

                    sink.formattedWrite(pattern, indents.tabs, prefix, memberstring, escaped);
                }
                else
                {
                    sink.formattedWrite(pattern, indents.tabs, prefix, memberstring, member);
                }
            }
        }
        else
        {
            static assert(0, "Trying to format assignment delta of a %s, which can't be done".format(Thing.stringof));
        }
    }
}

///
unittest
{
    import std.array : Appender;

    Appender!string sink;
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
        string user;
        string password;
        Server server;
    }

    Connection conn;

    with (conn)
    {
        state = Connection.State.connected;
        nickname = "NICKNAME";
        user = "USER";
        server.address = "address.tld";
        server.port = 1337;
    }

    sink.formatDeltaInto!(No.asserts)(Connection.init, conn, 0, "conn");

    assert(sink.data ==
`conn.state = Connection.State.connected;
conn.nickname = "NICKNAME";
conn.user = "USER";
conn.server.address = "address.tld";
conn.server.port = 1337;
`, '\n' ~ sink.data);

    sink = typeof(sink).init;

    sink.formatDeltaInto!(Yes.asserts)(Connection.init, conn, 0, "conn");

    assert(sink.data ==
`assert((conn.state == Connection.State.connected), Enum!(Connection.State).toString(conn.state));
assert((conn.nickname == "NICKNAME"), conn.nickname);
assert((conn.user == "USER"), conn.user);
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
}