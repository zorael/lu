/++
 +  This module contains the `meldInto` functions; functions that take two
 +  structs or classes of the same type and combine them, creating a resulting
 +  object with the union of the members of both parents. Array and associative
 +  array variants exist too.
 +
 +  Example:
 +  ---
 +  struct Foo
 +  {
 +      string abc;
 +      string def;
 +      int i;
 +      float f;
 +      double d;
 +  }
 +
 +  Foo f1; // = new Foo;
 +  f1.abc = "ABC";
 +  f1.def = "DEF";
 +
 +  Foo f2; // = new Foo;
 +  f2.abc = "this won't get copied";
 +  f2.def = "neither will this";
 +  f2.i = 42;
 +  f2.f = 3.14f;
 +
 +  f2.meldInto(f1);
 +
 +  with (f1)
 +  {
 +      import std.math : isNaN;
 +
 +      assert(abc == "ABC");
 +      assert(def == "DEF");
 +      assert(i == 42);
 +      assert(f == 3.14f);
 +      assert(d.isNaN);
 +  }
 +  ---
 +/
module lu.meld;

private:

import lu.traits : isTrulyString;
import std.traits : isArray, isAssociativeArray;

public:


/++
 +  To what extent a source should overwrite a target when melding.
 +/
enum MeldingStrategy
{
    /++
     +  Takes care not to overwrite settings when either the source or the
     +  target is `.init`.
     +/
    conservative,

    /++
     +  Only considers the `init`-ness of the source, so as not to overwrite
     +  things with empty strings, but otherwise always considers the source to
     +  trump the target.
     +/
    aggressive,

    /++
     +  Works like aggressive but also always overwrites bools, regardless of
     +  falseness.
     +/
    overwriting,
}


/++
 +  UDA conveying that this member's value cannot or should not be melded.
 +/
struct Unmeldable;


// meldInto
/++
 +  Takes two structs or classes of the same type and melds them together,
 +  making the members a union of the two.
 +
 +  In the case of classes it only overwrites members in `intoThis` that are
 +  `typeof(member).init`, so only unset members get their values overwritten by
 +  the melding class. It also does not work with static members.
 +
 +  In the case of structs it also overwrites members that still have their
 +  default values, in cases where such is applicable.
 +
 +  Supply a template parameter `MeldingStrategy` to decide to which extent
 +  values are overwritten.
 +
 +  Example:
 +  ---
 +  struct Foo
 +  {
 +      string abc;
 +      int def;
 +      bool b = true;
 +  }
 +
 +  Foo foo, bar;
 +  foo.abc = "from foo"
 +  foo.b = false;
 +  bar.def = 42;
 +  foo.meldInto(bar);
 +
 +  assert(bar.abc == "from foo");
 +  assert(bar.def == 42);
 +  assert(!bar.b);  // false overwrote default value true
 +  ---
 +
 +  Params:
 +      strategy = To what extent the source object should overwrite set
 +          (non-`init`) values in the receiving object.
 +      meldThis = Object to meld (source).
 +      intoThis = Reference to object to meld (target).
 +/
void meldInto(MeldingStrategy strategy = MeldingStrategy.conservative, Thing)
    (Thing meldThis, ref Thing intoThis)
