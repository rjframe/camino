/** Read and write to the Camino history file. */
module camino.history;

import std.datetime.date : Date, TimeOfDay;
import std.exception : enforce;
import std.json : JSONValue;
import std.stdio : File;
import std.typecons : Tuple;

import camino.exception;
import camino.goal : Actual = GoalValue;
import camino.habit;

import sumtype;


enum Task { Complete, Incomplete };

alias Update = SumType!(Task, Actual, Instance);

enum Skip : string { Skip = "skip" };
alias Instance = SumType!(ulong, bool, Skip);

/** Stores information concerning an individual record from the history file.

    ## Notes

    TODO: I should probably store the path or [std.stdio.File|File] object and
    assert that we only refer to that one record. Since we're only dealing with
    one file on any given run, I'm currently just assuming this.
*/
struct Record {
    // TODO: make readRecord, etc. methods of this?

    /** $(B $(I disabled)) */
    // TODO: File bug on adrdox -> $(NEVER_DOCUMENT) is ignored.
    @disable this();

    /** Create a new [Record] of the specified JSON object and the file position
        from which that object was read.

        It is the caller's responsibility to validate that the [JSONValue]
        represents a valid record.
    */
    pure nothrow @nogc
    this(JSONValue record, size_t file_pos) {
        this.rec = record;
        this.file_pos = file_pos;
    }

    /** Retrieve the index into the source file from which the record was read.
    */
    pure nothrow @nogc
    @property
    size_t pos() const { return file_pos; }

    /** Provides access to the underlying [JSONValue] record.

        This method is `alias this`ed to the [Record]; operations should be
        typically performed directly on the [Record] object instead of
        explicitly via this method.

        Examples:

        ---
        import std.json : JSONValue;
        import std.stdio : writeln;

        auto data = JSONValue(`{"2020-01-01": {}, "v": "1.0.0"}`);
        auto record = Record(data, 0);

        // These two statements are identical:
        writeln(record.toPrettyString());
        writeln(record.record().toPrettyString());
        ---
    */
    // TODO: Should I be providing a reference or provide read-only access
    // instead?
    pure nothrow @nogc
    @property
    auto ref JSONValue record() { return rec; }
    alias record this;

    private:

    JSONValue rec;
    size_t file_pos;
}

/** Update the specified `Habit` for the given date.

    Params:
        history = An opened file from which to read records.
        date    = the date to update.
        habit   = The habit whose status to update.
        update  = The action to record.

    Throws: InvalidRecord, InvalidCommand

    TODO: finish documentation, implementation.
*/
void update(FILE = File)(FILE history, Date date, Habit habit, Update update) {
    import std.stdio : writeln; // tmp

    auto record = readRecord(history, date);

    writeln("\nUpdating: ", habit.description);
    writeln("Current: ", record);

    // TODO: Throw exception if the record does not already include the habit?
    // We need to have a complete record, and requiring that it exist prior to
    // updating makes that simpler for us here.

    auto newRecord = update.match!(
        (Task t) => JSONValue(t == Task.Complete),
        (Actual a) => a.toJSONValue(),
        (Instance i) => {
            return updateInstance(
                record[date.toISOExtString()][habit.description],
                i
            );
        }()
    );

    /* Next steps: reserialize, replace at line.

       If we're not the last line of the file, copy everything to a temp file,
       fixing the updated record, then replace the temp w/ the history file.
       Otherwise, we can just replace the last line; this should be the common
       case
     */

    writeln("newRec: ", newRecord);

    record[date.toISOExtString()][habit.description] = newRecord;

    writeln("\n*** updated: ", record);
}

/** Read the record for the specified date from the given history file.

    The passed file object must conform to the [std.stdio.File] API and be
    opened for reading by the caller.

    The file must be a JSONL (JSON list) file.

    Examples:

    ---
    import std.datetime : Date;
    import std.stdio : File;

    auto record = readRecord(File("myfile.jsonl"), Date(2020, 1, 1));
    ---

    Throws:

    [InvalidJSON] if the record is not a valid JSON object.

    [InvalidRecord] if there is no record for the given date in the file.
*/
Record readRecord(FILE = File)(FILE history, in Date date) {
    import std.json : parseJSON;

    size_t file_pos = 0;
    char[] buf;

    while (history.readln(buf) > 0) {
        scope(failure) {
            import std.conv : text;
            throw new InvalidJSON("Record is not a JSON object.", buf.text);
        }

        auto tokens = readTokenStream(buf);
        enforce(tokens.length == 3);

        enforce(
            tokens[0].tryMatch!(
                (Symbol s) => s == Symbol.Brace
            )
        );

        enforce(
            tokens[2].tryMatch!(
                (Symbol s) => s == Symbol.Colon
            )
        );

        const rec_date = tokens[1].tryMatch!(
            (string s) => s
        );

        if (rec_date == date.toISOExtString()) {
            return Record(parseJSON(buf), file_pos);
        }

        file_pos += buf.length;
    }

    throw new InvalidRecord("No record found for specified date.");
}

