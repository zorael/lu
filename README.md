# lu

Miscellaneous general-purpose library modules. Used in the [kameloso bot](https://github.com/zorael/kameloso) but wholly decoupled from it.

The split was made so that we could in turn fork the IRC-parsing modules from kameloso into a dub package of its own. It's a work in progress, but this is more than halfway.

* [`core/conv.d`](source/lu/core/conv.d): Conversion functions and templates.
* [`core/meld.d`](source/lu/core/meld.d): *Melding*, or taking two structs/classes of the same type and merging the two.
* [`core/string.d`](source/lu/core/string.d): String-manipulation functions and templates; notably `nom` which advances a string passed a supplied substring.
* [`core/traits.d`](source/lu/core/traits.d): Miscellaneous traits and cleverness.
* [`core/uda.d`](source/lu/core/uda.d): Some attributes used here and there.
* [`common.d`](source/lu/common.d): Things that don't have a better home yet.
* [`json.d`](source/lu/json.d): Convenience wrapper around a `JSONValue`.
* [`net.d`](source/lu/net.d): Connection helpers, including Fibers that help resolve addresses, connect to one and read from one.
* [`objmanip.d`](source/lu/objmanip.d): Struct/class manipulation, such as setting a member field by its string name.
* [`serialisation.d`](source/lu/serialisation.d): Functions and templates for serialising structs into an INI file-like format.

# Roadmap

* set up CIs
* have Travis generate API docs
* fix comments mentioning *kameloso* everywhere

# License

This project is licensed under the **MIT** license - see the [LICENSE](LICENSE) file for details.
