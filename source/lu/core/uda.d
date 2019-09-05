/++
 +  User-defined attributes (UDAs) used here and there.
 +/
module lu.core.uda;

/// UDA conveying that a field may not be serialised to configuration files.
struct Unconfigurable;

/// UDA conveying that a string is an array with this token as separator.
struct Separator
{
    /// Separator, can be more than one character.
    string token = ",";
}

/++
 +  UDA conveying that this member contains sensitive information and should not
 +  be printed in clear text; e.g. passwords.
 +/
struct Hidden;

/++
 +  UDA conveying that a string contains characters that could otherwise
 +  indicate a comment.
 +/
struct CannotContainComments;

/++
 +  UDA conveying that this member's value must be quoted when serialised.
 +/
struct Quoted;
