/++
 +  Common functions used throughout the program, generic enough to be used in
 +  several places, not fitting into any specific one.
 +/
module lu.common;

private:

import core.time : Duration, seconds;
import std.range.primitives : isOutputRange;
import std.typecons : Flag, No, Yes;

public:

@safe:


// getMultipleOf
/++
 +  Given a number, calculate the largest multiple of `n` needed to reach that number.
 +
 +  It rounds up, and if supplied `Yes.alwaysOneUp` it will always overshoot.
 +  This is good for when calculating format pattern widths.
 +
 +  Example:
 +  ---
 +  immutable width = 15.getMultipleOf(4);
 +  assert(width == 16);
 +  immutable width2 = 16.getMultipleOf!(Yes.alwaysOneUp)(4);
 +  assert(width2 == 20);
 +  ---
 +
 +  Params:
 +      oneUp = Whether or not to always overshoot.
 +      num = Number to reach.
 +      n = Base value to find a multiplier for.
 +
 +  Returns:
 +      The multiple of `n` that reaches and possibly overshoots `num`.
 +/
Number getMultipleOf(Flag!"alwaysOneUp" oneUp = No.alwaysOneUp, Number)
    (const Number num, const int n) pure nothrow @nogc
in ((n > 0), "Cannot get multiple of 0 or negatives")
in ((num >= 0), "Cannot get multiples for a negative number")
do
{
    if (num == 0) return 0;

    if (num == n)
    {
        static if (oneUp) return (n * 2);
        else
        {
            return n;
        }
    }

    immutable frac = (num / double(n));
    immutable floor_ = cast(uint)frac;

    static if (oneUp)
    {
        immutable mod = (floor_ + 1);
    }
    else
    {
        immutable mod = (floor_ == frac) ? floor_ : (floor_ + 1);
    }

    return cast(uint)(mod * n);
}

///
unittest
{
    import std.conv : text;

    immutable n1 = 15.getMultipleOf(4);
    assert((n1 == 16), n1.text);

    immutable n2 = 16.getMultipleOf!(Yes.alwaysOneUp)(4);
    assert((n2 == 20), n2.text);

    immutable n3 = 16.getMultipleOf(4);
    assert((n3 == 16), n3.text);
    immutable n4 = 0.getMultipleOf(5);
    assert((n4 == 0), n4.text);

    immutable n5 = 1.getMultipleOf(1);
    assert((n5 == 1), n5.text);

    immutable n6 = 1.getMultipleOf!(Yes.alwaysOneUp)(1);
    assert((n6 == 2), n6.text);
}


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


// timeSince
/++
 +  Express how much time has passed in a `Duration`, in natural (English) language.
 +
 +  Write the result to a passed output range `sink`.
 +
 +  Example:
 +  ---
 +  Appender!string sink;
 +
 +  const then = Clock.currTime;
 +  Thread.sleep(1.seconds);
 +  const now = Clock.currTime;
 +
 +  const duration = (now - then);
 +  immutable inEnglish = sink.timeSince(duration);
 +  ---
 +
 +  Params:
 +      abbreviate = Whether or not to abbreviate the output, using `h` instead
 +          of `hours`, `m` instead of `minutes`, etc.
 +      sink = Output buffer sink to write to.
 +      duration = A period of time.
 +/
void timeSince(Flag!"abbreviate" abbreviate = No.abbreviate, Sink)
    (auto ref Sink sink, const Duration duration) pure
