/++
 +  Various compile-time traits, mostly for internal use.
 +/
module lu.traits;

import lu.uda;

import std.traits : Unqual, isArray, isAssociativeArray, isFunction, isType;
import std.typecons : Flag, No, Yes;


// isConfigurableVariable
/++
 +  Eponymous template bool of whether a variable can be configured via the
 +  functions in `lu.config` or not.
 +
 +  Currently it does not support static arrays.
 +
 +  Params:
 +      var = Alias of variable to introspect.
 +/
template isConfigurableVariable(alias var)
{
    static if (!isType!var)
    {
        import std.traits : isSomeFunction;

        alias T = typeof(var);

        enum isConfigurableVariable =
            !isSomeFunction!T &&
            !__traits(isTemplate, T) &&
            //!__traits(isAssociativeArray, T) &&
            !__traits(isStaticArray, T);
    }
    else
    {
        enum isConfigurableVariable = false;
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

    static assert(isConfigurableVariable!i);
    static assert(isConfigurableVariable!c);
    static assert(!isConfigurableVariable!c2); // should static arrays pass?
    static assert(!isConfigurableVariable!S);
    static assert(!isConfigurableVariable!C);
    static assert(!isConfigurableVariable!E);
    static assert(isConfigurableVariable!e);
}


// isOfAssignableType
/++
 +  Eponymous template bool of whether or not a variable is "assignable"; if it is
 +  an lvalue that isn't protected from being written to.
 +
 +  Params:
 +      T = Type to introspect.
 +/
template isOfAssignableType(T)
if (isType!T)
{
    import std.traits : isSomeFunction;

    enum isOfAssignableType = isType!T &&
        !isSomeFunction!T &&
        !__traits(isTemplate, T) &&
        !is(T == const) &&
        !is(T == immutable);
}


// isOfAssignableType
/++
 +  Eponymous template bool of whether or not a variable is "assignable"; if it is
 +  an lvalue that isn't protected from being written to.
 +
 +  Overload that takes an alias symbol instead of a normal template parameter.
 +
 +  Params:
 +      symbol = Symbol to introspect.
 +/
enum isOfAssignableType(alias symbol) = isType!symbol && is(symbol == enum);

///
unittest
{
    struct Foo
    {
        string bar, baz;
    }

    class Bar
    {
        int i;
    }

    void boo(int i) {}

    enum Baz { abc, def, ghi }
    Baz baz;

    static assert(isOfAssignableType!int);
    static assert(!isOfAssignableType!(const int));
    static assert(!isOfAssignableType!(immutable int));
    static assert(isOfAssignableType!(string[]));
    static assert(isOfAssignableType!Foo);
    static assert(isOfAssignableType!Bar);
    static assert(!isOfAssignableType!boo);  // room for improvement: @property
    static assert(isOfAssignableType!Baz);
    static assert(!isOfAssignableType!baz);
    static assert(isOfAssignableType!string);
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
    alias T = Unqual!QualT;

    enum hasElaborateInit = ()
    {
        bool match;

        T thing;  // need a `this`

        foreach (immutable i, member; thing.tupleof)
        {
            import std.traits : isSomeFunction, isType;

            static if (!__traits(isDeprecated, thing.tupleof[i]) &&
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
                else static if (T.init.tupleof[i] != MemberType.init)
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
if (isFunction!fun)
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
        import std.meta : Alias, AliasSeq, Filter;
        import std.traits : hasUDA;

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
                alias member = __traits(getMember, symbol, names[0]);

                // Filtering not compiled members such as alias of basic types.
                static if (!__traits(compiles, hasUDA!(member, attribute)))
                {
                    alias getSymbolsByUDAImpl = tail;
                }
                // Get overloads for functions, in case different overloads have different sets of UDAs.
                else static if (isFunction!member)
                {
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