if ((is(Thing == struct) || is(Thing == class)) && (!is(intoThis == const) &&
    !is(intoThis == immutable)))
{
    import lu.traits : isAnnotated, hasElaborateInit;
    import std.traits : isArray, isAssignable, isPointer, isSomeString, isType,
        hasUnsharedAliasing;

    static if (is(Thing == struct) && !hasElaborateInit!Thing &&
        (strategy == MeldingStrategy.conservative))
    {
        if (meldThis == Thing.init)
        {
            // We're merging an .init with something, and .init does not have
            // any special default values. Nothing would get melded, so exit early.
            return;
        }

        static if (!hasUnsharedAliasing!Thing)
        {
            if (intoThis == Thing.init)
            {
                // Likewise we're merging into an .init, so just fast-path overwrite.
                intoThis = meldThis;
                return;
            }
        }
    }

    foreach (immutable i, ref targetMember; intoThis.tupleof)
    {
        static if (!isType!targetMember)
        {
            alias T = typeof(targetMember);

            static if (isAnnotated!(intoThis.tupleof[i], Unmeldable))
            {
                // Do nothing
            }
            else static if (is(T == struct) || is(T == class))
            {
                // Recurse
                meldThis.tupleof[i].meldInto!strategy(targetMember);
            }
            else static if (isAssignable!T)
            {
                // Overwriting strategy overwrites everything except where the
                // source is clearly `.init`.
                // Aggressive strategy works like overwriting except it doesn't
                // blindly overwrite struct bools.
                static if ((strategy == MeldingStrategy.overwriting) ||
                    (strategy == MeldingStrategy.aggressive))
                {
                    static if (is(T == float) || is(T == double))
                    {
                        import std.math : isNaN;

                        if (!meldThis.tupleof[i].isNaN)
                        {
                            targetMember = meldThis.tupleof[i];
                        }
                    }
                    else static if (is(T == bool))
                    {
                        static if (strategy == MeldingStrategy.overwriting)
                        {
                            // Non-discriminately overwrite bools
                            targetMember = meldThis.tupleof[i];
                        }
                        else static if (strategy == MeldingStrategy.aggressive)
                        {
                            static if (is(Thing == class))
                            {
                                // We cannot tell whether or not it has the same value as
                                // `Thing.init` does, as it would need to be instantiated.
                                // Assume overwrite?
                                targetMember = meldThis.tupleof[i];
                            }
                            else
                            {
                                if (targetMember == Thing.init.tupleof[i])
                                {
                                    targetMember = meldThis.tupleof[i];
                                }
                            }
                        }
                        else
                        {
                            static assert(0, "Logic error; unexpected `MeldingStrategy` " ~
                                "passed to struct/class `meldInto`");
                        }
                    }
                    else static if (isArray!T && !isSomeString!T)
                    {
                        // Pass on to array melder
                        meldThis.tupleof[i].meldInto!strategy(targetMember);
                    }
                    else static if (isAssociativeArray!T)
                    {
                        // Pass on to AA melder
                        meldThis.tupleof[i].meldInto!strategy(targetMember);
                    }
                    else static if (isPointer!T)
                    {
                        // Aggressive and/or overwriting, so just overwrite the pointer?
                        targetMember = meldThis.tupleof[i];
                    }
                    else static if (is(Thing == class))
                    {
                        // Can't compare with Thing.init.tupleof[i]
                        targetMember = meldThis.tupleof[i];
                    }
                    else
                    {
                        if (meldThis.tupleof[i] != Thing.init.tupleof[i])
                        {
                            targetMember = meldThis.tupleof[i];
                        }
                    }
                }
                // Conservative strategy takes care not to overwrite members
                // with non-`init` values.
                else static if (strategy == MeldingStrategy.conservative)
                {
                    static if (is(T == float) || is(T == double))
                    {
                        import std.math : isNaN;

                        if (targetMember.isNaN)
                        {
                            targetMember = meldThis.tupleof[i];
                        }
                    }
                    else static if (is(T == enum))
                    {
                        if (meldThis.tupleof[i] > targetMember)
                        {
                            targetMember = meldThis.tupleof[i];
                        }
                    }
                    else static if (is(T == string[]))
                    {
                        import std.algorithm.searching : canFind;

                        if (!targetMember.canFind(meldThis.tupleof[i]))
                        {
                            targetMember ~= meldThis.tupleof[i];
                        }
                    }
                    else static if (isArray!T && !isSomeString!T)
                    {
                        // Pass on to array melder
                        meldThis.tupleof[i].meldInto!strategy(targetMember);
                    }
                    else static if (isAssociativeArray!T)
                    {
                        // Pass on to AA melder
                        meldThis.tupleof[i].meldInto!strategy(targetMember);
                    }
                    else static if (isPointer!T)
                    {
                        // Conservative, so check if null and overwrite if so
                        if (!targetMember) targetMember = meldThis.tupleof[i];
                    }
                    else static if (is(T == bool))
                    {
                        static if (is(Thing == class))
                        {
                            // We cannot tell whether or not it has the same value as
                            // `Thing.init` does, as it would need to be instantiated.
                            // Assume overwrite?
                            targetMember = meldThis.tupleof[i];
                        }
                        else
                        {
                            if (targetMember == Thing.init.tupleof[i])
                            {
                                targetMember = meldThis.tupleof[i];
                            }
                        }
                    }
                    else
                    {
                        /+  This is tricksy for bools. A value of false could be
                            false, or merely unset. If we're not overwriting,
                            let whichever side is true win out? +/

                        static if (is(Thing == class))
                        {
                            if (targetMember == T.init)
                            {
                                targetMember = meldThis.tupleof[i];
                            }
                        }
                        else
                        {
                            if ((targetMember == T.init) ||
                                (targetMember == Thing.init.tupleof[i]))
                            {
                                targetMember = meldThis.tupleof[i];
                            }
                        }
                    }
                }
            }
            else
            {
                /*import std.traits : fullyQualifiedName;
                pragma(msg, '`' ~ T.stringof ~ "` `" ~
                    fullyQualifiedName!(meldThis.tupleof[i]) ~ "` is not meldable!");*/
            }
        }
    }
}

