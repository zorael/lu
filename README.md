# lu [![Linux/macOS/Windows](https://img.shields.io/github/actions/workflow/status/zorael/lu/d.yml?branch=master)](https://github.com/zorael/lu/actions?query=workflow%3AD) [![Linux](https://img.shields.io/circleci/project/github/zorael/lu/master.svg?logo=circleci&style=flat&maxAge=3600)](https://circleci.com/gh/zorael/lu) [![Windows](https://img.shields.io/appveyor/ci/zorael/lu/master.svg?logo=appveyor&style=flat&maxAge=3600)](https://ci.appveyor.com/project/zorael/lu) [![Commits since last release](https://img.shields.io/github/commits-since/zorael/lu/v1.2.5.svg?logo=github&style=flat&maxAge=3600)](https://github.com/zorael/lu/compare/v1.2.5...master)

Miscellaneous general-purpose library modules. Nothing extraordinary.

## What it is

API documentation can be found [here](https://lu.dpldocs.info).

* [`meld.d`](source/lu/meld.d): Combining two structs/classes of the same type into a union set of their members' values. Also works with arrays and associative arrays. A melding strategy can be supplied as a template parameter for fine-tuning behaviour, but in general non-init values overwrite init ones.

```d
// Aggregate
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

// Array
auto sourceArr = [ 123, 0, 789, 0, 456, 0 ];
auto targetArr = [ 0, 456, 0, 123, 0, 789 ];
sourceArr.meldInto(targetArr);
assert(targetArr == [ 123, 456, 789, 123, 456, 789 ]);

// Associative array
string[string] sourceAA = [ "a":"a", "b":"b" ];
string[string] targetAA = [ "c":"c", "d":"d" ];

sourceAA.meldInto(targetAA);
assert(targetAA == [ "a":"a", "b":"b", "c":"c", "d":"d" ]);
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

assert(sink[] ==
`s = "some string";
i = 42;
`);

sink.clear();

// As above but prepend the name "altered" before the members
sink.formatDeltaInto!(No.asserts)(Foo.init, altered, 0, "altered");

assert(sink[] ==
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

* [`typecons.d`](source/lu/typecons.d): So far only `UnderscoreOpDispatcher`. When mixed into some aggregate, it generates an `opDispatch` that allows for accessing and mutating any (potentially private) members of it whose names start with an underscore. Arrays are appended to.

```d
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
```

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

* [`serialisation.d`](source/lu/serialisation.d): Functions and templates for serialising structs into an `.ini` file-**like** format, with entries and values separated into two columns by whitespace.

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

File file = File("config.conf", "w");
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
enum line = "Word split by spaces \\o/";
string slice = line;  // mutable

immutable first = slice.advancePast(" ");
assert(first == "Word");

immutable second = slice.advancePast(" ");
assert(second == "split");

immutable third = slice.advancePast(" ");
assert(third == "by");
assert(slice == "spaces \\o/");

/+
    If the optional Yes.inherit is passed, the whole slice is returned
    in case the delimiter isn't found, otherwise it throws.
 +/
immutable fourth = slice.advancePast("?", Yes.inherit);
assert(fourth == "spaces \\o/");
assert(slice.length == 0);

enum quoted = `author "John Doe" title "Foo Bar" tag1 tag2 tag3 tag4`;
string authorHeader;
string author;
string titleHeader;
string title;
string[] overflow;

immutable results = quoted.splitInto(authorHeader, author, titleHeader, title, overflow);
assert(results == SplitResults.overrun);
assert(author == "John Doe");
assert(title == "Foo Bar");
assert(overflow == [ "tag1", "tag2", "tag3", "tag4" ]);

immutable intoArray = quoted.splitWithQuotes();
assert(intoArray.length == 8);
assert(intoArray[1] == "John Doe");
assert(intoArary[3] == "Foo Bar");
assert(intoArray[4..8] == [ "tag1", "tag2", "tag3", "tag4" ]);
```

* [`conv.d`](source/lu/conv.d): Conversion functions and templates.

```d
// Credit for Enum goes to Stephan Koch (https://github.com/UplinkCoder). Used with permission.
// Generates less bloat than `std.conv.to` on larger enums. Restrictions apply.

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

* [`json.d`](source/lu/json.d): Convenience wrappers around a Phobos `JSONValue`, which can be unwieldy. Not a JSON parser implementation.
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
