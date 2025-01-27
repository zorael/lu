# lu [![Linux/macOS/Windows](https://img.shields.io/github/actions/workflow/status/zorael/lu/d.yml?branch=master)](https://github.com/zorael/lu/actions?query=workflow%3AD) [![Linux](https://img.shields.io/circleci/project/github/zorael/lu/master.svg?logo=circleci&style=flat&maxAge=3600)](https://circleci.com/gh/zorael/lu) [![Windows](https://img.shields.io/appveyor/ci/zorael/lu/master.svg?logo=appveyor&style=flat&maxAge=3600)](https://ci.appveyor.com/project/zorael/lu) [![Commits since last release](https://img.shields.io/github/commits-since/zorael/lu/v3.1.1.svg?logo=github&style=flat&maxAge=3600)](https://github.com/zorael/lu/compare/v3.1.1...master)

Miscellaneous general-purpose library modules. Nothing extraordinary.

API documentation can be found [here](https://zorael.github.io/lu/lu.html).

#### [`meld.d`](source/lu/meld.d)

Combining two structs/classes of the same type into a union set of their members' values. Also works with arrays and associative arrays. A melding strategy can be supplied as a template parameter for fine-tuning behaviour, but in general non-`.init` values overwrite `.init` ones.

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

#### [`objmanip.d`](source/lu/objmanip.d)

Struct/class manipulation, such as assigning a member a value by its string name. Originally intended to only accept string values but now works with any assignable type. When the passed value doesn't implicitly match, `std.conv.to` is used to coerce.

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

success = foo.setMemberByName("i", 42);
assert(success);
assert(foo.i == 42);

success = foo.setMemberByName("b", "true");
assert(success);
assert(foo.b == true);

success = foo.setMemberByName("b", "foo");
assert(!success);

success = foo.setMemberByName("pi", "3.15");
assert(!success);
```

#### [`deltastrings.d`](source/lu/deltastrings.d)

Expressing the difference between two instances of a struct or class of the same type, as a D code string of either assignment statements or assert statement. The output is written to an output range.

```d
Appender!(char[]) sink;  // or any other output range

struct Foo
{
    string s;
    int i;
    bool b;
}

Foo altered;
altered.s = "some string";
altered.i = 42;

/+
    Generate assignment statements by passing `No.asserts`.
 +/
sink.putDelta!(No.asserts)(Foo.init, altered);

assert(sink[] ==
`s = "some string";
i = 42;
`);

sink.clear();

/+
    As above but prepend the name "altered" before the members.
 +/
sink.putDelta!(No.asserts)(Foo.init, altered, 0, "altered");

assert(sink[] ==
`altered.s = "some string";
altered.i = 42;
`);

sink.clear();

/+
    Generate assert statements by passing `Yes.asserts`.
 +/
sink.putDelta!(Yes.asserts)(Foo.init, altered, 0, "altered");

assert(sink[] ==
`assert((altered.s == "some string"), altered.s);
assert((altered.i == 42), altered.i.to!string);
`);

// A compatibility alias `formatDeltaInto` remains available for now
```

#### [`typecons.d`](source/lu/typecons.d)

The `OpDispatcher` mixin template. When mixed into some aggregate, it generates an `opDispatch` that allows for accessing and mutating any members of it whose names either start or end with a token string. Dynamic arrays are appended to.

A convenience mixin `UnderscoreOpDispatcher` is provided that instantiates an `OpDispatcher` with an underscore token, set to allow access to members that start with `_`.

```d
struct Foo
{
    int _i;
    string _s;
    bool _b;
    string[] _add;
    alias wordList = _add;

    mixin UnderscoreOpDispatcher;  // OpDispatcher!("_", Yes.inFront);
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
    It returns `this` by reference, allowing for chaining calls.
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

/+
    The `inFront` template argument makes it look for members that have the
    token string in the front of their name. Set to `No.inFront`, it looks for
    members whose names end with the string.
 +/
struct Bar
{
    int i_private;
    string s_private;
    bool b_private = true;
    string[] add_private;

    mixin OpDispatcher!("_private", No.inFront);
}

Bar b;
b.i = 9;
b.s = "boop";
b.b = false;
b.add("hi there");
```

#### [`traits.d`](source/lu/traits.d)

Various traits and cleverness.

```d
/+
    Statically enforces that a mixin template is mixed into a given type of scope.
 +/
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

#### [`serialisation.d`](source/lu/serialisation.d)

Functions and templates for serialising structs into a configure file-y format, with entries and values optionally separated into two columns by whitespace.

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

#### [`string.d`](source/lu/string.d)

String manipulation functions and templates.

```d
/+
    Advances a string slice past the first occurrence of a delimiter, returning
    the slice up to the delimiter. The slice is mutated in place.

    Not based on graphemes. Really meant to be used on ASCII strings.
    Your mileage may vary with UTF-8.
 +/
enum line = "Word split by spaces \\o/";
string slice = line;  // mutable

immutable first = slice.advancePast(" ");
assert(first == "Word");

immutable second = slice.advancePast(' ');
assert(second == "split");

immutable third = slice.advancePast(" ");
assert(third == "by");

alias fourth = slice;
assert(fourth == "spaces \\o/");

/+
    If the optional `inherit: true` is passed, the whole slice is returned
    if the delimiter isn't found, otherwise it throws.
 +/
immutable fourth = slice.advancePast("?", inherit: true);
assert(fourth == "spaces \\o/");
assert(slice.length == 0);
```

```d
/+
    Splits a string into multiple substrings delimited by whitespace, where
    multiple words enclosed within quotes are counted as one substring.
    The quotes are removed from the result. The delimiter can be any string or character.
 +/
enum quoted = `author "John Doe" title "Foo Bar"`;
immutable intoArray = quoted.splitWithQuotes();
assert(intoArray.length == 4);
assert(intoArray[1] == "John Doe");
assert(intoArray[3] == "Foo Bar");
```

```d
/+
    Splits a string of words by whitespace, storing the resulting substrings in
    strings passed to it by reference. It returns a `SplitResults` enum indicating
    how the number of split words matched the number of passed string symbols.

    If there are more substrings than there were ref strings passed,
    the remainder is stored in an overflow array, passed last.

    As with `splitWithQuotes`, quoted strings are treated as one word.
 +/
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
```

#### [`conv.d`](source/lu/conv.d)

Conversion functions and templates.

```d
/+
    Converts an enum member to its string name and vice versa.
    Generates less bloat than `std.conv.to` on larger enums. Restrictions apply.

    Credit for Enum goes to Stephan Koch (https://github.com/UplinkCoder). Used with permission.
 +/
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

// Shorthand convenience helper function, infers the type from the argument
assert(Foo.abc.toString() == "abc");
```

#### [`container.d`](source/lu/container.d)

Miscellaneous containers.

```d
// Basic FIFO buffer
Buffer!string buffer;

buffer.put("abc");
buffer.put("def");
assert(!buffer.empty);
assert(buffer.front == "abc");
buffer.popFront();
assert(buffer.front == "def");
buffer.popFront();
assert(buffer.empty);
```

```d
// Simple circular buffer
CircularBuffer!(int, Yes.dynamic) circBuf;
circBuf.resize(3);

circBuf.put(1);
circBuf.put(2);
circBuf.put(3);
circBut.put(4);
assert(circBuf.front == 4);
assert(circBuf.buf == [ 4, 2, 3 ]);
```

```d
/+
    A wrapper of a built-in associative array with controllable rehashing.
    Should otherwise transparently behave like the underlying AA.
    Use the `.aaOf` escape hatch to access the underlying associative array.
 +/
RehashingAA!(int[string]) aa;
aa.minimumNeededForRehash = 2;

void rehashCallback() { /* Do something */ }
aa.onRehashDg = &rehashCallback;

assert(aa.newKeysSinceLastRehash == 0);
aa["abc"] = 123;
aa["def"] = 456;
assert(aa.newKeysSinceLastRehash == 2);
assert(aa.numRehashes == 0);
aa["ghi"] = 789;
assert(aa.numRehashes == 1);
assert(aa.newKeysSinceLastRehash == 0);
aa.rehash();
assert(aa.numRehashes == 2);

foreach (key, value; aa.aaOf)
{
    // opApply is not implemented yet, so you can't `foreach` over `aa` directly
}
```

```d
/+
    A wrapper of a built-in associative array with mutexed access to elements.
 +/
MutexedAA!(string[int]) aa;
aa.setup();  // necessary if declared without using the helper functions below

aa[1] = "one";
aa[2] = "two";
aa[3] = "three";

auto hasOne = aa.has(1);
assert(hasOne);
assert(aa[1] == "one");

assert(aa[2] == "two");

auto three = aa.get(3);
assert(three == "three");

auto four = aa.get(4, "four");
assert(four == "four");

auto five = aa.require(5, "five");
assert(five == "five");
assert(aa[5] == "five");

auto keys = aa.keys;
assert(keys.canFind(1));
assert(keys.canFind(5));
assert(!keys.canFind(6));

auto values = aa.values;
assert(values.canFind("one"));
assert(values.canFind("four"));
assert(!values.canFind("six"));

aa.rehash();
```

```d
/+
    Convenience function initialise and set up a `MutexAA` in one go.
 +/
auto aa = mutexedAA!(int[int]);
//aa.setup();  // no need to setup when the helper functions are used
aa[123] = 456;
```

```d
/+
    As above but additionally takes a pre-existing associative array to wrap.
    Template parameters are inferred from the passed AA.
 +/
auto orig = [ "abc" : 123, "def" : 456 ];
auto aa = mutexedAA(orig);
//aa.setup();
aa["ghi"] = 789;
```

#### [`array.d`](source/lu/array.d)

Some array utilities. Also a simple truth table.

```d
/+
    Table of runtime values, but the function may be called during CTFE to
    produce a compile-time (dynamic) array.
 +/
const table = truthTable(1, 3, 5);
assert(table.length == 6);
assert(table == [ false, true, false, true, false, true ]);
assert(table == [ 0, 1, 0, 1, 0, 1 ]);

assert(!table[0]);
assert( table[1]);
assert(!table[2]);
assert( table[3]);
assert(!table[4]);
assert( table[5]);

/+
    Table of compile-time values. Produces a static array.
 +/
static staticTable = truthTable!(2, 7);
static assert(is(typeof(staticTable) : bool[8]));
static assert(staticTable == [ false, false, true, false, false, false, false, true ]);
static assert(staticTable == [ 0, 0, 1, 0, 0, 0, 0, 1 ]);

static assert(!staticTable[0]);
static assert(!staticTable[1]);
static assert( staticTable[2]);
static assert(!staticTable[3]);
static assert(!staticTable[4]);
static assert(!staticTable[5]);
static assert(!staticTable[6]);
static assert( staticTable[7]);
```

#### [`json.d`](source/lu/json.d)

Simple wrappers around Phobos `std.json`.

```d
auto json = JSONValue([ "foo" : 123, "bar" : 456, "baz" : 789 ]);

assert("foo" in json);
assert("qux" !in json);

string bar;

if (auto barJSON = "bar" in json)
{
    // Quite annoying roundabout way to safely get a value
    bar = (*barJSON).str;
}
else
{
    bar = "not found";
}

// Less annoying roundabout way to safely get a value
string baz = json.getOrFallback("baz", "not found");
assert(baz == "baz");

string xyzzy = json.getOrFallback("xyzzy", "not found");
assert(xyzzy == "not found");
```

#### [`common.d`](source/lu/common.d)

Things that don't have a better home yet.

```d
/+
    Returns the number of shared domains between two hostnames.
    Top-level domains are counted as well, so "youtube.com" and "github.com"
    share one domain. Case-sensitivity can be controlled with the optional
    `caseSensitive` parameter.

    Reverse the order of the domains with the optional `reverse` parameter,
    such as for flatpak application IDs.
 +/
assert(sharedDomains("irc.libera.chat", "zinc.libera.chat") == 2);
assert(sharedDomains("irc.gamesurge.net", "Stuff.GameSurge.net", caseSensitive: false) ==  2);
assert(sharedDomains("forum.dlang.org", "en.wikipedia.org") == 1);  // subtract 1 if you want to ignore TLDs
assert(sharedDomains("www.reddit.com", "www.twitch.tv") == 0);

// Reversed
assert(sharedDomains("org.kde.Platform", "org.kde.KStyle.Awaita", reverse: true) == 2);
```

## Caveats

Starting with `v3.0.0`, a more recent compiler version is required. This is to allow for use of named arguments and to enable some compiler preview switches. You need a compiler based on D version **2.108** or later (April 2024). For **ldc** this translates to a minimum of version **1.38**, while for **gdc** you broadly need release series **14**.

If your repositories (or other software sources) don't have compilers recent enough, you can use the official [`install.sh`](https://dlang.org/install.html) installation script to download current ones, or any version of choice.

Releases of the library prior to `v3.0.0` remain available for older compilers.

**Please report bugs. Unreported bugs can only be fixed by accident.**

## Roadmap

* nothing right now, ideas needed

## Built with

* [**D**](https://dlang.org)
* [`dub`](https://code.dlang.org)

## License

This project is licensed under the **Boost Software License 1.0** - see the [LICENSE_1_0.txt](LICENSE_1_0.txt) file for details.