version(unittest)
{
    struct TestFoo
    {
        string abc;
        string def;
        int i;
        float f;
        double d;
        int[string] aa;
        int[] arr;
        int* ip;

        void blah() {}

        const string kek;
        immutable bool bur;

        this(bool bur)
        {
            kek = "uden lo";
            this.bur = bur;
        }
    }
}

///
unittest
{
    import std.conv : to;

    TestFoo f1; // = new TestFoo;
    f1.abc = "ABC";
    f1.def = "DEF";
    f1.aa = [ "abc" : 123, "ghi" : 789 ];
    f1.arr = [ 1, 0, 3, 0, 5 ];

    TestFoo f2; // = new TestFoo;
    f2.abc = "this won't get copied";
    f2.def = "neither will this";
    f2.i = 42;
    f2.f = 3.14f;
    f2.aa = [ "abc" : 999, "def" : 456 ];
    f2.arr = [ 0, 2, 0, 4 ];

    f2.meldInto(f1);

    with (f1)
    {
        import std.math : isNaN;

        assert((abc == "ABC"), abc);
        assert((def == "DEF"), def);
        assert((i == 42), i.to!string);
        assert((f == 3.14f), f.to!string);
        assert(d.isNaN, d.to!string);
        assert((aa == [ "abc" : 123, "def" : 456, "ghi" : 789 ]), aa.to!string);
        assert((arr == [ 1, 2, 3, 4, 5 ]), arr.to!string);
    }

    TestFoo f3; // new TestFoo;
    f3.abc = "abc";
    f3.def = "def";
    f3.i = 100_135;
    f3.f = 99.9f;
    f3.aa = [ "abc" : 123, "ghi" : 789 ];
    f3.arr = [ 1, 0, 3, 0, 5 ];

    TestFoo f4; // new TestFoo;
    f4.abc = "OVERWRITTEN";
    f4.def = "OVERWRITTEN TOO";
    f4.i = 0;
    f4.f = 0.1f;
    f4.d = 99.999;
    f4.aa = [ "abc" : 999, "def" : 456 ];
    f4.arr = [ 9, 2, 0, 4 ];

    f4.meldInto!(MeldingStrategy.aggressive)(f3);

    with (f3)
    {
        import std.math : approxEqual;

        assert((abc == "OVERWRITTEN"), abc);
        assert((def == "OVERWRITTEN TOO"), def);
        assert((i == 100_135), i.to!string); // 0 is int.init
        assert((f == 0.1f), f.to!string);
        assert(d.approxEqual(99.999), d.to!string);
        assert((aa == [ "abc" : 999, "def" : 456, "ghi" : 789 ]), aa.to!string);
        assert((arr == [ 9, 2, 3, 4, 5 ]), arr.to!string);
    }

    // Overwriting is just aggressive but always overwrites bools.

    struct User
    {
        enum Class { anyone, blacklist, whitelist, admin }
        string nickname;
        string alias_;
        string ident;
        string address;
        string login;
        bool special;
        Class class_;
    }

    User one;
    with (one)
    {
        nickname = "kameloso";
        ident = "NaN";
        address = "herpderp.net";
        special = false;
        class_ = User.Class.whitelist;
    }

    User two;
    with (two)
    {
        nickname = "kameloso^";
        alias_ = "Kameloso";
        address = "asdf.org";
        login = "kamelusu";
        special = true;
        class_ = User.Class.blacklist;
    }

    //import lu.conv : Enum;

    User twoCopy = two;

    one.meldInto!(MeldingStrategy.conservative)(two);
    with (two)
    {
        assert((nickname == "kameloso^"), nickname);
        assert((alias_ == "Kameloso"), alias_);
        assert((ident == "NaN"), ident);
        assert((address == "asdf.org"), address);
        assert((login == "kamelusu"), login);
        assert(special);
        assert(class_ == User.Class.whitelist);//, Enum!(User.Class).toString(class_));
    }

    one.class_ = User.Class.blacklist;

    one.meldInto!(MeldingStrategy.overwriting)(twoCopy);
    with (twoCopy)
    {
        assert((nickname == "kameloso"), nickname);
        assert((alias_ == "Kameloso"), alias_);
        assert((ident == "NaN"), ident);
        assert((address == "herpderp.net"), address);
        assert((login == "kamelusu"), login);
        assert(!special);
        assert(class_ == User.Class.blacklist);//, Enum!(User.Class).toString(class_));
    }

    struct EnumThing
    {
        enum Enum { unset, one, two, three }
        Enum enum_;
    }

    EnumThing e1;
    EnumThing e2;
    e2.enum_ = EnumThing.Enum.three;
    assert(e1.enum_ == EnumThing.Enum.init);//, Enum!(EnumThing.Enum).toString(e1.enum_));
    e2.meldInto(e1);
    assert(e1.enum_ == EnumThing.Enum.three);//, Enum!(EnumThing.Enum).toString(e1.enum_));

    struct WithArray
    {
        string[] arr;
    }

    WithArray w1, w2;
    w1.arr = [ "arr", "matey", "I'ma" ];
    w2.arr = [ "pirate", "stereotype", "unittest" ];
    w2.meldInto(w1);
    assert((w1.arr == [ "arr", "matey", "I'ma", "pirate", "stereotype", "unittest" ]), w1.arr.to!string);

    WithArray w3, w4;
    w3.arr = [ "arr", "matey", "I'ma" ];
    w4.arr = [ "arr", "matey", "I'ma" ];
    w4.meldInto(w3);
    assert((w3.arr == [ "arr", "matey", "I'ma" ]), w3.arr.to!string);

    struct Server
    {
        string address;
    }

    struct Bot
    {
        string nickname;
        Server server;
    }

    Bot b1, b2;
    b1.nickname = "kameloso";
    b1.server.address = "freenode.net";

    assert(!b2.nickname.length, b2.nickname);
    assert(!b2.server.address.length, b2.nickname);
    b1.meldInto(b2);
    assert((b2.nickname == "kameloso"), b2.nickname);
    assert((b2.server.address == "freenode.net"), b2.server.address);

    b2.nickname = "harbl";
    b2.server.address = "rizon.net";

    b2.meldInto!(MeldingStrategy.aggressive)(b1);
    assert((b1.nickname == "harbl"), b1.nickname);
    assert((b1.server.address == "rizon.net"), b1.server.address);

    class Class
    {
        static int i;
        string s;
        bool b;
    }

    Class abc = new Class;
    abc.i = 42;
    abc.s = "some string";
    abc.b = true;

    Class def = new Class;
    def.s = "other string";
    abc.meldInto(def);

    assert((def.i == 42), def.i.to!string);
    assert((def.s == "other string"), def.s);
    assert(def.b);

    abc.meldInto!(MeldingStrategy.aggressive)(def);
    assert((def.s == "some string"), def.s);

    struct Bools
    {
        bool a = true;
        bool b = false;
    }

    Bools bools1, bools2, inverted, backupInverted;

    bools2.a = false;

    inverted.a = false;
    inverted.b = true;
    backupInverted = inverted;

    bools2.meldInto(bools1);
    assert(!bools1.a);
    assert(!bools1.b);

    bools2.meldInto(inverted);
    assert(!inverted.a);
    assert(inverted.b);
    inverted = backupInverted;

    bools2.meldInto!(MeldingStrategy.overwriting)(inverted);
    assert(!inverted.a);
    assert(!inverted.b);
    inverted = backupInverted;

    struct Asdf
    {
        string nickname = "sadf";
        string server = "asdf.net";
    }

    Asdf a, b;
    a.server = "a";
    b.server = "b";
    b.meldInto!(MeldingStrategy.aggressive)(a);
    assert((a.server == "b"), a.server);

    a.server = "a";
    b.server = Asdf.init.server;
    b.meldInto!(MeldingStrategy.aggressive)(a);
    assert((a.server == "a"), a.server);

    struct Blah
    {
        int yes = 42;
        @Unmeldable int no = 24;
    }

    Blah blah1, blah2;
    blah1.yes = 5;
    blah1.no = 42;
    blah1.meldInto!(MeldingStrategy.aggressive)(blah2);
    assert((blah2.yes == 5), blah2.yes.to!string);
    assert((blah2.no == 24), blah2.no.to!string);
}


