/++
    Common user-defined attributes (UDAs).
 +/
module lu.uda;

/// UDA conveying that a field cannot (or should not) be serialised.
struct Unserialisable;

/++
    UDA conveying that the annotated array should have this token as separator
    when formatted to a string.
 +/
struct Separator
{
    /// Separator, can be more than one character.
    string token = ",";
}

/++
    UDA conveying that this member contains sensitive information and should not
    be printed in clear text; e.g. passwords.
 +/
struct Hidden;

/++
    UDA conveying that this member may contain characters that would otherwise
    indicate a comment, but isn't.
 +/
struct CannotContainComments;

/++
    UDA conveying that this member's value must be quoted when serialised.
 +/
struct Quoted;
