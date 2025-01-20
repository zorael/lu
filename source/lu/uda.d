/++
    Common user-defined attributes (UDAs).

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.uda;

/++
    UDA conveying that a field cannot (or should not) be serialised.
 +/
enum Unserialisable;

/++
    UDA conveying that the annotated array should have this token as separator
    when formatted to a string.
 +/
struct Separator
{
    /++
        Separator, can be more than one character.
     +/
    string token = ",";
}

/++
    UDA conveying that this member contains sensitive information and should not
    be printed in clear text; e.g. passwords.
 +/
enum Hidden;

/++
    UDA conveying that this member may contain characters that would otherwise
    indicate a comment, but isn't.
 +/
enum CannotContainComments;

/++
    UDA conveying that this member's value must be quoted when serialised.
 +/
enum Quoted;


/++
    UDA conveying that this member's value cannot or should not be melded.
 +/
enum Unmeldable;
