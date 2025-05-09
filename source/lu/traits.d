/++
    Various compile-time traits and cleverness.

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.traits;

private:

import std.traits : isArray, isAssociativeArray, isSomeFunction, isType;
import std.meta : allSatisfy, templateNot;

public:


// MixinScope
/++
    The types of scope into which a mixin template may be mixed in.
 +/
enum MixinScope
{
    function_  = 1 << 0,  /// Mixed into a function.
    class_     = 1 << 1,  /// Mixed into a class.
    struct_    = 1 << 2,  /// Mixed into a struct.
    interface_ = 1 << 3,  /// Mixed into an interface.
    union_     = 1 << 4,  /// Mixed into a union.
    module_    = 1 << 5,  /// Mixed into a module.
}


// MixinConstraints
/++
    Mixes in constraints into another mixin template, to provide static
    guarantees that it is not mixed into a type of scope other than the one specified.

    Using this you can ensure that a mixin template meant to be mixed into a
    class isn't mixed into a module-level scope, or into a function, etc.

    More than one scope type can be supplied with bitwise OR.

    Example:
    ---
    module foo;

    mixin template Foo()
    {
        mixin MixinConstraints!(MixinScope.module_, "Foo");  // Constrained to module-level scope
    }

    mixin Foo;  // no problem, scope is MixinScope.module_

    void bar()
    {
        mixin Foo;  // static assert(0): scope is MixinScope.function_, not MixinScope.module_
    }

    class C
    {
        mixin Foo;  // static assert(0): ditto but MixinScope.class_
    }

    struct C
    {
        mixin Foo;  // static assert(0): ditto but MixinScope.struct_
    }

    mixin template FooStructOrClass()
    {
        mixin MixinConstraints(MixinScope.struct_ | MixinScope.class_);
    }
    ---

    Params:
        mixinScope = The scope into which to only allow the mixin to be mixed in.
            All other kinds of scopes will be statically rejected.
        mixinName = Optional string name of the mixing-in mixin.
            Can be anything; it's just used for the error messages.

    See_Also:
        [MixinScope]
 +/
