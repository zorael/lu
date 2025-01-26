/++
    Type constructors.

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.typecons;

private:

import std.typecons : Flag, No, Yes;

public:


// OpDispatcher
/++
    Mixin template generating an `opDispatch` redirecting calls to members whose
    names match the passed variable string but with a given token string in
    the front or at the end of the name.

    Params:
        token = The token to look for as part of the variable name, either in
            the front of it or at the end of it. May be any non-zero number of characters.
        inFront = Whether to look for the token in front of the variable name
            instead of at the end of it; defaults to `Yes.inFront`.
 +/
mixin template OpDispatcher(string token, Flag!"inFront" inFront = Yes.inFront)
{
    version(unittest)
    {
        import lu.traits : MixinConstraints, MixinScope;
        mixin MixinConstraints!(
            (MixinScope.struct_ | MixinScope.class_ | MixinScope.union_),
            typeof(this).stringof);
    }

    static if (!token.length)
    {
        import std.format : format;
        enum pattern = "Empty token passed to `%s.PrefixOpDispatcher`";
        enum message = pattern.format(typeof(this).stringof);
        static assert(0, message);
    }

    /++
        Mutator.

        Params:
            var = The variable name to set.
            value = The value to set the variable to.

        Returns:
            A reference to the object which this is mixed into.
     +/
    ref auto opDispatch(string var, T)(T value)
    {
        import std.traits : isArray, isAssociativeArray, isSomeString;

        static if (!var.length)
        {
            import std.format : format;
            enum pattern = "Empty variable name passed to `%s.opDispatch`";
            enum message = pattern.format(typeof(this).stringof);
            static assert(0, message);
        }

        enum realVar = inFront ?
            token ~ var :
            var ~ token;

        alias V = typeof(mixin(realVar));

        static if (isAssociativeArray!V)
        {
            import lu.meld : MeldingStrategy, meldInto;
            value.meldInto!(MeldingStrategy.overwriting)(mixin(realVar));
        }
        else static if (isArray!V && !isSomeString!V)
        {
            mixin(realVar) ~= value;
        }
        else
        {
            mixin(realVar) = value;
        }

        return this;
    }

    /++
        Accessor.

        Params:
            var = The variable name to get.

        Returns:
            The value of the variable.
     +/
    ref auto opDispatch(string var)() inout
    {
        static if (!var.length)
        {
            import std.format : format;
            enum pattern = "Empty variable name passed to `%s.opDispatch`";
            enum message = pattern.format(typeof(this).stringof);
            static assert(0, message);
        }

        enum realVar = inFront ?
            token ~ var :
            var ~ token;

        return mixin(realVar);
    }
}

///
unittest
{
    {
        static struct Foo
        {
            int _i;
            string _s;
            bool _b;
            string[] _add;
            alias wordList = _add;

            mixin OpDispatcher!("_", Yes.inFront);
        }

        Foo f;
        f.i = 42;         // f.opDispatch!"i"(42);
        f.s = "hello";    // f.opDispatch!"s"("hello");
        f.b = true;       // f.opDispatch!"b"(true);
        f.add("hello");   // f.opDispatch!"add"("hello");
        f.add("world");   // f.opDispatch!"add"("world");

        assert(f.i == 42);
        assert(f.s == "hello");
        assert(f.b);
        assert(f.wordList == [ "hello", "world" ]);

        // ref auto allows this
        ++f.i;
        assert(f.i == 43);

        /+
            Returns `this` by reference, so we can chain calls.
         +/
        auto f2 = Foo()
            .i(9001)
            .s("world")
            .b(false)
            .add("hi")
            .add("there");

        assert(f2.i == 9001);
        assert(f2.s == "world");
        assert(!f2.b);
        assert(f2.wordList == [ "hi", "there" ]);
    }
    {
        static struct  Foo
        {
            int i_private;
            string s_private;
            bool b_private = true;
            string[] add_private;
            alias wordList = add_private;

            mixin OpDispatcher!("_private", No.inFront);
        }

        Foo f;
        f.i = 9;
        f.s = "foo";
        f.b = false;
        f.add("bar");
        f.add("baz");

        assert(f.i == 9);
        assert(f.s == "foo");
        assert(!f.b);
        assert(f.wordList == [ "bar", "baz" ]);
    }
}


// UnderscoreOpDispatcher
/++
    Mixin template generating an `opDispatch` redirecting calls to members whose
    names match the passed variable string but with an underscore prepended to
    the name.

    This is a convenience mixin for `OpDispatcher!("_", Yes.inFront)`.

    Example:
    ---
    struct Bar
    {
        string _s;
        int _i;
        bool _b;
        string[string] _aa;

        mixin UnderscoreOpDispatcher;
    }
    ---

    See_Also:
        [OpDispatcher]
 +/
mixin template UnderscoreOpDispatcher()
{
    private import lu.typecons : OpDispatcher;
    mixin OpDispatcher!("_", Yes.inFront);
}

///
unittest
{
    static struct Bar
    {
        string _s;
        int _i;
        bool _b = true;
        string[string] _aa;
        mixin UnderscoreOpDispatcher;
    }

    Bar bar;
    bar.s = "hi there";
    bar.i = -123;
    bar.b = false;
    bar.aa = [ "hello" : "world" ];
    bar.aa = [ "foo" : "bar" ];
    assert(bar.aa == [ "hello" : "world", "foo" : "bar"]);
}
