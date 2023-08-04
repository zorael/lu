/++
    SemVer information about the current release.

    Contains only definitions, no code. Helps importing projects tell what
    features are available.
 +/
module lu.semver;


/// SemVer versioning of this build.
enum LuSemVer
{
    /++
        SemVer major version of the library.
     +/
    major = 1,

    /++
        SemVer minor version of the library.
     +/
    minor = 2,

    /++
        SemVer patch version of the library.
     +/
    patch = 5,

    /++
        SemVer version of the library. Deprecated; use `LuSemVer.major` instead.
     +/
    //deprecated("Use `LuSemVer.major` instead. This symbol will be removed in a future release.")
    majorVersion = major,

    /++
        SemVer version of the library. Deprecated; use `LuSemVer.minor` instead.
     +/
    //deprecated("Use `LuSemVer.minor` instead. This symbol will be removed in a future release.")
    minorVersion = minor,

    /++
        SemVer version of the library. Deprecated; use `LuSemVer.patch` instead.
     +/
    //deprecated("Use `LuSemVer.patch` instead. This symbol will be removed in a future release.")
    patchVersion = patch,
}


/// Pre-release SemVer subversion of this build.
enum LuSemVerPrerelease = string.init;
