/++
    Assertion helpers.

    Example:
    ---
    enum correct =
    "abc
    def
    ghi
    jkl
    mno
    pqr
    stu
    vw
    xyz";

    enum incorrect =
    "abc
    def
    ghi
    jkl
    mnO
    pqr
    stu
    vw
    xyz";

    assertMultilineEquals(correct, incorrect);

    /*
    Line mismatch at source/lu/assert_.d:143, block 5:3; expected 'O'(79) was 'o'(111)
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
version(none)
unittest
{
    enum actual =
"abc
def
ghi";

    enum expected =
"abc
deF
ghi";

    assertMultilineEquals(actual, expected);

/+
core.exception.AssertError@somefile.d(123):
Line mismatch at somefile.d:456, block 2:3; expected 'F'(70) was 'f'(102)
expected:"deF"
  actual:"def"
            ^
 +/
}