if (isOutputRange!(Sink, char[]))
in ((duration >= 0.seconds), "Cannot call timeSince on a negative duration")
do
{
    import std.format : formattedWrite;
    import std.traits : isIntegral, isSomeString;

    static if (!__traits(hasMember, Sink, "put")) import std.range.primitives : put;

    int days, hours, minutes, seconds;
    duration.split!("days", "hours", "minutes", "seconds")(days, hours, minutes, seconds);

    // Copied from lu.string to avoid importing it
    pragma(inline)
    static string plurality(const int num, const string singular, const string plural) pure nothrow @nogc
    {
        return ((num == 1) || (num == -1)) ? singular : plural;
    }

    if (days)
    {
        static if (abbreviate)
        {
            sink.formattedWrite("%dd", days);
        }
        else
        {
            sink.formattedWrite("%d %s", days, plurality(days, "day", "days"));
        }
    }

    if (hours)
    {
        static if (abbreviate)
        {
            if (days) sink.put(' ');
            sink.formattedWrite("%dh", hours);
        }
        else
        {
            if (days)
            {
                if (minutes) sink.put(", ");
                else sink.put("and ");
            }
            sink.formattedWrite("%d %s", hours, plurality(hours, "hour", "hours"));
        }
    }

    if (minutes)
    {
        static if (abbreviate)
        {
            if (hours || days) sink.put(' ');
            sink.formattedWrite("%dm", minutes);
        }
        else
        {
            if (hours || days) sink.put(" and ");
            sink.formattedWrite("%d %s", minutes, plurality(minutes, "minute", "minutes"));
        }
    }

    if (!minutes && !hours && !days)
    {
        static if (abbreviate)
        {
            sink.formattedWrite("%ds", seconds);
        }
        else
        {
            sink.formattedWrite("%d %s", seconds, plurality(seconds, "second", "seconds"));
        }
    }
}

///
unittest
{
    import core.time;
    import std.array : Appender;

    Appender!(char[]) sink;
    sink.reserve(64);  // workaround for formattedWrite < 2.076

    {
        immutable dur = 0.seconds;
        sink.timeSince(dur);
        assert((sink.data == "0 seconds"), sink.data);
        sink.clear();
        sink.timeSince!(Yes.abbreviate)(dur);
        assert((sink.data == "0s"), sink.data);
        sink.clear();
    }

    {
        immutable dur = 3_141_519_265.msecs;
        sink.timeSince(dur);
        assert((sink.data == "36 days, 8 hours and 38 minutes"), sink.data);
        sink.clear();
        sink.timeSince!(Yes.abbreviate)(dur);
        assert((sink.data == "36d 8h 38m"), sink.data);
        sink.clear();
    }

    {
        immutable dur = 3599.seconds;
        sink.timeSince(dur);
        assert((sink.data == "59 minutes"), sink.data);
        sink.clear();
        sink.timeSince!(Yes.abbreviate)(dur);
        assert((sink.data == "59m"), sink.data);
        sink.clear();
    }

    {
        immutable dur = 3.days + 35.minutes;
        sink.timeSince(dur);
        assert((sink.data == "3 days and 35 minutes"), sink.data);
        sink.clear();
        sink.timeSince!(Yes.abbreviate)(dur);
        assert((sink.data == "3d 35m"), sink.data);
        sink.clear();
    }
}


// timeSince
/++
 +  Express how much time has passed in a `Duration`, in natural (English) language.
 +
 +  Returns the result as a string.
 +
 +  Example:
 +  ---
 +  const then = Clock.currTime;
 +  Thread.sleep(1.seconds);
 +  const now = Clock.currTime;
 +
 +  const duration = (now - then);
 +  immutable inEnglish = timeSince(duration);
 +  ---
 +
 +  Params:
 +      abbreviate = Whether or not to abbreviate the output, using `h` instead
 +          of `hours`, `m` instead of `minutes`, etc.
 +      duration = A period of time.
 +
 +  Returns:
 +      A string with the passed duration expressed in natural English language.
 +/
string timeSince(Flag!"abbreviate" abbreviate = No.abbreviate)(const Duration duration) pure
{
    import std.array : Appender;

    Appender!string sink;
    sink.reserve(50);
    sink.timeSince!abbreviate(duration);
    return sink.data;
}

///
unittest
{
    import core.time : seconds;

    {
        immutable dur = 789_383.seconds;  // 1 week, 2 days, 3 hours, 16 minutes, and 23 secs
        immutable since = dur.timeSince;
        immutable abbrev = dur.timeSince!(Yes.abbreviate);
        assert((since == "9 days, 3 hours and 16 minutes"), since);
        assert((abbrev == "9d 3h 16m"), abbrev);
    }

    {
        immutable dur = 3_620.seconds;  // 1 hour and 20 secs
        immutable since = dur.timeSince;
        immutable abbrev = dur.timeSince!(Yes.abbreviate);
        assert((since == "1 hour"), since);
        assert((abbrev == "1h"), abbrev);
    }

    {
        immutable dur = 30.seconds;  // 30 secs
        immutable since = dur.timeSince;
        immutable abbrev = dur.timeSince!(Yes.abbreviate);
        assert((since == "30 seconds"), since);
        assert((abbrev == "30s"), abbrev);
    }

    {
        immutable dur = 1.seconds;
        immutable since = dur.timeSince;
        immutable abbrev = dur.timeSince!(Yes.abbreviate);
        assert((since == "1 second"), since);
        assert((abbrev == "1s"), abbrev);
    }
}