mixin template MixinConstraints(MixinScope mixinScope, string mixinName = "a constrained mixin")
{
private:
    import lu.traits : CategoryName, MixinScope;
    import std.traits : fullyQualifiedName, isSomeFunction;

    // https://forum.dlang.org/post/sk4hqm$12cf$1@digitalmars.com
    alias mixinParent = __traits(parent, {});

    static if (isSomeFunction!mixinParent)
    {
        static if (!(mixinScope & MixinScope.function_))
        {
            import std.format : format;
            alias mixinParentInfo = CategoryName!mixinParent;
            static assert(0, ("%s `%s` mixes in `%s` but it is not supposed to be " ~
                "mixed into a function")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else static if (is(mixinParent == class))
    {
        static if (!(mixinScope & MixinScope.class_))
        {
            import std.format : format;
            alias mixinParentInfo = CategoryName!mixinParent;
            static assert(0, ("%s `%s` mixes in `%s` but it is not supposed to be " ~
                "mixed into a class")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else static if (is(mixinParent == struct))
    {
        static if (!(mixinScope & MixinScope.struct_))
        {
            import std.format : format;
            alias mixinParentInfo = CategoryName!mixinParent;
            static assert(0, ("%s `%s` mixes in `%s` but it is not supposed to be " ~
                "mixed into a struct")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else static if (is(mixinParent == interface))
    {
        static if (!(mixinScope & MixinScope.interface_))
        {
            import std.format : format;
            alias mixinParentInfo = CategoryName!mixinParent;
            static assert(0, ("%s `%s` mixes in `%s` but it is not supposed to be " ~
                "mixed into an interface")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else static if (is(mixinParent == union))
    {
        static if (!(mixinScope & MixinScope.union_))
        {
            import std.format : format;
            alias mixinParentInfo = CategoryName!mixinParent;
            static assert(0, ("%s `%s` mixes in `%s` but it is not supposed to be " ~
                "mixed into a union")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else static if (__traits(isModule, mixinParent))
    {
        static if (!(mixinScope & MixinScope.module_))
        {
            import std.format : format;
            alias mixinParentInfo = CategoryName!mixinParent;
            static assert(0, ("%s `%s` mixes in `%s` but it is not supposed to be " ~
                "mixed into a module-level scope")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else
    {
        import std.format : format;
        static assert(0, "Logic error; unexpected scope type of parent of mixin `%s`: `%s`"
            .format(mixinName, fullyQualifiedName!mixinParent));
    }
}

///
unittest
{
    void fun()
    {
        // MixinConstraints!(MixinScope.function_, "TestMixinConstrainedToFunctions");
        mixin TestMixinConstrainedToFunctions;
    }

    class TestClassC
    {
        // MixinConstraints!(MixinScope.class_, "TestMixinConstrainedToClass");
        mixin TestMixinConstrainedToClass;
    }

    struct TestStructS
    {
        // mixin MixinConstraints!(MixinScope.struct_, "TestMixinConstrainedToStruct");
        mixin TestMixinConstrainedToStruct;
    }

    struct TestStructS2
    {
        mixin TestMixinConstrainedToClassOrStruct;
    }
}

version(unittest)
{
    mixin template TestMixinConstrainedToFunctions()
    {
        mixin MixinConstraints!(MixinScope.function_, "TestMixinConstrainedToFunctions");
    }

    mixin template TestMixinConstrainedToClass()
    {
        mixin MixinConstraints!(MixinScope.class_, "TestMixinConstrainedToClass");
    }

    mixin template TestMixinConstrainedToStruct()
    {
        mixin MixinConstraints!(MixinScope.struct_, "TestMixinConstrainedToStruct");
    }

    mixin template TestMixinConstrainedToClassOrStruct()
    {
        mixin MixinConstraints!((MixinScope.class_ | MixinScope.struct_),
            "TestMixinConstrainedToClassOrStruct");
    }

    mixin template TestMixinConstrainedToModule()
    {
        mixin MixinConstraints!((MixinScope.module_),
            "TestMixinConstrainedToModule");
    }

    mixin TestMixinConstrainedToModule;
}


// CategoryName
/++
    Provides string representations of the category of a symbol, where such is not
    a fundamental primitive variable but a module, a function, a delegate,
    a class or a struct.

    Example:
    ---
    module foo;

    void bar() {}

    alias categoryName = CategoryName!bar;

    assert(categoryName.type == "function");
    assert(categoryName.name == "bar");
    assert(categoryName.fqn == "foo.bar");
    ---

    Params:
        sym = Symbol to provide the strings for.
 +/
template CategoryName(alias sym)
{
    import std.traits : isDelegate, isFunction;

    // type
    /++
        String representation of the category type of `sym`.
     +/
    static if (isFunction!sym)
    {
        enum type = "function";
    }
    else static if (isDelegate!sym)
    {
        enum type = "delegate";
    }
    else static if (is(sym == class) || is(typeof(sym) == class))
    {
        enum type = "class";
    }
    else static if (is(sym == struct) || is(typeof(sym) == struct))
    {
        enum type = "struct";
    }
    else static if (is(sym == interface) || is(typeof(sym) == interface))
    {
        enum type = "interface";
    }
    else static if (is(sym == union) || is(typeof(sym) == union))
    {
        enum type = "union";
    }
    else static if (__traits(isModule, sym))
    {
        enum type = "module";
    }
    else
    {
        // Not quite sure when this could happen
        enum type = "some";
    }


    // name
    /++
        A short name for the symbol `sym` is an alias of.
     +/
    enum name = __traits(identifier, sym);


    // fqn
    /++
        The fully qualified name for the symbol `sym` is an alias of.
     +/
    enum fqn = fullyQualifiedName!sym;
}

///
unittest
{
    bool localSymbol;

    void fn() {}

    auto dg = () => localSymbol;

    class C {}
    C c;

    struct S {}
    S s;

    interface I {}

    union U
    {
        int i;
        bool b;
    }

    U u;

    alias Ffn = CategoryName!fn;
    static assert(Ffn.type == "function");
    static assert(Ffn.name == "fn");
    // Can't test fqn from inside a unittest

    alias Fdg = CategoryName!dg;
    static assert(Fdg.type == "delegate");
    static assert(Fdg.name == "dg");
    // Ditto

    alias Fc = CategoryName!c;
    static assert(Fc.type == "class");
    static assert(Fc.name == "c");
    // Ditto

    alias Fs = CategoryName!s;
    static assert(Fs.type == "struct");
    static assert(Fs.name == "s");

    alias Fm = CategoryName!(lu.traits);
    static assert(Fm.type == "module");
    static assert(Fm.name == "traits");
    static assert(Fm.fqn == "lu.traits");

    alias Fi = CategoryName!I;
    static assert(Fi.type == "interface");
    static assert(Fi.name == "I");

    alias Fu = CategoryName!u;
    static assert(Fu.type == "union");
    static assert(Fu.name == "u");
}


// TakesParams
/++
    Given a function and a tuple of types, evaluates whether that function could
    be called with that tuple as parameters. Alias version (works on functions,
    not function types.)

    Qualifiers like `const` and`immutable` are skipped, which may make it a poor
    choice if dealing with functions that require such arguments.

    It is merely syntactic sugar, using [std.meta] and [std.traits] behind the scenes.

    Example:
    ---
    void noParams();
    bool boolParam(bool);
    string stringParam(string);
    float floatParam(float);

    static assert(TakesParams!(noParams));
    static assert(TakesParams!(boolParam, bool));
    static assert(TakesParams!(stringParam, string));
    static assert(TakesParams!(floatParam, float));
    ---

    Params:
        fun = Function to evaluate the parameters of.
        P = Variadic list of types to compare `fun`'s function parameters with.
 +/
template TakesParams(alias fun, P...)
if (isSomeFunction!fun)
{
    import std.traits : Parameters, Unqual, staticMap;

    alias FunParams = staticMap!(Unqual, Parameters!fun);
    alias PassedParams = staticMap!(Unqual, P);

    static if (is(FunParams : PassedParams))
    {
        enum TakesParams = true;
    }
    else
    {
        enum TakesParams = false;
    }
}

///
unittest
{
    void foo();
    void foo1(string);
    void foo2(string, int);
    void foo3(bool, bool, bool);

    static assert( TakesParams!(foo));//, AliasSeq!()));
    static assert( TakesParams!(foo1, string));
    static assert( TakesParams!(foo2, string, int));
    static assert( TakesParams!(foo3, bool, bool, bool));
    static assert(!TakesParams!(foo, string));
    static assert(!TakesParams!(foo1, string, int));
    static assert(!TakesParams!(foo2, bool, bool, bool));
}


// TakesParams
/++
    Given a function and a tuple of types, evaluates whether that function could
    be called with that tuple as parameters. Non-alias version (works on types).

    Qualifiers like `const` and `immutable` are skipped, which may make it a
    poor choice if dealing with functions that require such arguments.

    It is merely syntactic sugar, using [std.meta] and [std.traits] behind the scenes.

    Example:
    ---
    void noParams();
    bool boolParam(bool);
    string stringParam(string);
    float floatParam(float);

    alias N = typeof(noParams);
    alias B = typeof(boolParam);
    alias S = typeof(stringParam);
    alias F = typeof(floatParam);

    static assert(TakesParams!N);
    static assert(TakesParams!(B, bool));
    static assert(TakesParams!(S, string));
    static assert(TakesParams!(F, float));
    ---

    Params:
        Fun = Type of function to evaluate the parameters of.
        P = Variadic list of types to compare `Fun` function parameters with.
 +/
template TakesParams(Fun, P...)
if (isSomeFunction!Fun)
{
    import std.traits : Parameters, Unqual, staticMap;

    alias FunParams = staticMap!(Unqual, Parameters!Fun);
    alias PassedParams = staticMap!(Unqual, P);

    static if (is(FunParams : PassedParams))
    {
        enum TakesParams = true;
    }
    else
    {
        enum TakesParams = false;
    }
}

///
unittest
{
    void foo();
    void foo1(string);
    void foo2(string, int);
    void foo3(bool, bool, bool);

    alias F = typeof(foo);
    alias F1 = typeof(foo1);
    alias F2 = typeof(foo2);
    alias F3 = typeof(foo3);

    static assert( TakesParams!F);//, AliasSeq!()));
    static assert( TakesParams!(F1, string));
    static assert( TakesParams!(F2, string, int));
    static assert( TakesParams!(F3, bool, bool, bool));
    static assert(!TakesParams!(F, string));
    static assert(!TakesParams!(F1, string, int));
    static assert(!TakesParams!(F2, bool, bool, bool));
}


// isSerialisable
/++
    Eponymous template bool of whether a variable can be treated as a mutable
    variable, like a fundamental integral, and thus be serialised.
    Overload that takes a non-type symbol.

    Params:
        sym = Alias of symbol to introspect.
 +/
template isSerialisable(alias sym)
if (!isType!sym)
{
    enum isSerialisable = isSerialisable!(typeof(sym));
}

///
unittest
{
    enum E { a, b, c }

    E e;
    string s;
    int i;
    char[] c;
    char[8] c2;

    static assert( isSerialisable!e);
    static assert( isSerialisable!s);
    static assert( isSerialisable!i);
    static assert( isSerialisable!c);
    static assert(!isSerialisable!c2);
}


// isSerialisable
/++
    Eponymous template bool of whether a variable can be treated as a mutable
    variable, like a fundamental integral, and thus be serialised.
    Overload that takes a type.

    Params:
        T = Type to introspect.
 +/
template isSerialisable(T)
if (isType!T)
{
    enum isSerialisable =
        !isSomeFunction!T &&
        !__traits(isTemplate, T) &&
        //!__traits(isAssociativeArray, T) &&
        !__traits(isStaticArray, T);
}

///
unittest
{
    enum E { a, b, c }
    struct S {}
    class C {}

    static assert( isSerialisable!S);
    static assert( isSerialisable!C);
    static assert( isSerialisable!E);
    static assert( isSerialisable!(char[]));
    static assert(!isSerialisable!(char[8]));
}


// isTrulyString
/++
    True if a type is `string`, `dstring` or `wstring`; otherwise false.

    Does not consider e.g. `char[]` a string, as
    [std.traits.isSomeString|isSomeString] does.

    Params:
        S = String type to introspect.

    See_Also:
        [isMerelyArray]
 +/
enum isTrulyString(S) = is(S == string) || is(S == dstring) || is(S == wstring);

///
unittest
{
    static assert( isTrulyString!string);
    static assert( isTrulyString!dstring);
    static assert( isTrulyString!wstring);
    static assert(!isTrulyString!(char[]));
    static assert(!isTrulyString!(dchar[]));
    static assert(!isTrulyString!(wchar[]));
}


// isMerelyArray
/++
    True if a type is a non-string array; otherwise false.

    For now also evaluates to true for static arrays.

    Params:
        S = Array type to introspect.

    See_Also:
        [isTrulyString]
 +/
enum isMerelyArray(S) = isArray!S && !isTrulyString!S;

///
unittest
{
    static assert(!isMerelyArray!string);
    static assert(!isMerelyArray!dstring);
    static assert(!isMerelyArray!wstring);
    static assert( isMerelyArray!(char[]));
    static assert( isMerelyArray!(dchar[]));
    static assert( isMerelyArray!(wchar[]));
    static assert( isMerelyArray!(int[5]));
}


// UnqualArray
/++
    Given an array of qualified elements, aliases itself to one such of
    unqualified elements.

    Params:
        QualArray = Qualified array type.
        QualType = Qualified type, element of `QualArray`.

    See_Also:
        [std.traits.Unqual]
 +/
template UnqualArray(QualArray : QualType[], QualType)
if (!isAssociativeArray!QualType)
{
    import std.traits : Unqual;

    alias UnqualArray = Unqual!QualType[];
}

///
unittest
{
    alias ConstStrings = const(string)[];
    alias UnqualStrings = UnqualArray!ConstStrings;
    static assert(is(UnqualStrings == string[]));

    alias ImmChars = string;
    alias UnqualChars = UnqualArray!ImmChars;
    static assert(is(UnqualChars == char[]));

    alias InoutBools = inout(bool)[];
    alias UnqualBools = UnqualArray!InoutBools;
    static assert(is(UnqualBools == bool[]));

    alias ConstChars = const(char)[];
    alias UnqualChars2 = UnqualArray!ConstChars;
    static assert(is(UnqualChars2 == char[]));
}


// UnqualArray
/++
    Given an associative array with elements that have a storage class, aliases
    itself to an associative array with elements without the storage classes.

    Params:
        QualArray = Qualified associative array type.
        QualElem = Qualified type, element of `QualArray`.
        QualKey = Qualified type, key of `QualArray`.

    See_Also:
        [std.traits.Unqual]
 +/
template UnqualArray(QualArray : QualElem[QualKey], QualElem, QualKey)
if (!isArray!QualElem)
{
    import std.traits : Unqual;

    alias UnqualArray = Unqual!QualElem[Unqual!QualKey];
}

///
unittest
{
    alias ConstStringAA = const(string)[int];
    alias UnqualStringAA = UnqualArray!ConstStringAA;
    static assert (is(UnqualStringAA == string[int]));

    alias ImmIntAA = immutable(int)[char];
    alias UnqualIntAA = UnqualArray!ImmIntAA;
    static assert(is(UnqualIntAA == int[char]));

    alias InoutBoolAA = inout(bool)[long];
    alias UnqualBoolAA = UnqualArray!InoutBoolAA;
    static assert(is(UnqualBoolAA == bool[long]));

    alias ConstCharAA = const(char)[string];
    alias UnqualCharAA = UnqualArray!ConstCharAA;
    static assert(is(UnqualCharAA == char[string]));
}


// UnqualArray
/++
    Given an associative array of arrays with a storage class, aliases itself to
    an associative array with array elements without the storage classes.

    Params:
        QualArray = Qualified associative array type.
        QualElem = Qualified type, element of `QualArray`.
        QualKey = Qualified type, key of `QualArray`.

    See_Also:
        [std.traits.Unqual]
 +/
template UnqualArray(QualArray : QualElem[QualKey], QualElem, QualKey)
if (isArray!QualElem)
{
    import std.traits : Unqual;

    static if (isTrulyString!(Unqual!QualElem))
    {
        alias UnqualArray = Unqual!QualElem[Unqual!QualKey];
    }
    else
    {
        alias UnqualArray = UnqualArray!QualElem[Unqual!QualKey];
    }
}

///
unittest
{
    alias ConstStringArrays = const(string[])[int];
    alias UnqualStringArrays = UnqualArray!ConstStringArrays;
    static assert (is(UnqualStringArrays == string[][int]));

    alias ImmIntArrays = immutable(int[])[char];
    alias UnqualIntArrays = UnqualArray!ImmIntArrays;
    static assert(is(UnqualIntArrays == int[][char]));

    alias InoutBoolArrays = inout(bool)[][long];
    alias UnqualBoolArrays = UnqualArray!InoutBoolArrays;
    static assert(is(UnqualBoolArrays == bool[][long]));

    alias ConstCharArrays = const(char)[][string];
    alias UnqualCharArrays = UnqualArray!ConstCharArrays;
    static assert(is(UnqualCharArrays == char[][string]));
}


// isStruct
/++
    Eponymous template that is `true` if the passed type is a struct.

    Used with [std.meta.Filter], which cannot take `is()` expressions.

    Params:
        T = Type to introspect.
 +/
enum isStruct(T) = is(T == struct);


// stringofParams
/++
    Produces a string of the unqualified parameters of the passed function alias.

    Example:
    ---
    void foo(bool b, int i, string s) {}
    static assert(stringofParams!foo == "bool, int, string");
    ---

    Params:
        fun = A function alias to get the parameter string of.
 +/
template stringofParams(alias fun)
if (isSomeFunction!fun)
{
    import std.traits : Parameters, Unqual, staticMap;

    alias FunParams = staticMap!(Unqual, staticMap!(Unqual, Parameters!fun));
    enum stringofParams = FunParams.stringof[1..$-1];
}

///
unittest
{
    void foo();
    void foo1(string);
    void foo2(string, int);
    void foo3(bool, bool, bool);

    enum ofFoo = stringofParams!foo;
    enum ofFoo1 = stringofParams!foo1;
    enum ofFoo2 = stringofParams!foo2;
    enum ofFoo3 = stringofParams!foo3;

    static assert(!ofFoo.length, ofFoo);
    static assert((ofFoo1 == "string"), ofFoo1);
    static assert((ofFoo2 == "string, int"), ofFoo2);
    static assert((ofFoo3 == "bool, bool, bool"), ofFoo3);
}


// isMutableArrayOfImmutables
/++
    Evaluates whether or not a passed array type is a mutable array of immutable
    elements, such as a string.

    Params:
        Array = Array to inspect.
 +/
enum isMutableArrayOfImmutables(Array : Element[], Element) =
    !is(Array == immutable) && is(Element == immutable);

///
unittest
{
    static assert( isMutableArrayOfImmutables!string);
    static assert( isMutableArrayOfImmutables!wstring);
    static assert( isMutableArrayOfImmutables!dstring);
    static assert(!isMutableArrayOfImmutables!(immutable(string)));
    static assert( isMutableArrayOfImmutables!(immutable(int)[]));
    static assert(!isMutableArrayOfImmutables!(immutable(int[])));
}


// udaIndexOf
/++
    Returns the index of a given UDA, as annotated on a symbol.

    Params:
        symbol = Symbol to introspect.
        T = UDA to get the index of.

    Returns:
        The index of the UDA if found, or `-1` if it was not present.

    See_Also:
        [std.traits.hasUDA]
        [std.traits.getSymbolsByUDA]
 +/
enum udaIndexOf(alias symbol, T) = ()
{
    /// Silence dscanner by adding this ddoc.
    ptrdiff_t index = -1;

    foreach (immutable i, uda; __traits(getAttributes, symbol))
    {
        static if (is(typeof(uda)))
        {
            alias U = typeof(uda);
        }
        else
        {
            alias U = uda;
        }

        static if (is(U == T))
        {
            index = i;
            break;
        }
    }

    return index;
}();

///
unittest
{
    enum UDA;
    enum UDA2;

    @UDA
    @UDA2
    @(42)
    static void foo() {}

    int i;

    static assert(udaIndexOf!(foo, UDA) == 0);
    static assert(udaIndexOf!(foo, UDA2) == 1);
    static assert(udaIndexOf!(foo, int) == 2);
    static assert(udaIndexOf!(foo, string) == -1);
    static assert(udaIndexOf!(i, UDA) == -1);
}


// stringOfTypeOf
/++
    The string representation of a type. Non-alias parameter overload.

    Should logically be called `stringOf`, but it's meant to make it easy to get
    the string types of a mixture of types and symbols.

    Params:
        T = Type to get the string representation of.

    Returns:
        The string representation of the type.
 +/
enum stringOfTypeOf(T) = T.stringof;

///
unittest
{
    static struct Foo {}
    static struct Bar {}

    assert(stringOfTypeOf!Foo == "Foo");
    assert(stringOfTypeOf!Bar == "Bar");
}


// stringOfTypeOf
/++
    The string representation of the type of something. Alias parameter overload.

    Params:
        T = Symbol whose type to get the string representation of.

    Returns:
        The string representation of the type.
 +/
enum stringOfTypeOf(alias T) = typeof(T).stringof;

///
unittest
{
    static struct Foo {}

    Foo foo;
    int i;
    alias n = int;

    static assert(stringOfTypeOf!foo == "Foo");
    static assert(stringOfTypeOf!i == "int");
    static assert(stringOfTypeOf!n == "int");
}


// isImplicitlyConvertibleToSize_t
/++
    Aliases itself to whether or not a type is implicitly convertible to `size_t`.

    For use with [std.meta.Filter], [std.traits.allSatisfy] and similar,
    which cannot take `is()` expressions.
 +/
template isImplicitlyConvertibleToSize_t(T)
if (isType!T)
{
    enum isImplicitlyConvertibleToSize_t = is(T : size_t);
}

///
unittest
{
    enum E { a, b, c }

    static assert( isImplicitlyConvertibleToSize_t!int);
    static assert( isImplicitlyConvertibleToSize_t!char);
    static assert( isImplicitlyConvertibleToSize_t!size_t);
    static assert(!isImplicitlyConvertibleToSize_t!string);
    static assert(!isImplicitlyConvertibleToSize_t!(int[]));
    static assert( isImplicitlyConvertibleToSize_t!E);
}


// isImplicitlyConvertibleToSize_t
/++
    Aliases itself to whether or not a symbol is of a type that is implicitly
    convertible to `size_t`.

    For use with [std.meta.Filter], [std.traits.allSatisfy] and similar,
    which cannot take `is()` expressions.
 +/
template isImplicitlyConvertibleToSize_t(alias T)
if (!isType!T)
{
    enum isImplicitlyConvertibleToSize_t = is(typeof(T) : size_t);
}

///
unittest
{
    enum E { a, b, c }

    int i;
    char c;
    size_t s_t;
    string s;
    int[] arr;

    static assert( isImplicitlyConvertibleToSize_t!i);
    static assert( isImplicitlyConvertibleToSize_t!c);
    static assert( isImplicitlyConvertibleToSize_t!s_t);
    static assert(!isImplicitlyConvertibleToSize_t!s);
    static assert(!isImplicitlyConvertibleToSize_t!arr);
    static assert( isImplicitlyConvertibleToSize_t!(E.a));
}


// isEnum
/++
    Aliases itself to whether or not a type is an enum.

    For use with [std.meta.Filter], [std.traits.allSatisfy] and similar,
    which cannot take `is()` expressions.
 +/
template isEnum(T)
if (isType!T)
{
    enum isEnum = is(T == enum);
}

///
unittest
{
    enum E { a, b, c }

    static assert( isEnum!E);
    static assert(!isEnum!int);
    static assert(!isEnum!string);
}


// isEnum
/++
    Aliases itself to whether or not a symbol is of a type is an enum.

    For use with [std.meta.Filter], [std.traits.allSatisfy] and similar,
    which cannot take `is()` expressions.
 +/
template isEnum(alias T)
if (!isType!T)
{
    enum isEnum = is(typeof(T) == enum);
}

///
unittest
{
    enum E { a, b, c}

    int i;
    char c;
    size_t s_t;
    string s;
    int[] arr;

    static assert(!isEnum!i);
    static assert(!isEnum!c);
    static assert(!isEnum!s_t);
    static assert(!isEnum!s);
    static assert(!isEnum!arr);
    static assert( isEnum!(E.a));
    static assert( isEnum!(E.c));
}


// allOfSameType
/++
    Aliases itself to whether or not all passed values are of the same type.

    A copy of [std.traits.allSameType] but modified to accept values rather than types.

    Params:
        values = Variadic list of values to compare.

    See_Also:
        [std.traits.allSameType]
 +/
template allOfSameType(values...)
if (allSatisfy!(templateNot!isType, values))
{
    enum allOfSameType = ()
    {
        static foreach (value; values[values.length > 1..__dollar])
        {
            static if (!is(typeof(values[0]) == typeof(value)))
            {
                if (__ctfe) return false;
            }
        }

        return true;
    }();
}
