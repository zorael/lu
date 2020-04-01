/++
 +  Functionality generic enough to be used in several places.
 +/
module lu.common;

public:

@safe:


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
