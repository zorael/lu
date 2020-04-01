/++
 +  Type constructors.
 +/
module lu.typecons;

private:

import std.typecons : Flag, No, Yes;

public:

@safe:


// Labeled
/++
 +  Labels an item by wrapping it in a struct with a `label` field.
 +
 +  Access to the `item` is passed on by use of `alias this` proxying, so this
 +  will transparently act like the original `item` in most cases. The original
 +  object can be accessed via the `item` member when it doesn't.
 +
 +  Example:
 +  ---
 +  Labeled!(string, long) timestring;
 +
 +  timestring.item = "Some string";
 +  timestring.label = Clock.currTime.toUnixTime;
 +  timestring = "New string value";
 +  ---
 +
 +  Params:
 +      Item = The type to embed and label.
 +      Label = The type to embed as label.
 +      disableThis = Whether or not to disable copying of the resulting struct.
 +/
struct Labeled(Item, Label, Flag!"disableThis" disableThis = No.disableThis)
{
public:
    /// The wrapped item.
    Item item;

    /// Backwards-compatibility alias to `item`.
    alias thing = item;

    /// The label applied to the wrapped item.
    Label label;

    /// Backwards-compatibility alias to `label`.
    alias id = label;

    /// Create a new `Labeled` struct with the passed `labl` identifier.
    this(Item item, Label label) pure nothrow @nogc @safe
    {
        this.item = item;
        this.label = label;
    }

    /++
     +  Assign `item` a new value.
     +
     +  Params:
     +      item = New value for `item`.
     +/
    void opAssign(Item item)
    {
        this.item = item;
    }

    static if (disableThis)
    {
        /// Never copy this.
        @disable this(this);
    }

    /// Transparently proxy all `Item`-related calls to `item`.
    alias item this;
}

///
unittest
{
    struct Foo
    {
        bool b = true;

        bool wefpok() @property
        {
            return false;
        }
    }

    Foo foo;
    Foo bar;

    Labeled!(Foo,int)[] arr;

    arr ~= labeled(foo, 1);
    arr ~= labeled(bar, 2);

    assert(arr[0].label == 1);
    assert(arr[1].label == 2);

    assert(arr[0].b);
    assert(!arr[1].wefpok);

    Labeled!(string, int) item;
    item.item = "harbl";
    item.label = 42;
    assert(item.label == 42);
    assert(item.item == "harbl");
    item = "snarbl";
    assert(item.item == "snarbl");
}


// labeled
/++
 +  Convenience function to create a `Labeled` struct while inferring the
 +  template parameters from the runtime arguments.
 +
 +  Example:
 +  ---
 +  Foo foo;
 +  auto namedFoo = labeled(foo, "hello world");
 +
 +  Foo bar;
 +  auto numberedBar = labeled(bar, 42);
 +  ---
 +
 +  Params:
 +      disableThis = Whether or not to disable copying of the resulting struct.
 +      item = Object to wrap.
 +      label = Label ID to apply to the wrapped item.
 +
 +  Returns:
 +      The passed object, wrapped and labeled with the supplied ID.
 +/
auto labeled(Flag!"disableThis" disableThis = No.disableThis, Item, Label)
    (Item item, Label label) pure nothrow @nogc
{
    import std.traits : Unqual;
    return Labeled!(Unqual!Item, Unqual!Label, disableThis)(item, label);
}

///
unittest
{
    auto foo = labeled("FOO", "foo");
    static assert(is(typeof(foo) == Labeled!(string, string)));

    assert(foo.item == "FOO");
    assert(foo.label == "foo");

    auto bar = labeled!(Yes.disableThis)("hirf", 0);
    assert(bar.item == "hirf");
    assert(bar.label == 0);

    void takesByValue(typeof(bar) bar) {}

    static assert(!__traits(compiles, takesByValue(bar)));
}