// meldInto (array)
/++
 +  Takes two arrays and melds them together, making a union of the two.
 +
 +  It only overwrites members that are `T.init`, so only unset
 +  fields get their values overwritten by the melding array. Supply a
 +  template parameter `MeldingStrategy.aggressive` to make it overwrite if the
 +  melding array's field is not `T.init`. Furthermore use
 +  `MeldingStrategy.overwriting` if working with bool members.
 +
 +  Example:
 +  ---
 +  int[] arr1 = [ 1, 2, 3, 0, 0, 0 ];
 +  int[] arr2 = [ 0, 0, 0, 4, 5, 6 ];
 +  arr1.meldInto!(MeldingStrategy.conservative)(arr2);
 +
 +  assert(arr2 == [ 1, 2, 3, 4, 5, 6 ]);
 +  ---
 +
 +  Params:
 +      strategy = To what extent the source object should overwrite set
 +          (non-`init`) values in the receiving object.
 +      meldThis = Array to meld (source).
 +      intoThis = Reference to the array to meld (target).
 +/
void meldInto(MeldingStrategy strategy = MeldingStrategy.conservative, Array1, Array2)
    (Array1 meldThis, ref Array2 intoThis) pure nothrow
if (isArray!Array1 && isArray!Array2 && !isTrulyString!Array1 && !isTrulyString!Array2 &&
    !is(Array2 == const) && !is(Array2 == immutable))
{
    import std.traits : isDynamicArray, isStaticArray;

    static if (isDynamicArray!Array2)
    {
        if (!meldThis.length)
        {
            // Source empty, just return
            return;
        }
        else if (!intoThis.length)
        {
            // Source has content but target empty, just inherit
            intoThis = meldThis.dup;
            return;
        }

        // Ensure there's room for all elements
        if (meldThis.length > intoThis.length) intoThis.length = meldThis.length;
    }
    else static if (isStaticArray!Array1 && isStaticArray!Array2)
    {
        static if (Array1.length == Array2.length)
        {
            if (meldThis == Array1.init)
            {
                // Source empty, just return
                return;
            }
            else if (intoThis == Array2.init)
            {
                // Source has content but target empty, just inherit
                intoThis = meldThis;  // value type, no need for .dup
                return;
            }
        }
        else
        {
            import std.format : format;
            static assert((Array2.length >= Array1.length),
                "Cannot meld a larger `%s` static array into a smaller `%s` static one"
                .format(Array1.stringof, Array2.stringof));
        }
    }
    else static if (isDynamicArray!Array1 && isStaticArray!Array2)
    {
        assert((meldThis.length <= Array2.length),
            "Cannot meld a larger dynamic array into a smaller static one");
    }
    else
    {
        import std.format : format;
        static assert(0, "Attempted to meld an unsupported array type: `%s` into `%s`"
            .format(Array1.stringof, Array2.stringof));
    }

    foreach (immutable i, const val; meldThis)
    {
        static if (strategy == MeldingStrategy.conservative)
        {
            if ((val != typeof(val).init) && (intoThis[i] == typeof(intoThis[i]).init))
            {
                intoThis[i] = val;
            }
        }
        else static if (strategy == MeldingStrategy.aggressive)
        {
            if (val != typeof(val).init)
            {
                intoThis[i] = val;
            }
        }
        else static if (strategy == MeldingStrategy.overwriting)
        {
            intoThis[i] = val;
        }
        else
        {
            static assert(0, "Logic error; unexpected `MeldingStrategy` passed to array `meldInto`");
        }
    }
}

