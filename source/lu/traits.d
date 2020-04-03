/++
 +  Various compile-time traits, mostly for internal use.
 +/
module lu.traits;

private:

import std.traits : isArray, isAssociativeArray, isSomeFunction, isType;
import std.typecons : Flag, No, Yes;

public:


// isSerialisable
/++
 +  Eponymous template bool of whether a variable can be treated as a mutable
 +  variable, like a fundamental integral, and thus be serialised.
 +
 +  Currently it does not support static arrays.
 +
 +  Params:
 +      sym = Alias of symbol to introspect.
 +/
template isSerialisable(alias sym)
{
    import std.traits : isType;

    static if (!isType!sym)
    {
        import std.traits : isSomeFunction;

        alias T = typeof(sym);

        enum isSerialisable =
            !isSomeFunction!T &&
            !__traits(isTemplate, T) &&
            //!__traits(isAssociativeArray, T) &&
            !__traits(isStaticArray, T);
    }
    else
    {
        enum isSerialisable = false;
    }
}

///
unittest
{
    int i;
    char[] c;
    char[8] c2;
    struct S {}
    class C {}
    enum E { foo }
    E e;

    static assert(isSerialisable!i);
    static assert(isSerialisable!c);
    static assert(!isSerialisable!c2); // should static arrays pass?
    static assert(!isSerialisable!S);
    static assert(!isSerialisable!C);
    static assert(!isSerialisable!E);
    static assert(isSerialisable!e);
}


// isAnnotated
/++
 +  True if the passed symbol is annotated with the passed User-defined Attribute,
 +  or by its string identifier. False otherwise.
 +
 +  Example:
 +  ---
 +  struct Fun;
 +
 +  bool unfun;
 +  @Fun bool fun;
 +  @("Fun") bool alsoFun;
 +
 +  static assert(isAnnotated!(fun, Fun));
 +  static assert(isAnnotated!(alsoFun, Fun));
 +  ---
 +
 +  Params:
 +      sym = Symbol to inspect.
 +      UDA = Annotation to look for.
 +/
template isAnnotated(alias sym, UDA)
{
    import std.traits : fullyQualifiedName, hasUDA;

    enum isAnnotated =
        hasUDA!(sym, UDA) ||
        hasUDA!(sym, __traits(identifier, UDA)) ||
        hasUDA!(sym, fullyQualifiedName!UDA);
}

///
unittest
{
    import lu.uda : Hidden, Unserialisable;

    @("Bar")
    struct Foo
    {
        bool configurable;
        @Unserialisable bool unserialisable_;
        @("Unserialisable") bool alsoUnserialisable;
    }

    @Foo
    struct Bar
    {
        bool visible;
        @Hidden bool hidden;
        @("Hidden") bool alsoHidden;
    }

    Foo f;
    Bar b;

    static assert (!isAnnotated!(b.visible, Hidden));
    static assert (isAnnotated!(b.hidden, Hidden));
    static assert (isAnnotated!(b.alsoHidden, Hidden));
    static assert (isAnnotated!(b.alsoHidden, "Hidden"));

    static assert (!isAnnotated!(f.configurable, Unserialisable));
    static assert (isAnnotated!(f.unserialisable_, Unserialisable));
    static assert (isAnnotated!(f.alsoUnserialisable, Unserialisable));
    static assert (isAnnotated!(f.alsoUnserialisable, "Unserialisable"));

    static assert (isAnnotated!(Bar, Foo));
    static assert (isAnnotated!(Foo, Bar));
    static assert (isAnnotated!(Foo, "Bar"));
}


