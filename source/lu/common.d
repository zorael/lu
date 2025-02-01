/++
    Compatibility module publicly importing symbols from [lu.misc].
    Import symbols directly from [lu.misc] instead.

    This module will be removed in a future release.
 +/
deprecated("Module was renamed; import symbols from `lu.misc` instead")
module lu.common;

/+
    Publicly import all of `lu.misc`.
 +/
public import lu.misc;
