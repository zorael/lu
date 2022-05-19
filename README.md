# lu [![Linux/macOS/Windows](https://img.shields.io/github/workflow/status/zorael/lu/D?logo=github&style=flat&maxAge=3600)](https://github.com/zorael/lu/actions?query=workflow%3AD) [![Linux](https://img.shields.io/circleci/project/github/zorael/lu/master.svg?logo=circleci&style=flat&maxAge=3600)](https://circleci.com/gh/zorael/lu) [![Windows](https://img.shields.io/appveyor/ci/zorael/lu/master.svg?logo=appveyor&style=flat&maxAge=3600)](https://ci.appveyor.com/project/zorael/lu) [![Commits since last release](https://img.shields.io/github/commits-since/zorael/lu/v1.2.0.svg?logo=github&style=flat&maxAge=3600)](https://github.com/zorael/lu/compare/v1.2.0...master)

Miscellaneous general-purpose library modules. Nothing extraordinary.

## What it is

API documentation can be found [here](https://lu.dpldocs.info).

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

* [`meld.d`](source/lu/meld.d): Melding two structs/classes of the same type into a union set of their members' values. Non-init values overwrite init ones.

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
    immutable double pi = 3.14;
}

Foo foo;
bool success;

success = foo.setMemberByName("s", "some string");
assert(success);
assert(foo.s == "some string");

success = foo.setMemberByName("i", "42");
assert(success);
assert(foo.i == 42);

success = foo.setMemberByName("b", "true");
assert(success);
assert(foo.b == true);

success = foo.setMemberByName("pi", "3.15");
assert(!success);

success = foo.setMemberByName("i", 999);  // Now works with non-string values
assert(success);
assert(foo.i == 999);
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

* [`serialisation.d`](source/lu/serialisation.d): Functions and templates for serialising structs into an .ini file-*like* format, with entries and values separated into two columns by whitespace.

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
`[Foo]
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
// Credit for Enum goes to Stephan Koch (https://github.com/UplinkCoder). Used with permission.

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

* [`json.d`](source/lu/json.d): Convenience wrappers around a `JSONValue`, which can be unwieldy. Not a JSON parser implementation.
* [`container.d`](source/lu/container.d): Container things, so far only a primitive FIFO `Buffer` (queue) and a LIFO `CircularBuffer`.
* [`common.d`](source/lu/common.d): Things that don't have a better home yet.
* [`numeric.d`](source/lu/numeric.d): Functions and templates that calculate or manipulate numbers in some way.
* [`uda.d`](source/lu/uda.d): Some user-defined attributes used here and there.

## Roadmap

* nothing right now, ideas needed

## Built with

* [**D**](https://dlang.org)
* [`dub`](https://code.dlang.org)

## License

This project is licensed under the **Boost Software License 1.0** - see the [LICENSE_1_0.txt](LICENSE_1_0.txt) file for details.
