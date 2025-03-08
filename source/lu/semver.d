/++
    SemVer information about the current release.

    Contains only definitions, no code. Helps importing projects tell what
    features are available.

    Copyright: [JR](https://github.com/zorael)
    License: [Boost Software License 1.0](https://www.boost.org/users/license.html)

    Authors:
        [JR](https://github.com/zorael)
 +/
module lu.semver;


/++
    SemVer versioning of this build.
 +/
enum LuSemVer
{
    /++
        SemVer major version of the library.
     +/
    major = 3,

    /++
        SemVer minor version of the library.
     +/
    minor = 2,

    /++
        SemVer patch version of the library.
     +/
    patch = 2,
}


/++
    Pre-release SemVer subversion of this build.
 +/
enum LuSemVerPrerelease = string.init;
