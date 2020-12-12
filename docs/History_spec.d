// just docs: History Tracking File Specification
// Compile this with adrdox.
/++
The history tracking file is a JSONL (JSON list) document; each line is a
complete JSON object containing a single day's record.

A single history file may contain JSON objects conforming to multiple versions
of this specification.

It is preferred but not required that records be sorted ascending by date.

$(NOTE Note: This specification is a work-in-progress draft.)

$(RAW_HTML
    <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">
    <img alt="Creative Commons License" style="border-width:0"
    src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />
    This specification is licensed under a <a rel="license"
    href="http://creativecommons.org/licenses/by-sa/4.0/">
    Creative Commons Attribution-ShareAlike 4.0 International License</a>.
)

## Record Versioning

$(TIP This section basically describes semver for a file format.)

The record version will be recorded as a string of three numbers separated by a
decimal point, in the format "major.minor.patch".

Version numbers shall be incremented based on the types of changes in the table
below. "Backward" and "forward" are defined in relation to an application
designed to work with a specific record version. "Backward compatible" means
that older applications can work with the newer record spec; and "forward
compatible" means that newer applications will be able to work with older
formats.

$(SMALL_TABLE
| Type of specification change | Versioning Change                           |
| ---------------------------- | ------------------------------------------- |
| Backward compatible changes  | Increment patch version                     |
| Forward compatible changes   | Increment minor version; reset patch        |
| Breaking changes             | Increment major version; reset patch, minor |
)

$(SIDEBAR
    This definition allows you to work with the latest version available without
    studying older version specifications. For example, if 1.4.5 is the most
    recent spec version, you can write your application against it and use it on
    any 1.x versions up to 1.4.x.
)

"Compatible" here refers to safely reading the record. If an application
modifies a compatible record with a version number higher than that it was
explicitly designed to handle, it must assume that the portions of the record it
does not understand are valid in the specified record version and preserve them
(additional fields, etc.).

For example, an application designed for records at version 1.0.0 can safely
read a record versioned 1.0.1; if it writes to the record, it must preserve
anything it does not understand, under the assumption that it is valid for
1.0.1. However, that application cannot safely read a record at version 1.1.0.

An application capable of reading records versioned 1.2.0 can safely read a
record at 1.1.0 (as well as 1.0.0); if that application was not designed to
write records at version 1.1.0 however, it must make any updates as 1.2.0
(upgrade the record).

An application only capable of working with version 2.0.0 of the specification
would be unable to safely read or write anything versioned 1.x.y or 3.x.y.


## Record Schema

### Version 1.0.0

No JSON object may contain keys or values not explicitly described in this
specification.

Each record (top-level object) will have two keys: a date and a version
specifier.

The first key in the record must be a date in the format "YYYY-MM-DD". The value
of this key will be the habit instance data within a JSON object.

The second key/value pair will be `"v": "1.0.0"`.

The base (empty) record then is: `{"2020-01-01": {}, "v": "1.0.0"}`

$(PITFALL
    The date must come first; this is invalid:
    `{"v": "1.0.0", "2020-01-01": {}}`
    $(NOTE Note: This is a departure from the JSON specification.)
)

The value of the date key is an object containing key/value pairs of habit data.
Each key is the name of a habit as specified by the habits file, and the
respective values contain instance data pertaining to its completion state.

The value of a habit key must be either a boolean value, the string "skip", or a
JSON object.

That object may contain a `goal` key; if `goal` is absent, readers must
consider it to be an implicit boolean `true` value.

The value of the `goal` key will be one of:
$(LIST
    * A boolean value
    * An integral value
    * A string representing an integral or time value, preceded by an ordering
      character ('<', '>', or '=').
    * A string representing a time value without a preceding ordering character.
      In this case an '=' is implied.
 )

The habit object must also contain one and only one of an `instances` or
`actual` key.

An `instances` key's value is an array of either integers or boolean values. The
array may contain the string "skip" with either array type.

The type of an `actual` key's value must match that of the `goal` key, but a
string value must not include an ordering prefix. The value of `actual` may be
the string "skip" regardless of the `goal` value type.


Some examples:

```javascript
{"2020-01-01": {"Habit": {"goal": true, "actual": true}}}
{"2020-01-01": {"Habit": {"goal": true, "actual": "skip"}}}
{"2020-01-01": {"Habit": {"goal": 100, "instances": [50, 50]}}}
{"2020-01-01": {"Habit": {"goal": "<1000", "instances": [100, 200]}}}
{"2020-01-01": {"Habit": {"goal": "<1000", "instances": [100, "skip"]}}}
{"2020-01-01": {"Habit": {"goal": "<12:30", "actual": "11:30"}}}
{"2020-01-01": {"Habit": {"actual": true}}}
{"2020-01-01": {"Habit": {"instances": [true, true, false]}}}
{"2020-01-01": {"Habit": {"goal": 4, "instances": [4, 3, "skip"]}}}
{"2020-01-01": {"Habit": {"goal": 4, "instances": [4, 3, 0]}}}
```

A habit value type of boolean or the string "skip" is shorthand; see the table
below.

$(SMALL_TABLE
| Short Record        | Equivalent Long Record                        |
| ------------------- | --------------------------------------------- |
| `{"Habit": true}`   | `{"Habit": {"goal": true, "actual": true}}`   |
| `{"Habit": false}`  | `{"Habit": {"goal": true, "actual": false}}`  |
| `{"Habit": "skip"}` | `{"Habit": {"goal": true, "actual": "skip"}}` |
)


#### Still To Determine

$(NUMBERED_LIST
    * Do I need to describe the interpretation of records? That requires
      discussing the habits file; or at least the semantics of it.
)
+/
module history_spec;
