# lu [![CircleCI Linux/OSX](https://img.shields.io/circleci/project/github/zorael/lu/master.svg?maxAge=3600&logo=circleci)](https://circleci.com/gh/zorael/lu) [![Travis Linux/OSX and documentation](https://img.shields.io/travis/zorael/lu/master.svg?maxAge=3600&logo=travis)](https://travis-ci.com/zorael/lu) [![Windows](https://img.shields.io/appveyor/ci/zorael/lu/master.svg?maxAge=3600&logo=appveyor)](https://ci.appveyor.com/project/zorael/lu) [![GitHub commits since last release](https://img.shields.io/github/commits-since/zorael/lu/v0.3.0.svg?maxAge=3600&logo=github)](https://github.com/zorael/lu/compare/v0.3.0...master)

Miscellaneous general-purpose library modules. Nothing extraordinary.

# What it is

API documentation can be found [here](https://zorael.github.io/lu).

In summary:

* [`traits.d`](source/lu/traits.d): Various traits and cleverness.
* [`meld.d`](source/lu/meld.d): Melding, or taking two structs/classes of the same type and merging the two into a union of their members.
* [`string.d`](source/lu/string.d): String manipulation functions and templates.
* [`conv.d`](source/lu/conv.d): Conversion functions and templates.
* [`common.d`](source/lu/common.d): Things that don't have a better home yet.
* [`uda.d`](source/lu/uda.d): Some user-defined attributes used here and there.
* [`json.d`](source/lu/json.d): Convenience wrappers around a `JSONValue`, which can be unwieldy.
* [`net.d`](source/lu/net.d): Connection helpers, including `Fiber`s that resolve addresses, connect to servers and read full strings from connections.
* [`objmanip.d`](source/lu/objmanip.d): Struct/class manipulation, such as setting a member field by its string name. Also some small AA things.
* [`serialisation.d`](source/lu/serialisation.d): Functions and templates for serialising structs into an .ini file-like format.
* [`deltastrings.d`](source/lu/deltastrings.d): Expressing the differences (or delta) between two instances of a struct or class of the same type, as either assignment statements or assert statements.
* [`container.d`](source/lu/container.d): Container things, so far only a primitive `Buffer`.
* [`numeric.d`](source/lu/numeric.d): Functions and templates that calculate or manipulate numbers in some way.

# Roadmap

* nothing right now, ideas needed

# Built with

* [**D**](https://dlang.org)
* [`dub`](https://code.dlang.org)

# License

This project is licensed under the **MIT** license - see the [LICENSE](LICENSE) file for details.
