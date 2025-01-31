/++
    Assertion helpers.

    Example:
    ---
    enum actual =
    "abc
    def
    ghi
    jkl
    mno
    pqr";

    enum expected =
    "abc
    def
    ghi
    jkl
    mnO
    pqr";

    actual.assertMultilineEquals(expected);

    /*
    core.exception.AssertError@some/file.d(123):
    Line mismatch at some/file.d:147, block 5:3; expected 'O'(79) was 'o'(111)
    expected:"mnO"
      actual:"mno"
                ^
     */
    ---

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.assert_;


// assertMultilineEquals
/++
    Asserts that two multiple-line strings are equal, with a more detailed error
    message than the yes/no of the built-in `assert()`.

    Params:
        actual = Actual string.
        expected = Expected string.
        file = File name to report in the error message.
        line = Line number to report in the error message.
 +/
void assertMultilineEquals(
    const(char[]) actual,
    const(char[]) expected,
    const string file = __FILE__,
    const uint line = __LINE__) pure @safe
{
    import std.algorithm.iteration : splitter;
    import std.conv : text;
    import std.format : format;
    import std.range : StoppingPolicy, repeat, zip;
    import std.utf : replacementDchar;

    if (actual == expected) return;

    auto expectedRange = expected.splitter("\n");
    auto actualRange = actual.splitter("\n");
    auto lineRange = zip(StoppingPolicy.longest, expectedRange, actualRange);
    uint lineNumber;

    foreach (const expectedLine, const actualLine; lineRange)
    {
        ++lineNumber;

        auto charRange = zip(StoppingPolicy.longest, expectedLine, actualLine);
        uint linePos;

        foreach (const expectedChar, const actualChar; charRange)
        {
            ++linePos;

            if (actualChar == expectedChar) continue;

            enum EOL = 65_535;
            immutable expectedCharString = (expectedChar != EOL) ?
                text('\'', expectedChar, '\'') :
                "EOL";
            immutable expectedCharValueString = (expectedChar != EOL) ?
                text('(', cast(uint)expectedChar, ')') :
                string.init;
            immutable actualCharString = (actualChar != EOL) ?
                text('\'', actualChar, '\'') :
                "EOL";
            immutable actualCharValueString = (actualChar != EOL) ?
                text('(', cast(uint)actualChar, ')') :
                string.init;
            immutable arrow = text(' '.repeat(linePos-1), '^');

            enum pattern = `
Line mismatch at %s:%d, block %d:%d; expected %s%s was %s%s
expected:"%s"
  actual:"%s"
          %s`;
            immutable message = pattern
                .format(
                    file,
                    line,
                    lineNumber,
                    linePos,
                    expectedCharString,
                    expectedCharValueString,
                    actualCharString,
                    actualCharValueString,
                    expectedLine,
                    actualLine,
                    arrow);
            assert(0, message);
        }
    }
}

///
unittest
{
    import std.exception : assertNotThrown, assertThrown;
    import core.exception : AssertError;

    {
        enum actual =
"abc
def
ghi
jkl
mno
pqr";

        enum expected =
"abc
def
ghi
jkl
mnO
pqr";

        assertThrown!AssertError(actual.assertMultilineEquals(expected));

        /*
        core.exception.AssertError@source/lu/assert_.d(123):
        Line mismatch at source/lu/assert_.d:147, block 5:3; expected 'O'(79) was 'o'(111)
        expected:"mnO"
          actual:"mno"
                    ^
         */
    }
    {
        enum actual =
"lorem ipsum
sit amet
consectetur
adipiscing";

        enum expected =
"lorem ipsum
sit amet
consectetur";

        assertThrown!AssertError(actual.assertMultilineEquals(expected));

        /*
        core.exception.AssertError@source/lu/assert_.d(118):
        Line mismatch at source/lu/assert_.d:169, block 4:1; expected EOL was 'a'(97)
        expected:""
          actual:"adipiscing"
                  ^
         */
    }
    {
        enum actual =
"i thought what I'd do was
I'd pretend
I was one of those deaf-mutes";

        enum expected = actual;
        assertNotThrown!AssertError(actual.assertMultilineEquals(expected));
    }
}
