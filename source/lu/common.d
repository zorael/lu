// This looks weird but adrdox doesn't pick the ddoc up otherwise

deprecated("Module was renamed; import symbols from `lu.misc` instead")
/++
    Compatibility module publicly importing symbols from [lu.misc].
    Import symbols directly from [lu.misc] instead.

    This module will be removed in a future release.
 +/
module lu.common;

/++
    Publicly import all of `lu.misc`.
 +/
public import lu.misc;