// Next
/++
 +  Enum of flags carrying the meaning of "what to do next".
 +/
enum Next
{
    continue_,     /// Keep doing whatever is being done, alternatively continue on to the next step.
    retry,         /// Halt what's being done and give it another attempt.
    returnSuccess, /// Exit or return with a positive return value.
    returnFailure, /// Exit or abort with a negative return value.
}


// ReturnValueException
/++
 +  Exception, to be thrown when an executed command returns an error value.
 +
 +  It is a normal `object.Exception` but with an attached command and return value.
 +/
final class ReturnValueException : Exception
{
@safe:
    /// The command run.
    string command;

    /// The value returned.
    int retval;

    /// Create a new `ReturnValueException`, without attaching anything.
    this(const string message, const string file = __FILE__, const size_t line = __LINE__) pure @nogc
    {
        super(message, file, line);
    }

    /// Create a new `ReturnValueException`, attaching a command.
    this(const string message, const string command, const string file = __FILE__,
        const size_t line = __LINE__) pure @nogc
    {
        this.command = command;
        super(message, file, line);
    }

    /// Create a new `ReturnValueException`, attaching a command and a returned value.
    this(const string message, const string command, const int retval,
        const string file = __FILE__, const size_t line = __LINE__) pure @nogc
    {
        this.command = command;
        this.retval = retval;
        super(message, file, line);
    }
}


// FileExistsException
/++
 +  Exception, to be thrown when attempting to create a file or directory and
 +  finding that one already exists with the same name.
 +
 +  It is a normal `object.Exception` but with an attached filename string.
 +/
final class FileExistsException : Exception
{
@safe:
    /// The name of the file.
    string filename;

    /// Create a new `FileExistsException`, without attaching a filename.
    this(const string message, const string file = __FILE__, const size_t line = __LINE__) pure @nogc
    {
        super(message, file, line);
    }

    /// Create a new `FileExistsException`, attaching a filename.
    this(const string message, const string filename, const string file = __FILE__,
        const size_t line = __LINE__) pure @nogc
    {
        this.filename = filename;
        super(message, file, line);
    }
}


// FileTypeMismatchException
/++
 +  Exception, to be thrown when attempting to access a file or directory and
 +  finding that something with the that name exists, but is of an unexpected type.
 +
 +  It is a normal `object.Exception` but with an embedded filename string, and an uint
 +  representing the existing file's type (file, directory, symlink, ...).
 +/
final class FileTypeMismatchException : Exception
{
@safe:
    /// The filename of the non-FIFO.
    string filename;

    /// File attributes.
    ushort attrs;

    /// Create a new `FileTypeMismatchException`, without embedding a filename.
    this(const string message, const string file = __FILE__, const size_t line = __LINE__) pure @nogc
    {
        super(message, file, line);
    }

    /// Create a new `FileTypeMismatchException`, embedding a filename.
    this(const string message, const string filename, const ushort attrs,
        const string file = __FILE__, const size_t line = __LINE__) pure @nogc
    {
        this.filename = filename;
        this.attrs = attrs;
        super(message, file, line);
    }
}


// getPlatform
/++
 +  Returns the string of the name of the current platform, adjusted to include
 +  `cygwin` as an alternative next to `win32` and `win64`, as well as embedded
 +  terminal consoles like in Visual Studio Code.
 +
 +  Example:
 +  ---
 +  immutable currentPlatform = getPlatform();
 +
 +  switch (currentPlatform)
 +  {
 +  case "Cygwin":
 +  case "vscode":
 +      // Special code for the terminal not being a conventional terminal (such as a pager)...
 +      break;
 +
 +  default:
 +      // Code for normal terminal
 +      break;
 +  }
 +  ---
 +
 +  Returns:
 +      String name of the current platform.
 +/