@("Read a record as JSON")
unittest {
    import std.datetime.date : Date;
    import std.json : parseJSON;
    import camino.test_util : FakeFile;

    auto text =
`{"2020-01-01": { "Eat lunch": false, "Read": { "goal": 500, "instances": [100, 350, 50, 1] }, "Get out of bed": { "goal" : "<6:31", "actual": "5:00" }}}
{"2020-01-02": { "Eat lunch": "skip", "Read": { "goal": 500, "instances": [100, 350, 50, 1] }, "Get out of bed": { "goal" : "<6:31", "actual": "5:00" }, "Litterbox": true }}
{"2020-01-03": { "Eat lunch": false, "Read": { "goal": 500, "instances": [100, 350, 50, 1] }, "Get out of bed": { "goal" : "<6:31", "actual": "5:00" }}}`;

    assert(readRecord(FakeFile(text), Date(2020, 1, 1)) ==
        parseJSON(`{"2020-01-01": { "Eat lunch": false, "Read":
            { "goal": 500, "instances": [100, 350, 50, 1] },
            "Get out of bed": { "goal" : "<6:31", "actual": "5:00" }}}`
        )
    );
}

@("readRecord throws an exception on an invalid JSON object")
unittest {
    import std.exception : assertThrown;
    import camino.test_util : FakeFile;

    auto brokenDictionary = "{\"2020-01-01\": { \"Get out of bed\": }}\n";
    auto notAnObject = "\"2020-01-01\"\n";

    assertThrown!InvalidJSON(
        readRecord(FakeFile(brokenDictionary), Date(2020, 01, 01)));
    assertThrown!InvalidJSON(
        readRecord(FakeFile(notAnObject), Date(2020, 01, 01)));
}

@("readRecord throws an exception if the desired record is not found")
unittest {
    import std.exception : assertThrown;
    import camino.test_util : FakeFile;

    auto noDate = `{"Eat Lunch": true}`;
    auto otherDate = `{"2020-01-01": { "Get out of bed": false }}`;

    assertThrown!InvalidRecord(
        readRecord(FakeFile(noDate), Date(2020, 01, 01)));
    assertThrown!InvalidRecord(
        readRecord(FakeFile(otherDate), Date(2020, 01, 02)));
}

private:

/** Serialze an [Actual] object as a [JSONValue]. */
pragma(inline)
pure nothrow
JSONValue toJSONValue(Actual actual) {
    import std.exception : assertNotThrown;

    // JSONValue's constructor can throw on some invalid assignments, but we are
    // guaranteed to be valid here.
    return actual.match!(
        (TimeOfDay t) => JSONValue(["actual": t.toISOExtString()]),
        (bool b) => JSONValue(["actual": b]),
        (int i) => JSONValue(["actual": i])
    ).assertNotThrown();
}

/** Update the specified record with the provided instance data.

    Notes:

    This function is not able to update a previously-set instance; only the next
    unset instance.

    Throws:

    [InvalidRecord] if the JSON record is invalid.

    [InvalidCommand] if all instances have already been set.
*/
// TODO: This will not be sufficient for all updates; e.g., read 500 pages
// weekly -- we won't have a fixed number of instances to track but only care
// about the sum of whatever instances are present. Need to rethink this.
JSONValue updateInstance(JSONValue record, const Instance newInstance) {
    import std.json : JSONType;

    // Insert the given value into the instances array.
    auto insert(T)(JSONValue record, T value) {
        enforce(
            validateInstanceTypes!T(record),
            new InvalidRecord(
                "Cannot add value to " ~ T.stringof ~ " array.",
                record
            )
        );

        foreach (ref elem; record["instances"].array) {
            if (elem.type == JSONType.null_) {
                elem = value;
                return record;
            }
        }
        throw new InvalidCommand("All habit instances have already been set.");
    }

    return newInstance.match!(
        (bool b) => insert(record, b),
        (ulong l) => insert(record, l),
        (Skip s) => {
            if (! (validateInstanceTypes!ulong(record)
                || validateInstanceTypes!bool(record)))
            {
                throw new InvalidRecord("Cannot add value to array.", record);
            }

            foreach (ref elem; record["instances"].array) {
                if (elem.type == JSONType.null_) {
                    elem = JSONValue("skip");
                    return record;
                }
            }
            throw new InvalidCommand(
                "All habit instances have already been set."
            );
        }()
    );
}

