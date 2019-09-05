# lu [![CircleCI Linux/OSX](https://img.shields.io/circleci/project/github/zorael/lu/master.svg?maxAge=3600&logo=circleci)](https://circleci.com/gh/zorael/lu) [![Travis Linux/OSX and documentation](https://img.shields.io/travis/zorael/lu/master.svg?maxAge=3600&logo=travis)](https://travis-ci.org/zorael/lu) [![Windows](https://img.shields.io/appveyor/ci/zorael/lu/master.svg?maxAge=3600&logo=appveyor)](https://ci.appveyor.com/project/zorael/lu) [![GitHub commits since last release](https://img.shields.io/github/commits-since/zorael/lu/v0.0.1.svg?maxAge=3600&logo=github)](https://github.com/zorael/lu/compare/v0.0.1...master)

Miscellaneous general-purpose library modules. Nothing extraordinary.

# What it is

API documentation can be found [here](https://zorael.github.io/lu).

In summary:

* [`core/conv.d`](source/lu/core/conv.d): Conversion functions and templates.
* [`core/meld.d`](source/lu/core/meld.d): *Melding*, or taking two structs/classes of the same type and merging the two.
* [`core/string.d`](source/lu/core/string.d): String manipulation functions and templates; notably `nom` which advances a string passed a supplied substring.
* [`core/traits.d`](source/lu/core/traits.d): Miscellaneous traits and cleverness.
* [`core/uda.d`](source/lu/core/uda.d): Some user-defined attributes used here and there.
* [`common.d`](source/lu/common.d): Things that don't have a better home yet.
* [`json.d`](source/lu/json.d): Convenience wrappers around a `JSONValue`.
* [`net.d`](source/lu/net.d): Connection helpers, including `Fiber`s that resolve addresses, connect to servers and read full strings from connections.
* [`objmanip.d`](source/lu/objmanip.d): Struct/class manipulation, such as setting a member field by its string name.
* [`serialisation.d`](source/lu/serialisation.d): Functions and templates for serialising structs into an .ini file-like format.

# Roadmap

* figure out better subpackaging

# License

This project is licensed under the **MIT** license - see the [LICENSE](LICENSE) file for details.
