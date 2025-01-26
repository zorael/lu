/++
    Things that don't have a better home yet.

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.common;

private:

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
        Creates a new [ReturnValueException], without attaching anything.
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }

    /++
        Creates a new [ReturnValueException], attaching a command.
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
        Creates a new [ReturnValueException], attaching a command and a returned value.
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
        Creates a new [FileExistsException], without attaching a filename.
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }

    /++
        Creates a new [FileExistsException], attaching a filename.
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
        The filename of the file in question.
     +/
    string filename;

    /++
        File attributes.
     +/
    ushort attrs;

    /++
        Creates a new [FileTypeMismatchException], without embedding a filename.
     +/
    this(const string message,
        const string file = __FILE__,
        const size_t line = __LINE__,
        Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(message, file, line, nextInChain);
    }

    /++
        Creates a new [FileTypeMismatchException], embedding a filename.
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

    Pass `reverse: true` to do reverse domain matching, like for flatpak
    application IDs.

    Example:
    ---
    int numDomains = sharedDomains("irc.freenode.net", "leguin.freenode.net");
    assert(numDomains == 2);  // freenode.net

    int numDomains2 = sharedDomains("Portlane2.EU.GameSurge.net", "services.gamesurge.net", caseSensitive:false);
    assert(numDomains2 == 2);  // gamesurge.net

    int numDomains3 = sharedDomains("org.kde.Platform", "org.kde.KStyle.Awaita", reverse: true);
    assert(numDomains3 == 2);  // org.kde
    ---

    Params:
        one = First domain string.
        other = Second domain string.
        reverse = Whether or not to do reverse domain matching.
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
    const bool reverse = false,
    const bool caseSensitive = true) pure @safe @nogc nothrow
{
    if (!one.length || !other.length) return 0;

    static uint numDomains(
        const char[] one,
        const char[] other,
        const bool caseSensitive,
        const bool reverse)
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
            immutable c1 = reverse ? one[i] : one[$-i-1];

            if (i == other.length)
            {
                if (c1 == '.') ++dots;
                break;
            }

            immutable c2 = reverse ? other[i] : other[$-i-1];

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
        numDomains(one, other, caseSensitive, reverse) :
        numDomains(other, one, caseSensitive, reverse);
}

///
@safe
unittest
{
    import std.conv : text;

    {
        immutable n = sharedDomains("irc.freenode.net", "help.freenode.net");
        assert((n == 2), n.text);
    }
    {
        immutable n = sharedDomains("irc.rizon.net", "services.rizon.net");
        assert((n == 2), n.text);
    }
    {
        immutable n = sharedDomains("www.google.com", "www.yahoo.com");
        assert((n == 1), n.text);
    }
    {
        immutable n = sharedDomains("www.google.se", "www.google.co.uk");
        assert((n == 0), n.text);
    }
    {
        immutable n = sharedDomains("", string.init);
        assert((n == 0), n.text);
    }
    {
        immutable n = sharedDomains("irc.rizon.net", "rizon.net");
        assert((n == 2), n.text);
    }
    {
        immutable n = sharedDomains("rizon.net", "rizon.net");
        assert((n == 2), n.text);
    }
    {
        immutable n = sharedDomains("net", "net");
        assert((n == 1), n.text);
    }
    {
        immutable n = sharedDomains("forum.dlang.org", "...");
        assert((n == 0), n.text);
    }
    {
        immutable n = sharedDomains("blahrizon.net", "rizon.net");
        assert((n == 1), n.text);
    }
    {
        immutable n = sharedDomains("rizon.net", "blahrizon.net");
        assert((n == 1), n.text);
    }
    {
        immutable n = sharedDomains("rizon.net", "irc.rizon.net");
        assert((n == 2), n.text);
    }
    {
        immutable n = sharedDomains("irc.gamesurge.net", "Stuff.GameSurge.net", caseSensitive:false);
        assert((n == 2), n.text);
    }
    {
        immutable n = sharedDomains("irc.freenode.net", "irc.FREENODE.net", caseSensitive:false);
        assert((n == 3), n.text);
    }

    /+
        Reverse domains, like those of flatpak application IDs.
     +/
    {
        immutable n = sharedDomains("irc.SpotChat.org", "irc.FREENODE.net", caseSensitive:false);
        assert((n == 0), n.text);
    }
    {
        immutable n = sharedDomains("org.kde.Plasma", "org.kde.Kate", reverse: true);
        assert((n == 2), n.text);
    }
    {
        immutable n = sharedDomains("com.redhat.Something", "com.redhat.Other", reverse: true);
        assert((n == 2), n.text);
    }
    {
        immutable n = sharedDomains("org.freedesktop.Platform.GL.default", "org.freedesktop.Platform.VAAPI.Intel", reverse: true);
        assert((n == 3), n.text);
    }
    {
        immutable n = sharedDomains("org.kde.Platform", "im.riot.Riot", reverse: true);
        assert((n == 0), n.text);
    }
}
