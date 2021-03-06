/++
    SemVer information about the current release.

    Contains only definitions, no code. Helps importing projects tell what
    features are available.
 +/
module lu.semver;


/// SemVer versioning of this build.
enum LuSemVer
{
    majorVersion = 1,  /// SemVer major version of the library.
    minorVersion = 1,  /// SemVer minor version of the library.
    patchVersion = 2,  /// SemVer patch version of the library.
}


/// Pre-release SemVer subversion of this build.
enum LuSemVerPrerelease = string.init;