// isAnnotated
/++
 +  True if the passed symbol is annotated with the passed User-defined Attribute
 +  fundamental literal. False otherwise.
 +
 +  Overload that takes the UDA as an alias and merely wraps `std.traits.hasUDA`.
 +
 +  Example:
 +  ---
 +  struct Fun;
 +
 +  bool unfun;
 +  @("Fun") bool fun;
 +
 +  static assert(!isAnnotated!(unfun, "Fun"));
 +  static assert(isAnnotated!(fun, "Fun"));
 +  ---
 +
 +  Params:
 +      sym = Symbol to inspect.
 +      UDA = Annotation to look for.
 +/
template isAnnotated(alias sym, alias UDA)
{
    import std.traits : getUDAs, hasUDA;
    enum isAnnotated = hasUDA!(sym, UDA);
}


// isTrulyString
/++
 +  True if a type is `string`, `dstring` or `wstring`; otherwise false.
 +
 +  Does not consider e.g. `char[]` a string, as `std.traits.isSomeString` does.
 +
 +  Params:
 +      S = String type to introspect.
 +/
enum isTrulyString(S) = is(S == string) || is(S == dstring) || is(S == wstring);

///
unittest
{
    static assert(isTrulyString!string);
    static assert(isTrulyString!dstring);
    static assert(isTrulyString!wstring);
    static assert(!isTrulyString!(char[]));
    static assert(!isTrulyString!(dchar[]));
    static assert(!isTrulyString!(wchar[]));
}


// UnqualArray
/++
 +  Given an array of qualified elements, aliases itself to one such of
 +  unqualified elements.
 +
 +  Params:
 +      QualArray = Qualified array type.
 +      QualType = Qualified type, element of `QualArray`.
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
 +  Given an associative array with elements that have a storage class, aliases
 +  itself to an associative array with elements without the storage classes.
 +
 +  Params:
 +      QualArray = Qualified associative array type.
 +      QualElem = Qualified type, element of `QualArray`.
 +      QualKey = Qualified type, key of `QualArray`.
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
 +  Given an associative array of arrays with a storage class, aliases itself to
 +  an associative array with array elements without the storage classes.
 +
 +  Params:
 +      QualArray = Qualified associative array type.
 +      QualElem = Qualified type, element of `QualArray`.
 +      QualKey = Qualified type, key of `QualArray`.
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
 +  Eponymous template that is true if the passed type is a struct.
 +
 +  Used with `std.meta.Filter`, which cannot take `is()` expressions.
 +
 +  Params:
 +      T = Type to introspect.
 +/
enum isStruct(T) = is(T == struct);


// TakesParams
/++
 +  Given a function and a tuple of types, evaluates whether that function could
 +  be called with that tuple as parameters. Qualifiers like `const` and
 +  `immutable` are skipped, which may make it a poor choice if dealing with
 +  functions that require such arguments.
 +
 +  It is merely syntactic sugar, using `std.meta` and `std.traits` behind the scenes.
 +
 +  Example:
 +  ---
 +  void noParams();
 +  bool boolParam(bool);
 +  string stringParam(string);
 +  float floatParam(float);
 +
 +  static assert(TakesParams!(noParams));
 +  static assert(TakesParams!(boolParam, bool));
 +  static assert(TakesParams!(stringParam, string));
 +  static assert(TakesParams!(floatParam, float));
 +  ---
 +
 +  Params:
 +      fun = Function to evaluate the parameters of.
 +      P = Variadic list of types to compare `fun`'s function parameters with.
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

    static assert(TakesParams!(foo));//, AliasSeq!()));
    static assert(TakesParams!(foo1, string));
    static assert(TakesParams!(foo2, string, int));
    static assert(TakesParams!(foo3, bool, bool, bool));

    static assert(!TakesParams!(foo, string));
    static assert(!TakesParams!(foo1, string, int));
    static assert(!TakesParams!(foo2, bool, bool, bool));
}


// stringofParams
/++
 +  Produces a string of the unqualified parameters of the passed function alias.
 +
 +  Example:
 +  ---
 +  void foo(bool b, int i, string s) {}
 +  static assert(stringofParams!foo == "bool, int, string");
 +  ---
 +
 +  Params:
 +      fun = A function alias to get the parameter string of.
 +/
