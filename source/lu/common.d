/++
    Functionality generic enough to be used in several places.

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.common;

private:

import std.typecons : Flag, No, Yes;

public:


// Next
/++
    Enum of flags carrying the meaning of "what to do next".
 +/
enum Next
{
    /++
        Unset, invalid value.
     +/
    unset,

    /++
        Do nothing.
     +/
    noop,

    /++
        Keep doing whatever is being done, alternatively continue on to the next step.
     +/
    continue_,

    /++
        Halt what's being done and give it another attempt.
     +/
    retry,

    /++
        Exit or return with a positive return value.
     +/
    returnSuccess,

    /++
        Exit or abort with a negative return value.
     +/
    returnFailure,

    /++
        Fatally abort.
     +/
    crash,
}


// ReturnValueException
/++
    Exception, to be thrown when an executed command returns an error value.

    It is a normal [object.Exception|Exception] but with an attached command
    and return value.
 +/
final class ReturnValueException : Exception
{
    /++
        The command run.
     +/
    string command;

    /++
        The value returned.
     +/
    int retval;

    /++
        Create a new [ReturnValueException], without attaching anything.
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }

    /++
        Create a new [ReturnValueException], attaching a command.
     +/
    this(const string message,
        const string command,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        this.command = command;
        super(message, file, line, nextInChain);
    }

    /++
        Create a new [ReturnValueException], attaching a command and a returned value.
     +/
    this(const string message,
        const string command,
        const int retval,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        this.command = command;
        this.retval = retval;
        super(message, file, line, nextInChain);
    }
}


// FileExistsException
/++
    Exception, to be thrown when attempting to create a file or directory and
    finding that one already exists with the same name.

    It is a normal [object.Exception|Exception] but with an attached filename string.
 +/
final class FileExistsException : Exception
{
    /++
        The name of the file.
     +/
    string filename;

    /++
        Create a new [FileExistsException], without attaching a filename.
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }

    /++
        Create a new [FileExistsException], attaching a filename.
     +/
    this(const string message,
        const string filename,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        this.filename = filename;
        super(message, file, line, nextInChain);
    }
}


// FileTypeMismatchException
/++
    Exception, to be thrown when attempting to access a file or directory and
    finding that something with the that name exists, but is of an unexpected type.

    It is a normal [object.Exception|Exception] but with an embedded filename
    string, and an uint representing the existing file's type (file, directory,
    symlink, ...).
 +/
final class FileTypeMismatchException : Exception
{
    /++
        The filename of the non-FIFO.
     +/
    string filename;

    /++
        File attributes.
     +/
    ushort attrs;

    /++
        Create a new [FileTypeMismatchException], without embedding a filename.
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }

    /++
        Create a new [FileTypeMismatchException], embedding a filename.
     +/
    this(const string message,
        const string filename,
        const ushort attrs,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        this.filename = filename;
        this.attrs = attrs;
        super(message, file, line, nextInChain);
    }
}


// sharedDomains
/++
    Calculates how many dot-separated suffixes two strings share.

    This is useful to see to what extent two addresses are similar.

    Example:
    ---
    int numDomains = sharedDomains("irc.freenode.net", "leguin.freenode.net");
    assert(numDomains == 2);  // freenode.net

    int numDomains2 = sharedDomains("Portlane2.EU.GameSurge.net", "services.gamesurge.net", No.caseSensitive);
    assert(numDomains2 == 2);  // gamesurge.net
    ---

    Params:
        one = First domain string.
        other = Second domain string.
        caseSensitive = Whether or not comparison should be done on a
            case-sensitive basis.

    Returns:
        The number of domains the two strings share.

    TODO:
        Support partial globs.
 +/
auto sharedDomains(
    const string one,
    const string other,
    const Flag!"caseSensitive" caseSensitive = Yes.caseSensitive) pure @safe @nogc nothrow
{
    if (!one.length || !other.length) return 0;

    static uint numDomains(const char[] one, const char[] other, const bool caseSensitive)
    {
        uint dots;
        double doubleDots;

        // If both strings are the same, act as if there's an extra dot.
        // That gives (.)rizon.net and (.)rizon.net two suffixes.

        if (caseSensitive)
        {
            if (one == other) ++dots;
        }
        else
        {
            import std.algorithm.comparison : equal;
            import std.uni : asLowerCase;
            if (one.asLowerCase.equal(other.asLowerCase)) ++dots;
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

            if (caseSensitive)
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
        numDomains(one, other, cast(bool)caseSensitive) :
        numDomains(other, one, cast(bool)caseSensitive);
}

///
@safe
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

    immutable n13 = sharedDomains("irc.gamesurge.net", "Stuff.GameSurge.net", No.caseSensitive);
    assert((n13 == 2), n13.text);

    immutable n14 = sharedDomains("irc.freenode.net", "irc.FREENODE.net", No.caseSensitive);
    assert((n14 == 3), n14.text);

    immutable n15 = sharedDomains("irc.SpotChat.org", "irc.FREENODE.net", No.caseSensitive);
    assert((n15 == 0), n15.text);
}