///
unittest
{
    import std.conv : to;

    auto arr1 = [ 123, 0, 789, 0, 456, 0 ];
    auto arr2 = [ 0, 456, 0, 123, 0, 789 ];
    arr1.meldInto!(MeldingStrategy.conservative)(arr2);
    assert((arr2 == [ 123, 456, 789, 123, 456, 789 ]), arr2.to!string);

    auto yarr1 = [ 'Z', char.init, 'Z', char.init, 'Z' ];
    auto yarr2 = [ 'A', 'B', 'C', 'D', 'E', 'F' ];
    yarr1.meldInto!(MeldingStrategy.aggressive)(yarr2);
    assert((yarr2 == [ 'Z', 'B', 'Z', 'D', 'Z', 'F' ]), yarr2.to!string);

    auto harr1 = [ char.init, 'X' ];
    yarr1.meldInto(harr1);
    assert((harr1 == [ 'Z', 'X', 'Z', char.init, 'Z' ]), harr1.to!string);

    char[5] harr2 = [ '1', '2', '3', '4', '5' ];
    char[] harr3;
    harr2.meldInto(harr3);
    assert((harr2 == harr3), harr3.to!string);

    int[3] asdf;
    int[3] hasdf;
    asdf.meldInto(hasdf);

    int[] dyn = new int[2];
    int[3] stat;
    dyn.meldInto(stat);
}