@("updateInstance updates an array of boolean values")
unittest {
    auto rec = JSONValue(["instances":
        [JSONValue(true), JSONValue(false), JSONValue("skip"), JSONValue(null)]
    ]);

    updateInstance(rec, Instance(true));
    assert(rec["instances"].array.length == 4);
    assert(rec["instances"][0] == JSONValue(true), rec.toString());
    assert(rec["instances"][1] == JSONValue(false), rec.toString());
    assert(rec["instances"][2] == JSONValue("skip"), rec.toString());
    // We changed this one:
    assert(rec["instances"][3] == JSONValue(true), rec.toString());
}

@("updateInstance updates the next unset (non-null) value")
unittest {
    auto rec = JSONValue(["instances":
        [JSONValue(true), JSONValue(null), JSONValue(null), JSONValue(null)]
    ]);

    updateInstance(rec, Instance(true));
    assert(rec["instances"].array.length == 4);
    assert(rec["instances"][0] == JSONValue(true), rec.toString());
    // We changed this one:
    assert(rec["instances"][1] == JSONValue(true), rec.toString());

    assert(rec["instances"][2] == JSONValue(null), rec.toString());
    assert(rec["instances"][3] == JSONValue(null), rec.toString());
}

@("updateInstance can add a skip")
unittest {
    auto rec = JSONValue(["instances":
        [JSONValue(0), JSONValue(1), JSONValue(null), JSONValue(null)]
    ]);

    updateInstance(rec, Instance(Skip.Skip));
    assert(rec["instances"].array.length == 4);
    assert(rec["instances"][0] == JSONValue(0), rec.toString());
    assert(rec["instances"][1] == JSONValue(1), rec.toString());
    // We changed this one:
    assert(rec["instances"][2] == JSONValue("skip"), rec.toString());

    assert(rec["instances"][3] == JSONValue(null), rec.toString());
}

@("updateInstance throws if all instances have previously been set.")
unittest {
    import std.exception : assertThrown;
    auto rec = JSONValue(["instances": [JSONValue(0), JSONValue(1)]]);
    assertThrown!InvalidCommand(updateInstance(rec, Instance(Skip.Skip)));
}

enum Symbol { Brace, Colon };
alias Token = SumType!(Symbol, string);

/** Read and return a stream of tokens from a partial JSON line.

    Validation of the JSON must be performed by the caller. We only read until
    we find a colon, assuming that what precedes it is the beginning of a JSON
    object; we then return the tokens we have read.

    Notes:

    This function exists for efficiency; we can obtain the key of our JSON
    object without parsing the full object, allowing us to only parse the object
    in the JSONL that we care about.

    Throws:

    Throws [InvalidJSON] if we are recognized to be an invalid object. Note
    that we only parse enough of the text to ensure it is a JSON object with a
    string-typed key.
*/
@safe pure
Token[] readTokenStream(in const(char[]) line) {
    Token[] tokens;
    size_t idx = 0;

    while (idx < line.length) {
        auto tok = readToken(line[idx..$]);
        tokens ~= tok[1];
        idx += tok[0];

        const do_break = tok[1].match!(
            (Symbol s) => s == Symbol.Colon,
            _ => false
        );
        if (do_break) break;
    }
    return tokens;
}

