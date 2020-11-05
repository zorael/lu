/++
    Templates that deal with constructing types, and ancillary helpers to such.
 +/
module lu.typecons;

private:

import std.traits : isAggregateType;

public:


// Imprint
/++
    Mixin that copies all normal value types of a passed aggregate type into the mixin site scope.

    Default values are carried over with structs, but not with classes and interfaces
    (as `T.init` is a valid value for structs but `null` in the case of classes).

    Deliberately does not enforce a mixin constraint, so as to be useful if someone
    ever wants to copy an aggregate's fields into a function.

    Examples:
    ---
    struct Base
    {
        enum E { A, B, C }

        E enum_;
        string s = "hello";
        int i = 42;
        float f = 3.14f;  // this value is lost
        bool b = true;
        Base* copy;
    }

    struct Derived
    {
        mixin Imprint!Base;
        bool b = false;  // overrides
    }
    ---

    Params:
        T = Type to copy members of.
 +/
mixin template Imprint(T)
if (isAggregateType!T)
{
    private import std.traits : fullyQualifiedName, isSomeFunction;

    static foreach (immutable i, immutable memberstring; __traits(derivedMembers, T))
    {
        static if (
            is(typeof(__traits(getMember, T, memberstring))) &&
            !__traits(hasMember, typeof(this), memberstring) &&
            (memberstring != "this") &&
            !isSomeFunction!(__traits(getMember, T, memberstring)))
        {
            // We can copy default values on structs, but not on classes or interfaces.
            static if (is(T == struct))
            {
                static if (is(typeof(__traits(getMember, T, memberstring)) == enum))
                {
                    import std.conv : text;

                    mixin(fullyQualifiedName!(typeof(__traits(getMember, T, memberstring))),
                        " ", memberstring, " = ",
                        fullyQualifiedName!(typeof(__traits(getMember, T, memberstring))),
                        ".", __traits(getMember, T.init, memberstring).text, ";");
                }
                else
                {
                    mixin(fullyQualifiedName!(typeof(__traits(getMember, T, memberstring))),
                        " ", memberstring, " = ",
                        EnclosingCharacters!(typeof(__traits(getMember, T, memberstring))).opening,
                        __traits(getMember, T.init, memberstring),
                        EnclosingCharacters!(typeof(__traits(getMember, T, memberstring))).closing,
                        ";");
                }
            }
            else
            {
                // Don't provide default values.
                mixin(fullyQualifiedName!(typeof(__traits(getMember, T, memberstring))),
                    " ", memberstring, ";");
            }
        }
    }
}

///
unittest
{
    static assert(__traits(hasMember, Derived, "enum_"));
    static assert(__traits(hasMember, Derived, "s"));
    static assert(__traits(hasMember, Derived, "i"));
    static assert(__traits(hasMember, Derived, "f"));
    static assert(__traits(hasMember, Derived, "copy"));
    static assert(Derived.init.b == false);
}


version(unittest)
{
    /// For unittests.
    struct Base
    {
        enum E { A, B, C }

        E enum_;
        string s = "hello";
        int i = 42;
        float f = 3.14f;  // this value is lost
        bool b = true;
        Base* copy;
    }

    /// For unittests.
    struct Derived
    {
        mixin Imprint!Base;
        bool b = false;  // overrides
    }
}


// EnclosingCharacters
/++
    Provides the characters needed to enclose literals of certain types, like
    double quotes for strings.

    Examples:
    ---
    enum quote = EnclosingCharacters!string.opening;
    enum singlequote = EnclosingCharacters!char.closing;
    enum nothing = EnclosingCharacters!bool.opening;
    ---
 +/
private template EnclosingCharacters(T)
{
    import std.traits : isSomeChar;

    static if (is(T : string))
    {
        enum opening = "\"";
        enum closing = opening;
    }
    else static if (isSomeChar!T)
    {
        enum opening = "'";
        enum closing = opening;
    }
    /*else static if (isArray!T)
    {
        enum opening = "[";
        enum closing = "]";
    }*/
    else
    {
        enum opening = string.init;
        enum closing = opening;
    }
}