// meldInto
/++
 +  Takes two associative arrays and melds them together, making a union of the two.
 +
 +  This is largely the same as the array-version `meldInto` but doesn't need
 +  the extensive template constraints it employs, so it might as well be kept separate.
 +
 +  Example:
 +  ---
 +  int[string] aa1 = [ "abc" : 42, "def" : -1 ];
 +  int[string] aa2 = [ "ghi" : 10, "jkl" : 7 ];
 +  arr1.meldInto(arr2);
 +
 +  assert("abc" in aa2);
 +  assert("def" in aa2);
 +  assert("ghi" in aa2);
 +  assert("jkl" in aa2);
 +  ---
 +
 +  Params:
 +      strategy = To what extent the source object should overwrite set
 +          (non-`init`) values in the receiving object.
 +      meldThis = Associative array to meld (source).
 +      intoThis = Reference to the associative array to meld (target).
 +/
void meldInto(MeldingStrategy strategy = MeldingStrategy.conservative, AA)
    (AA meldThis, ref AA intoThis) pure
if (isAssociativeArray!AA)
{
    if (!meldThis.length)
    {
        // Empty source
        return;
    }
    else if (!intoThis.length)
    {
        // Empty target, just assign
        intoThis = meldThis.dup;
        return;
    }

    foreach (immutable key, val; meldThis)
    {
        static if (strategy == MeldingStrategy.conservative)
        {
            if (val == typeof(val).init)
            {
                // Source value is .init; do nothing
                continue;
            }

            const target = key in intoThis;

            if (!target || (*target == typeof(*target).init))
            {
                // Target value doesn't exist or is .init; meld
                intoThis[key] = val;
            }
        }
        else static if ((strategy == MeldingStrategy.aggressive) ||
            (strategy == MeldingStrategy.overwriting))
        {
            import std.traits : ValueType;

            static if ((strategy == MeldingStrategy.overwriting) &&
                is(ValueType!AA == bool))
            {
                // Always overwrite
                intoThis[key] = val;
            }
            else
            {
                if (val != typeof(val).init)
                {
                    // Target value doesn't exist; meld
                    intoThis[key] = val;
                }
            }
        }
        else
        {
            static assert(0, "Logic error; unexpected `MeldingStrategy` passed to AA `meldInto`");
        }
    }
}

///
unittest
{
    bool[string] aa1;
    bool[string] aa2;

    aa1["a"] = true;
    aa1["b"] = false;
    aa2["c"] = true;
    aa2["d"] = false;

    assert("a" in aa1);
    assert("b" in aa1);
    assert("c" in aa2);
    assert("d" in aa2);

    aa1.meldInto!(MeldingStrategy.overwriting)(aa2);

    assert("a" in aa2);
    assert("b" in aa2);

    string[string] saa1;
    string[string] saa2;

    saa1["a"] = "a";
    saa1["b"] = "b";
    saa2["c"] = "c";
    saa2["d"] = "d";

    saa1.meldInto!(MeldingStrategy.conservative)(saa2);
    assert("a" in saa2);
    assert("b" in saa2);

    saa1["a"] = "A";
    saa1.meldInto!(MeldingStrategy.aggressive)(saa2);
    assert(saa2["a"] == "A");
}