template stringofParams(alias fun)
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


static if ((__VERSION__ == 2088L) || (__VERSION__ == 2089L))
{
    // getSymbolsByUDA
    /++
     +  Provide a pre-2.088 `std.traits.getSymbolsByUDA`.
     +
     +  The `std.traits.getSymbolsByUDA` in 2.088/2.089 is completely broken by having
     +  inserted a constraint to force it to only work on aggregates, which a module
     +  apparently isn't.
     +/
    template getSymbolsByUDA(alias symbol, alias attribute)
    //if (isAggregateType!symbol)  // <--
    {
        import std.traits : hasUDA;

        alias membersWithUDA = getSymbolsByUDAImpl!(symbol, attribute, __traits(allMembers, symbol));

        // if the symbol itself has the UDA, tack it on to the front of the list
        static if (hasUDA!(symbol, attribute))
        {
            alias getSymbolsByUDA = AliasSeq!(symbol, membersWithUDA);
        }
        else
        {
            alias getSymbolsByUDA = membersWithUDA;
        }
    }


    // getSymbolsByUDAImpl
    /++
     +  Implementation of `std.traits.getSymbolsByUDA`, copy/pasted.
     +/
    private template getSymbolsByUDAImpl(alias symbol, alias attribute, names...)
    {
        import std.meta : AliasSeq;

        static if (names.length == 0)
        {
            alias getSymbolsByUDAImpl = AliasSeq!();
        }
        else
        {
            alias tail = getSymbolsByUDAImpl!(symbol, attribute, names[1 .. $]);

            // Filtering inaccessible members.
            static if (!__traits(compiles, __traits(getMember, symbol, names[0])))
            {
                alias getSymbolsByUDAImpl = tail;
            }
            else
            {
                import std.traits : hasUDA, isFunction;

                alias member = __traits(getMember, symbol, names[0]);

                // Filtering not compiled members such as alias of basic types.
                static if (!__traits(compiles, hasUDA!(member, attribute)))
                {
                    alias getSymbolsByUDAImpl = tail;
                }
                // Get overloads for functions, in case different overloads have different sets of UDAs.
                else static if (isFunction!member)
                {
                    import std.meta : AliasSeq, Filter;

                    enum hasSpecificUDA(alias member) = hasUDA!(member, attribute);
                    alias overloadsWithUDA = Filter!(hasSpecificUDA, __traits(getOverloads, symbol, names[0]));
                    alias getSymbolsByUDAImpl = AliasSeq!(overloadsWithUDA, tail);
                }
                else static if (hasUDA!(member, attribute))
                {
                    alias getSymbolsByUDAImpl = AliasSeq!(member, tail);
                }
                else
                {
                    alias getSymbolsByUDAImpl = tail;
                }
            }
        }
    }
}
else
{
    // Merely forward to the real template.
    public import std.traits : getSymbolsByUDA;
}


// MixinScope
/++
 +  The types of scope into which a mixin template may be mixed in.
 +/
enum MixinScope
{
    function_,  /// Mixed in inside a function.
    class_,     /// Mixed in inside a class.
    struct_,    /// Mixed in inside a struct.
    module_,    /// Mixed in inside a module.
}


// CategoryName
/++
 +  Provides string representations of the category of a symbol, where such is not
 +  a fundamental primitive variable but a module, a function, a delegate,
 +  a class or a struct.
 +
 +  Acuratem module detection only works on compilers 2.087 and later, due to
 +  missing support for `__traits(isModule)`.
 +
 +  Example:
 +  ---
 +  module foo;
 +
 +  void bar() {}
 +
 +  alias categoryName = CategoryName!bar;
 +
 +  assert(categoryName.type == "function");
 +  assert(categoryName.name == "bar");
 +  assert(categoryName.fqn == "foo.bar");
 +  ---
 +
 +  Params:
 +      sym = Symbol to provide the strings for.
 +/
