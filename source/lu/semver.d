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
    major = 2,

    /++
        SemVer minor version of the library.
     +/
    minor = 0,

    /++
        SemVer patch version of the library.
     +/
    patch = 0,
}


/// Pre-release SemVer subversion of this build.
enum LuSemVerPrerelease = string.init;
