/++
    Type constructors.
 +/
module lu.typecons;

private:

public:


// UnderscoreOpDispatcher
/++
    Mixin template generating an `opDispatch` redirecting calls to members whose
    names match the passed variable string but with an underscore prepended.
 +/
mixin template UnderscoreOpDispatcher()
{
    version(unittest)
    {
        import lu.traits : MixinConstraints, MixinScope;
        mixin MixinConstraints!(
            (MixinScope.struct_ | MixinScope.class_ | MixinScope.union_),
            typeof(this).stringof);
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
        import std.traits : isArray, isSomeString;

        enum realVar = '_' ~ var;
        alias V = typeof(mixin(realVar));

        static if (isArray!V && !isSomeString!V)
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
    auto opDispatch(string var)() const
    {
        enum realVar = '_' ~ var;
        return mixin(realVar);
    }
}

///
unittest
{
    struct Foo
    {
        int _i;
        string _s;
        bool _b;
        string[] _add;
        alias wordList = _add;

        mixin UnderscoreOpDispatcher;
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

    /+
        Returns `this` by reference, so we can chain calls.
     +/
    auto f2 = Foo()
        .i(9001)
        .s("world")
        .b(false)
        .add("hello")
        .add("world");

    assert(f2.i == 9001);
    assert(f2.s == "world");
    assert(!f2.b);
    assert(f2.wordList == [ "hello", "world" ]);
}