template CategoryName(alias sym)
{
    import std.traits : fullyQualifiedName;

    // type
    /++
     +  String representation of the category type of `sym`.
     +/
    enum type = ()
    {
        import std.traits : isDelegate, isFunction;

        static if ((__VERSION__ >= 2087L) && __traits(isModule, sym))
        {
            return "module";
        }
        else static if (isFunction!sym)
        {
            return "function";
        }
        else static if (isDelegate!sym)
        {
            return "delegate";
        }
        else static if (is(sym == class) || is(typeof(sym) == class))
        {
            return "class";
        }
        else static if (is(sym == struct) || is(typeof(sym) == struct))
        {
            return "struct";
        }
        else static if (__VERSION__ < 2087L)
        {
            return "module(?)";
        }
        else
        {
            return "(unknown)";
        }
    }();


    // name
    /++
     +  A short name for the symbol `sym` is an alias of.
     +/
    enum name = __traits(identifier, sym);


    // fqn
    /++
     +  The fully qualified name for the symbol `sym` is an alias of.
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

    static if (__VERSION__ >= 2087L)
    {
        static assert(Fm.type == "module");
    }
    else
    {
        static assert(Fm.type == "module(?)");
    }

    static assert(Fm.name == "traits");
    static assert(Fm.fqn == "lu.traits");
}


// MixinConstraints
/++
 +  Mixes in static constraints into another mixin template, to provide static
 +  guarantees that it is not mixed into a type of scope other than the one specified.
 +
 +  Using this you can ensure that a mixin template meant to be mixed into a
 +  class isn't mixed into a module-level scope, or into a function, etc.
 +
 +  Example:
 +  ---
 +  module foo;
 +
 +  mixin template Foo()
 +  {
 +      mixin MixinConstraints!("Foo", MixinScope.module_);  // Constrained to module-level scope
 +  }
 +
 +  mixin Foo;  // no problem, scope is MixinScope.module_
 +
 +  void bar()
 +  {
 +      mixin Foo;  // static assert(0): scope is MixinScope.function_, not MixinScope.module_
 +  }
 +
 +  class C
 +  {
 +      mixin Foo;  // static assert(0): ditto but MixinScope.class_
 +  }
 +
 +  struct C
 +  {
 +      mixin Foo;  // static assert(0): ditto but MixinScope.struct_
 +  }
 +  ---
 +
 +  Params:
 +      mixinScope = The scope into which to only allow the mixin to be mixed in.
 +          All other kinds of scopes will be statically rejected.
 +      mixinName = Optional string name of the mixing-in mixin.
 +          Can be anything; it's just used for the error messages.
 +/