auto getPlatform()
{
    import std.conv : text;
    import std.process : environment;
    import std.system : os;

    enum osName = os.text;

    version(Windows)
    {
        import std.process : execute;

        immutable term = environment.get("TERM", string.init);

        if (term.length)
        {
            try
            {
                // Get the uname and strip the newline
                immutable uname = execute([ "uname", "-o" ]).output;
                return uname.length ? uname[0..$-1] : osName;
            }
            catch (Exception e)
            {
                return osName;
            }
        }
        else
        {
            return osName;
        }
    }
    else
    {
        return environment.get("TERM_PROGRAM", osName);
    }
}


import std.traits : isAssociativeArray;

// pruneAA
/++
 +  Iterates an associative array and deletes invalid entries, either if the value
 +  is in a default `.init` state or as per the optionally passed predicate.
 +
 +  It is supposedly undefined behaviour to remove an associative array's fields
 +  when foreaching through it. So far we have been doing a simple mark-sweep
 +  garbage collection whenever we encounter this use-case in the code, so why
 +  not just make a generic solution instead and deduplicate code?
 +
 +  Example:
 +  ---
 +  auto aa =
 +  [
 +      "abc" : "def",
 +      "ghi" : string.init;
 +      "mno" : "123",
 +      "pqr" : string.init,
 +  ];
 +
 +  pruneAA(aa);
 +
 +  assert("ghi" !in aa);
 +  assert("pqr" !in aa);
 +
 +  pruneAA!((entry) => entry.length > 0)(aa);
 +
 +  assert("abc" !in aa);
 +  assert("mno" !in aa);
 +  ---
 +
 +  Params:
 +      pred = Optional predicate if special logic is needed to determine whether
 +          an entry is to be removed or not.
 +      aa = The associative array to modify.
 +/
void pruneAA(alias pred = null, T)(ref T aa)
if (isAssociativeArray!T)
{
    if (!aa.length) return;

    string[] garbage;

    // Mark
    foreach (/*immutable*/ key, value; aa)
    {
        static if (!is(typeof(pred) == typeof(null)))
        {
            import std.functional : binaryFun, unaryFun;

            alias unaryPred = unaryFun!pred;
            alias binaryPred = binaryFun!pred;

            static if (__traits(compiles, unaryPred(value)))
            {
                if (unaryPred(value)) garbage ~= key;
            }
            else static if (__traits(compiles, binaryPred(key, value)))
            {
                if (unaryPred(key, value)) garbage ~= key;
            }
            else
            {
                static assert(0, "Unknown predicate type passed to `pruneAA`");
            }
        }
        else
        {
            if (value == typeof(value).init)
            {
                garbage ~= key;
            }
        }
    }

    // Sweep
    foreach (immutable key; garbage)
    {
        aa.remove(key);
    }
}

///
unittest
{
    import std.conv : text;

    {
        auto aa =
        [
            "abc" : "def",
            "ghi" : "jkl",
            "mno" : "123",
            "pqr" : string.init,
        ];

        pruneAA!((a) => a == "def")(aa);
        assert("abc" !in aa);

        pruneAA!((a,b) => a == "pqr")(aa);
        assert("pqr" !in aa);

        pruneAA!`a == "123"`(aa);
        assert("mno" !in aa);
    }
    {
        struct Record
        {
            string name;
            int id;
        }

        auto aa =
        [
            "rhubarb" : Record("rhubarb", 100),
            "raspberry" : Record("raspberry", 80),
            "blueberry" : Record("blueberry", 0),
            "apples" : Record("green apples", 60),
            "yakisoba"  : Record("yakisoba", 78),
            "cabbage" : Record.init,
        ];

        pruneAA(aa);
        assert("cabbage" !in aa);

        pruneAA!((entry) => entry.id < 80)(aa);
        assert("blueberry" !in aa);
        assert("apples" !in aa);
        assert("yakisoba" !in aa);
        assert((aa.length == 2), aa.length.text);
    }
    {
        import std.algorithm.searching : canFind;

        string[][string] aa =
        [
            "abc" : [ "a", "b", "c" ],
            "def" : [ "d", "e", "f" ],
            "ghi" : [ "g", "h", "i" ],
            "jkl" : [ "j", "k", "l" ],
        ];

        pruneAA(aa);
        assert((aa.length == 4), aa.length.text);

        pruneAA!((entry) => entry.canFind("a"))(aa);
        assert("abc" !in aa);
    }
}


