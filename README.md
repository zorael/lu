# lu [![CircleCI Linux/OSX](https://img.shields.io/circleci/project/github/zorael/lu/master.svg?maxAge=3600&logo=circleci)](https://circleci.com/gh/zorael/lu) [![Travis Linux/OSX and documentation](https://img.shields.io/travis/zorael/lu/master.svg?maxAge=3600&logo=travis)](https://travis-ci.com/zorael/lu) [![Windows](https://img.shields.io/appveyor/ci/zorael/lu/master.svg?maxAge=3600&logo=appveyor)](https://ci.appveyor.com/project/zorael/lu) [![GitHub commits since last release](https://img.shields.io/github/commits-since/zorael/lu/v0.3.1.svg?maxAge=3600&logo=github)](https://github.com/zorael/lu/compare/v0.3.1...master)

Miscellaneous general-purpose library modules. Nothing extraordinary.

# What it is

API documentation can be found [here](https://zorael.github.io/lu/lu.html).

In summary:

* [`traits.d`](source/lu/traits.d): Various traits and cleverness.

```d
mixin template MyMixin()
{
    mixin MixinConstraints!(MixinScope.struct_ | MixinScope.class_);

    void foo() {}

    int i;
}

struct Bar
{
    mixin MyMixin;  // ok
}

class Baz
{
    mixin MyMixin; // also ok
}

void baz()
{
    mixin MyMixin;  // static assert 0, wrong mixin scope type
}
```

* [`meld.d`](source/lu/meld.d): Melding two structs/classes of the same type and merging the two into a union of their members' values.

```d
struct Foo
{
    string s;
    int i;
}

Foo source;
source.s = "some string";

Foo target;
target.i = 42;

source.meldInto(target);

assert(target.s == "some string");
assert(target.i == 42);
```

* [`objmanip.d`](source/lu/objmanip.d): Struct/class manipulation, such as setting a member field by its string name.

```d
struct Foo
{
    string s;
    int i;
    bool b;
}

Foo foo;

foo.setMemberByName("s", "some string");
assert(foo.s == "some string");

foo.setMemberByName("i", "42");
assert(foo.i == 42);

foo.setMemberByName("b", "true");
assert(foo.b == true);
```

* [`deltastrings.d`](source/lu/deltastrings.d): Expressing the differences between two instances of a struct or class of the same type, as either assignment statements or assert statements.

```d
struct Foo
{
    string s;
    int i;
    bool b;
}

Foo altered;
altered.s = "some string";
altered.i = 42;

Appender!(char[]) sink;

// Generate assignment statements by passing `No.asserts`
sink.formatDeltaInto!(No.asserts)(Foo.init, altered);

asser(sink[] ==
`s = "some string";
i = 42;
`);

sink.clear();

// As above but prepend the name "altered" before the members
sink.formatDeltaInto!(No.asserts)(Foo.init, altered, 0, "altered");

asser(sink[] ==
`altered.s = "some string";
altered.i = 42;
`);

sink.clear();

// Generate assert statements by passing `Yes.asserts`
sink.formatDeltaInto!(Yes.asserts)(Foo.init, altered, 0, "altered");

assert(sink[] ==
`assert((altered.s == "some string"), altered.s);
assert((altered.i == 42), altered.i.to!string);
`);
```

* [`serialisation.d`](source/lu/serialisation.d): Functions and templates for serialising structs into an .ini file-like format.

```d
struct Foo
{
    string s;
    int i;
    bool b;
    double pi;
}

Foo foo;
foo.s = "some string";
foo.i = 42;
foo.b = true;
foo.pi = 3.14159;

Appender!(char[]) sink;
sink.serialise(foo);
immutable justified = sink[].justifiedEntryValueText;

assert(justified ==
`
[Foo]
s               some string
i               42
b               true
pi              3.14159
`);

File file = File("config.conf", "rw");
file.writeln(justified);

// Later...

Foo newFoo;
newFoo.deserialise(readText("config.conf"));

assert(newFoo.s == "some string");
assert(newFoo.i == 42);
assert(newFoo.b == true);
assert(newFoo.pi == 3.14159);
```

* [`string.d`](source/lu/string.d): String manipulation functions and templates.

```d
enum line = "Word split by spaces";
string slice = line;  // mutable

immutable first = slice.nom(" ");
assert(first == "Word");

immutable second = slice.nom(" ");
assert(second == "split");

immutable third = slice.nom(" ");
assert(third == "by");

assert(slice == "spaces");

immutable fourth = slice.nom!(Yes.inherit)(" ");
assert(fourth == "spaces");
assert(slice.length == 0);
```

* [`conv.d`](source/lu/conv.d): Conversion functions and templates.

```d
// Credit for Enum goes to Stephan Koch

enum Foo { abc, def, ghi }

immutable someAbc = Foo.abc;
immutable someDef = Foo.def;
immutable someGhi = Foo.ghi;

assert(Enum!Foo.toString(someAbc) == "abc");
assert(Enum!Foo.toString(someDef) == "def");
assert(Enum!Foo.toString(someGhi) == "ghi");

immutable otherAbc = Enum!Foo.fromString("abc");
immutable otherDef = Enum!Foo.fromString("def");
immutable otherGhi = Enum!Foo.fromString("ghi");
```

* [`net.d`](source/lu/net.d): Connection helpers, including Generator Fibers that resolve addresses, connect to servers and read full strings from connections.
* [`json.d`](source/lu/json.d): Convenience wrappers around a `JSONValue`, which can be unwieldy.
* [`container.d`](source/lu/container.d): Container things, so far only a primitive `Buffer`.
* [`common.d`](source/lu/common.d): Things that don't have a better home yet.
* [`numeric.d`](source/lu/numeric.d): Functions and templates that calculate or manipulate numbers in some way.
* [`uda.d`](source/lu/uda.d): Some user-defined attributes used here and there.

# Roadmap

* nothing right now, ideas needed

# Built with

* [**D**](https://dlang.org)
* [`dub`](https://code.dlang.org)

# License

This project is licensed under the **MIT** license - see the [LICENSE](LICENSE) file for details.