mixin template MixinConstraints(MixinScope mixinScope, string mixinName = "a constrained mixin")
{
private:
    import lu.traits : CategoryName, MixinScope;
    import std.format : format;

    /// Sentinel value as anchor to get the parent scope from.
    enum mixinSentinel = true;

    alias mixinParent = __traits(parent, mixinSentinel);
    alias mixinParentInfo = CategoryName!mixinParent;

    static if (mixinScope == MixinScope.function_)
    {
        import std.traits : isSomeFunction;

        static if (!isSomeFunction!mixinParent)
        {
            static assert(0, ("%s `%s` mixes in `%s` but it is only supposed to be " ~
                "mixed into a function")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else static if (mixinScope == MixinScope.class_)
    {
        static if(!is(mixinParent == class))
        {
            static assert(0, ("%s `%s` mixes in `%s` but it is only supposed to be " ~
                "mixed into a class")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else static if (mixinScope == MixinScope.struct_)
    {
        static if(!is(mixinParent == struct))
        {
            static assert(0, ("%s `%s` mixes in `%s` but it is only supposed to be " ~
                "mixed into a struct")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else static if (mixinScope == MixinScope.module_)
    {
        static if (__VERSION__ < 2087L)
        {
            import std.traits : isSomeFunction;

            static if (isSomeFunction!mixinParent ||
                is(mixinParent == class) ||
                is(mixinParent == struct))
            {
                static assert(0, ("%s `%s` mixes in `%s` but it is only supposed to be " ~
                    "mixed into a module-level scope")
                    .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
            }
        }
        else static if (!__traits(isModule, mixinParent))
        {
            static assert(0, ("%s `%s` mixes in `%s` but it is only supposed to be " ~
                "mixed into a module-level scope")
                .format(mixinParentInfo.type, mixinParentInfo.fqn, mixinName));
        }
    }
    else
    {
        static assert(0, "Logic error; unexpected member of `MixinScope`");
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

    class C
    {
        // MixinConstraints!(MixinScope.class_, "TestMixinConstrainedToClass");
        mixin TestMixinConstrainedToClass;
    }

    struct S
    {
        // mixin MixinConstraints!(MixinScope.struct_, "TestMixinConstrainedToStruct");
        mixin TestMixinConstrainedToStruct;
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
}


// isMutableArrayOfImmutables
/++
 +  Evaluates whether or not a passed array type is a mutable array of immutable
 +  elements, such as a string.
 +
 +  Params:
 +      Array = Array to inspect.
 +/
enum isMutableArrayOfImmutables(Array : Element[], Element) =
    !is(Array == immutable) && is(Element == immutable);

///
unittest
{
    static assert(isMutableArrayOfImmutables!string);
    static assert(isMutableArrayOfImmutables!wstring);
    static assert(isMutableArrayOfImmutables!dstring);
    static assert(!isMutableArrayOfImmutables!(immutable(string)));

    static assert(isMutableArrayOfImmutables!(immutable(int)[]));
    static assert(!isMutableArrayOfImmutables!(immutable(int[])));
}


// hasElaborateInit
/++
 +  Eponymous template that is true if the passed type has default values to
 +  any of its fields.
 +
 +  Params:
 +      QualT = Qualified struct type to introspect for elaborate .init.
 +/
template hasElaborateInit(QualT)
if (is(QualT == struct))
{
    import std.traits : Unqual, isType;

    alias T = Unqual!QualT;

    enum hasElaborateInit = ()
    {
        bool match;

        T thing;  // need a `this`

        foreach (immutable i, member; thing.tupleof)
        {
            import std.traits : isEqualityComparable, isSomeFunction, isType;

            static if (
                !__traits(isDeprecated, thing.tupleof[i]) &&
                !isType!(thing.tupleof[i]) &&
                !isSomeFunction!(thing.tupleof[i]) &&
                !__traits(isTemplate, thing.tupleof[i]))
            {
                alias MemberType = typeof(thing.tupleof[i]);

                static if (is(MemberType == float) || is(MemberType == double))
                {
                    import std.math : isNaN;
                    match = !member.isNaN;
                }
                else static if (isEqualityComparable!T && (
                        T.init.tupleof[i] != MemberType.init))
                {
                    match = true;
                }

                if (match) break;
            }
        }

        return match;
    }();
}

///
unittest
{
    struct NoDefaultValues
    {
        string s;
        int i;
        bool b;
        float f;
    }

    struct HasDefaultValues
    {
        string s;
        int i = 42;
        bool b;
        float f;
    }

    struct HasDefaultValuesToo
    {
        string s;
        int i;
        bool b;
        float f = 3.14f;
    }

    struct HasDefaultValuesThree
    {
        string s;
        int i;
        bool b;
        double d = 99.9;
    }

    static assert(!hasElaborateInit!NoDefaultValues);
    static assert(hasElaborateInit!HasDefaultValues);
    static assert(hasElaborateInit!HasDefaultValuesToo);
    static assert(hasElaborateInit!HasDefaultValuesThree);
}