// Buffer
/++
 +  Simple buffer for storing and fetching items of any type `T`.
 +
 +  It uses a static array internally, which imposes a hard limit on how many
 +  items can be added.
 +
 +  Example:
 +  ---
 +  Buffer!string buffer;
 +
 +  buffer.put("abc");
 +  buffer.put("def");
 +  assert(!buffer.empty);
 +  assert(buffer.front == "abc");
 +  buffer.popFront();
 +  assert(buffer.front == "def");
 +  buffer.popFront();
 +  assert(buffer.empty);
 +  ---
 +
 +  Params:
 +      T = Buffer item type.
 +      bufferSize = How many items to allocate space for. It will assert if
 +          you attempt to store any past this amount.
 +/
struct Buffer(T, size_t bufferSize = 128)
{
pure nothrow @nogc:
    /// Internal buffer static array.
    T[bufferSize] buf;

    /// Current position in the array.
    ptrdiff_t pos;

    /// Position of last entry in the array.
    ptrdiff_t end;

    /++
     +  Append an item to the end of the buffer.
     +
     +  Params:
     +      more = Item to add.
     +/
    void put(const T more)
    in ((end < bufferSize), typeof(this).stringof ~ " buffer overflow")
    do
    {
        buf[end++] = more;
    }

    /++
     +  Implements `buf ~= someT` (appending) by wrapping `put`.
     +
     +  Params:
     +      op = Op type, here specialised to "`~`".
     +      more = Item to add.
     +/
    void opOpAssign(string op : "~")(const T more)
    {
        return put(more);
    }

    /++
     +  Fetches the item at the current position of the buffer.
     +
     +  Returns:
     +      An item T.
     +/
    T front()
    in ((end > 0), "Empty range")
    do
    {
        return buf[pos];
    }

    /// Advances the current position to the next item in the buffer.
    void popFront()
    {
        if (++pos == end) reset();
    }

    /++
     +  Returns whether or not the array is considered empty.
     +
     +  Mind that the buffer may well still contain old contents. Use `clear`
     +  to zero it out.
     +
     +  Returns:
     +      `true` if there are items available to get via `front`, `false` if not.
     +/
    bool empty()
    {
        return (end == 0);
    }

    /// Resets the array positions, effectively emptying the buffer.
    void reset()
    {
        pos = 0;
        end = 0;
    }

    /// Zeroes out the buffer, getting rid of old contents.
    void clear()
    {
        buf[] = T.init;
    }
}

///
unittest
{
    {
        Buffer!(bool, 4) buf;

        assert(buf.empty);
        buf.put(true);
        buf.put(false);
        buf.put(true);
        buf.put(false);

        assert(!buf.empty);
        assert(buf.front == true);
        buf.popFront();
        assert(buf.front == false);
        buf.popFront();
        assert(buf.front == true);
        buf.popFront();
        assert(buf.front == false);
        buf.popFront();
        assert(buf.empty);
        assert(buf.buf == [ true, false, true, false ]);
        buf.put(false);
        assert(buf.buf == [ false, false, true, false ]);
        buf.reset();
        assert(buf.empty);
        buf.clear();
        assert(buf.buf == [ false, false, false, false ]);
    }
    {
        Buffer!(string, 4) buf;

        assert(buf.empty);
        buf.put("abc");
        buf.put("def");
        buf.put("ghi");

        assert(!buf.empty);
        assert(buf.front == "abc");
        buf.popFront();
        assert(buf.front == "def");
        buf.popFront();
        buf.put("JKL");
        assert(buf.front == "ghi");
        buf.popFront();
        assert(buf.front == "JKL");
        buf.popFront();
        assert(buf.empty);
        assert(buf.buf == [ "abc", "def", "ghi", "JKL" ]);
        buf.put("MNO");
        assert(buf.buf == [ "MNO", "def", "ghi", "JKL" ]);
        buf.clear();
        assert(buf.buf == [ string.init, string.init, string.init, string.init ]);
    }
    {
        Buffer!(char, 64) buf;
        buf ~= 'a';
        buf ~= 'b';
        buf ~= 'c';
        assert(buf.buf[0..3] == "abc".dup);

        foreach (char_; buf)
        {
            assert((char_ == 'a') || (char_ == 'b') || (char_ == 'c'));
        }
    }
}