/** Read the next token from the provided text.

    We only recognize a small subset of valid token, since we only need to read
    the beginning of an object to ensure we're a JSON object with a string key.

    Notes:

    Only [readTokenStream] should call this function. That is likely the
    function you're looking for.

    Throws:

    Throws [InvalidJSON] if we are recognized to be an invalid object. Note
    that we only parse enough of the text to ensure it is a JSON object with a
    string-typed key.
*/
@safe pure
Tuple!(size_t, Token) readToken(in const(char[]) line)
    in(line.length > 0)
{
    import std.conv : text;
    import std.typecons : tuple;
    import std.uni : isWhite;

    size_t len = 0;
    // FIXME: I know the length of a valid record here. Make this a static
    // array; we can return when full even if we haven't reached a colon
    // (invalid record).
    char[] token;
    bool inString = false;

    // Our parsing here does not allow for { or : in strings; any such string
    // would be invalid and readRecord() will check that so we don't need to
    // care here.
    foreach (ch; line) {
        if (ch.isWhite()) {
            // Should never be possible since we're reading by line.
            if (ch == '\n') assert(0, "newline cannot happen");
            ++len;
        } else if (ch == '{') {
            return tuple(len + 1, Token(Symbol.Brace));
        } else if (ch == ':') {
            return tuple(len + 1, Token(Symbol.Colon));
        } else if (ch == '"') {
            if (inString) {
                return tuple(len, Token(token.dup));
            } else {
                ++len;
                inString = true;
            }
        } else {
            if (inString) {
                token ~= ch;
                ++len;
            } else {
                throw new InvalidJSON(
                    "Unexpected token in JSON object: " ~ ch,
                    line.text
                );
            }
        }
    }

    throw new InvalidJSON("Invalid record: not a JSON object.", line.text);
}

@("readToken parses early JSON object tokens")
unittest {
    assert(readToken(`{ "adsf"`)[1] == Token(Symbol.Brace));
    assert(readToken(`{"adsf"`)[1] == Token(Symbol.Brace));
    assert(readToken(`{1`)[1] == Token(Symbol.Brace));
    assert(readToken(`{`)[1] == Token(Symbol.Brace));

    assert(readToken(`"asdf"`)[1] == Token("asdf"));
    assert(readToken(`"asdf"`)[1] == Token("asdf"));
    assert(readToken(`"asdf"`)[1] == Token("asdf"));
}

@("readToken throws on non-object creation tokens")
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidJSON(readToken("asdf"));
    assertThrown!InvalidJSON(readToken("[1]"));
    assertThrown!InvalidJSON(readToken("1"));
    assertThrown!InvalidJSON(readToken("}"));
}

/** Determine whether the provided [JSONValue] is a valid instance array. */
pure nothrow
bool validateInstanceTypes(T)(in JSONValue arr)
    if (is(T == ulong) || is(T == bool))
{
    import std.json : JSONType;

    scope(failure) { return false; }

    if (arr.type != JSONType.object || arr["instances"].type != JSONType.array)
    {
        return false;
    }

    // We use this to work around the awkwardness of JSONValue's type
    // handling and separate the compile time and run time conditional
    // statements.
    static if (is(T == bool)) {
        const typeCheck =
            "elem.type == JSONType.true_ || elem.type == JSONType.false_";
    } else {
        const typeCheck =
            "elem.type == JSONType.uinteger || elem.type == JSONType.integer";
    }

    bool foundNull = false;

    foreach (elem; arr["instances"].array) {
        if (elem.type == JSONType.null_) {
            foundNull = true;
        } else if (mixin(typeCheck)) {
            if (foundNull) return false;
        } else if (elem.type == JSONType.string) {
            if (foundNull) return false;
            return elem.str == "skip";
        } else {
            // Invalid element type.
            return false;
        }
    }

    return true;
}

@("validateInstanceTypes correctly validates Instance arrays")
unittest {
    auto boolean = JSONValue(
        ["instances": [JSONValue(true), JSONValue(false),
            JSONValue("skip"), JSONValue(null)]]);
    auto integral = JSONValue(
        ["instances": [JSONValue(1), JSONValue(2),
            JSONValue("skip"), JSONValue(3), JSONValue(4)]]);

    auto noMixedTypes = JSONValue(
        ["instances": [JSONValue(false), JSONValue(0)]]);
    auto nothingFollowsNull = JSONValue(
        ["instances": [JSONValue(1), JSONValue(2),
            JSONValue(null), JSONValue(3)]]);
    auto notAnInstance = JSONValue([JSONValue(1), JSONValue(2), JSONValue(3)]);

    assert(validateInstanceTypes!bool(boolean));
    assert(validateInstanceTypes!ulong(integral));

    // No implicit conversions
    assert(! validateInstanceTypes!ulong(boolean));
    assert(! validateInstanceTypes!bool(integral));
    assert(! validateInstanceTypes!ulong(noMixedTypes));
    assert(! validateInstanceTypes!bool(noMixedTypes));

    assert(! validateInstanceTypes!ulong(nothingFollowsNull));
    assert(! validateInstanceTypes!ulong(notAnInstance));
}