// sharedDomains
/++
 +  Calculates how many dot-separated suffixes two strings share.
 +
 +  This is useful to see to what extent two addresses are similar.
 +
 +  Example:
 +  ---
 +  int numDomains = sharedDomains("irc.freenode.net", "leguin.freenode.net");
 +  assert(numDomains == 2);  // freenode.net
 +
 +  int numDomains2 = sharedDomains!(No.caseSensitive)("Portlane2.EU.GameSurge.net", "services.gamesurge.net");
 +  assert(numDomains2 == 2);  // gamesurge.net
 +  ---
 +
 +  Params:
 +      caseSensitive = Whether or not comparison should be done on a case-sensitive basis.
 +      one = First domain string.
 +      other = Second domain string.
 +
 +  Returns:
 +      The number of domains the two strings share.
 +
 +  TODO:
 +      Support partial globs.
 +/
auto sharedDomains(Flag!"caseSensitive" caseSensitive = Yes.caseSensitive)
    (const string one, const string other) pure @nogc nothrow
{
    if (!one.length || !other.length) return 0;

    static uint numDomains(const char[] one, const char[] other)
    {
        uint dots;
        double doubleDots;

        // If both strings are the same, act as if there's an extra dot.
        // That gives (.)rizon.net and (.)rizon.net two suffixes.

        static if (caseSensitive)
        {
            if (one.length && (one == other)) ++dots;
        }
        else
        {
            import std.algorithm.comparison : equal;
            import std.uni : asLowerCase;
            if (one.length && one.asLowerCase.equal(other.asLowerCase)) ++dots;
        }

        foreach (immutable i; 0..one.length)
        {
            immutable c1 = one[$-i-1];

            if (i == other.length)
            {
                if (c1 == '.') ++dots;
                break;
            }

            immutable c2 = other[$-i-1];

            static if (caseSensitive)
            {
                if (c1 != c2) break;
            }
            else
            {
                import std.ascii : toLower;
                if (c1.toLower != c2.toLower) break;
            }

            if (c1 == '.')
            {
                if (!doubleDots)
                {
                    ++dots;
                    doubleDots = true;
                }
            }
            else
            {
                doubleDots = false;
            }
        }

        return dots;
    }

    return (one.length > other.length) ?
        numDomains(one, other) :
        numDomains(other, one);
}

///
unittest
{
    import std.conv : text;

    immutable n1 = sharedDomains("irc.freenode.net", "help.freenode.net");
    assert((n1 == 2), n1.text);

    immutable n2 = sharedDomains("irc.rizon.net", "services.rizon.net");
    assert((n2 == 2), n2.text);

    immutable n3 = sharedDomains("www.google.com", "www.yahoo.com");
    assert((n3 == 1), n3.text);

    immutable n4 = sharedDomains("www.google.se", "www.google.co.uk");
    assert((n4 == 0), n4.text);

    immutable n5 = sharedDomains("", string.init);
    assert((n5 == 0), n5.text);

    immutable n6 = sharedDomains("irc.rizon.net", "rizon.net");
    assert((n6 == 2), n6.text);

    immutable n7 = sharedDomains("rizon.net", "rizon.net");
    assert((n7 == 2), n7.text);

    immutable n8 = sharedDomains("net", "net");
    assert((n8 == 1), n8.text);

    immutable n9 = sharedDomains("forum.dlang.org", "...");
    assert((n9 == 0), n8.text);

    immutable n10 = sharedDomains("blahrizon.net", "rizon.net");
    assert((n10 == 1), n10.text);

    immutable n11 = sharedDomains("rizon.net", "blahrizon.net");
    assert((n11 == 1), n11.text);

    immutable n12 = sharedDomains("rizon.net", "irc.rizon.net");
    assert((n12 == 2), n12.text);

    immutable n13 = sharedDomains!(No.caseSensitive)("irc.gamesurge.net", "Stuff.GameSurge.net");
    assert((n13 == 2), n13.text);

    immutable n14 = sharedDomains!(No.caseSensitive)("irc.freenode.net", "irc.FREENODE.net");
    assert((n14 == 3), n14.text);

    immutable n15 = sharedDomains!(No.caseSensitive)("irc.SpotChat.org", "irc.FREENODE.net");
    assert((n15 == 0), n15.text);
}
