/** Read and write to the Camino history file. */
module camino.history;

import std.datetime.date : Date, TimeOfDay;
import std.exception : enforce;
import std.json : JSONValue;
import std.stdio : File;
import std.typecons : Tuple;

import camino.exception;
import camino.goal : Actual = GoalValue;
import camino.habit : Habit;

import sumtype;

/** Mark a task as complete or incomplete.

    Currently only Task.Complete is explicitly used.
*/
enum Task { Complete, Incomplete }

/** Represents any type of update that can be made to a [Record]. */
alias Update = SumType!(Task, Actual, Instance);

/** Specifies that an instance of a goal was skipped. */
enum Skip : string { Skip = "skip" }

/** Represents the data associated with an instance of a goal. */
alias Instance = SumType!(ulong, bool, Skip);

/** Stores information concerning an individual record from the history file. */
struct Record(FILE = File) {
    // TODO: make readRecord, etc. methods of this?

    /** $(B $(I disabled)) */
    // TODO: File bug on adrdox -> $(NEVER_DOCUMENT) is ignored.
    @disable this();

    /** Create a new [Record] of the specified JSON object and the file position
        from which that object was read.

        It is the caller's responsibility to validate that the [JSONValue]
        represents a valid record.
    */
    nothrow
    this(ref FILE history, JSONValue record, size_t file_pos) {
        this.file = history;
        this.rec = record;
        this.file_pos = file_pos;
    }

    /** Create a new [Record] of the specified JSON object and the file position
        from which that object was read.

        It is the caller's responsibility to validate that the [JSONValue]
        represents a valid record.
    */
    this(ref FILE history, const(char[]) record, size_t file_pos) {
        import std.json : parseJSON;

        this.file = history;
        this.rec = parseJSON(record);
        this.file_pos = file_pos;
    }

    /** Retrieve the index into the source file from which the record was read.
    */
    pure nothrow @nogc
    @property
    size_t pos() const { return this.file_pos; }

    /** Provides access to the underlying [JSONValue] record.

        This method is `alias this`ed to the [Record]; operations should be
        typically performed directly on the [Record] object instead of
        explicitly via this method.

        Examples:

        ---
        import std.json : JSONValue;
        import std.stdio : File, writeln;

        auto sourceFile = File("path/to/file");
        // Assume data came from sourceFile.
        auto data = JSONValue(`{"2020-01-01": {}, "v": "1.0.0"}`);
        auto record = Record!File(sourceFile, data, 0);

        // These two statements are identical:
        writeln(record.toPrettyString());
        writeln(record.record().toPrettyString());
        ---
    */
    // TODO: Should I be providing a reference or provide read-only access
    // instead?
    @property
    pure nothrow @nogc
    auto ref JSONValue record() const { return this.rec; }

    alias record this;

    /** Write this record to the file, replacing the original data in the
        record.

        If the record is the last line of the file, replaces the record.
        Otherwise, writes to a temporary file then replaces the original file
        with the temporary.
    */
    // TODO: Handle/document exceptions.
    void writeToFile() {
        import std.stdio : LockType;

        auto line = this.rec.toString();

        if (this.atLastLine()) {
            scope(exit) { this.file.unlock(); }

            // TODO: length should go to the end of the file (end of existing
            // line).
            this.file.lock(LockType.readWrite, this.file_pos, line.length);

            auto current_pos = this.file.tell();

            this.file.seek(this.file_pos);
            this.file.write(line);
            this.file.truncate(this.file_pos + line.length);
            this.file.writeln();
            this.file.seek(current_pos);
        } else {
            assert(0, "not implemented");
        }
    }

    private:

    /** Returns true if the record was read from the last line of the file;
        otherwise, returns false.
    */
    // TODO: Document exceptions
    bool atLastLine() {
        scope(exit) {
            this.file.seek(this.file_pos);
        }

        char[] buf;

        this.file.seek(this.file_pos);
        this.file.readln(buf);

        return this.file.readln(buf) == 0;
    }

    FILE file;
    JSONValue rec;
    ulong file_pos;
}

@("Record.atLastLine() determines whether we're at the file's final line")
unittest {
    import camino.test_util : FakeFile;

    auto file = FakeFile("Line 1\nLine 2\nLine 3\n");

    auto record = Record!FakeFile(file, JSONValue(true), 0);
    assert(! record.atLastLine());

    record = Record!FakeFile(file, JSONValue(true), 14);
    assert(record.atLastLine());
}

@("Record.writeToFile() updates a record at the last line")
unittest {
    import camino.test_util : FakeFile;

    auto file = FakeFile("[false]\nfalse\n{\"val\": 1}\n");
    auto record = Record!FakeFile(file, JSONValue([true]), 14);

    record.writeToFile();
    auto reader = record.file.byLine();
    assert(reader.front() == "[false]", reader.front());
    reader.popFront();
    assert(reader.front() == "false", reader.front());
    reader.popFront();
    assert(reader.front() == "[true]", reader.front());
    reader.popFront();
    assert(reader.empty());
}

/** Append an empty record for the given habits to the end of the file for the
    specified date.

    Params:
        file =   A history file open for writing.
        date =   The date for which to create the record. It is the caller's
                 responsibility to ensure that the date given is unique within
                 the file.
        habits = The list of [Habit]s that will comprise the record.

    Throws:

    [Exception] or [std.exception.ErrnoException] on failure to write to the
    file.
*/
void appendEmptyRecord(FILE = File)(
    FILE file,
    in Date date,
    const Habit[] habits
)
    in(file.isOpen())
{
    const record = habits.toJSONRecord(date);
    const file_pos = file.tell();

    scope(exit) {
        file.seek(file_pos);
    }

    file.seek(file.size);
    file.writeln(record);
}

@("appendEmptyRecord writes the date object first")
unittest {
    import camino.schedule : Repeat, Schedule;
    import camino.goal : Goal, GoalValue;
    import camino.test_util : FakeFile;
    import std.algorithm : startsWith;

    auto file = FakeFile("");

    const habits = [
        Habit(
            Schedule(Repeat.Daily),
            "Habit 1",
            Goal(GoalValue(true))
        )
    ];

    appendEmptyRecord(file, Date(2020, 1, 1), habits);

    assert(file.readText()[1..$].startsWith(`{"2020-01-01"`), file.readText());
}

@("appendEmptyRecord creates an empty history record from Habits")
unittest {
    import camino.schedule : Repeat, SpecialRepeat, Schedule;
    import camino.goal : Goal, GoalValue;
    import camino.test_util : FakeFile;
    import std.json : parseJSON;

    auto file = FakeFile("");

    SpecialRepeat habitThreeRepeat = {
        interval: Repeat.Daily,
        numberOfIntervals: 1,
        numberPerInstance: 2,
        negative: false
    };

    const habits = [
        Habit(
            Schedule(Repeat.Daily),
            "Habit 1",
            Goal(GoalValue(true))
        ),
        Habit(
            Schedule(Repeat.Daily),
            "Habit 2",
            Goal(GoalValue(50))
        ),
        Habit(
            Schedule(habitThreeRepeat),
            "Habit 3",
            Goal(GoalValue(50))
        ),
    ];

    appendEmptyRecord(file, Date(2020, 1, 1), habits);

    assert(file.readText().parseJSON() ==
        parseJSON(
            `{"2020-01-01":{"Habit 1":{"actual":false,"goal":true},`
            ~ `"Habit 2":{"actual":0,"goal":50},`
            ~ `"Habit 3":{"goal":50,"instances":[null,null]}},`
            ~ `"version":"1.0.0"}`
        )
    );
}

@("appendEmptyRecord appends to the end of the history file")
unittest {
    import camino.schedule : Repeat, SpecialRepeat, Schedule;
    import camino.goal : Goal, GoalValue, Ordering;
    import camino.test_util : FakeFile;
    import std.json : parseJSON;

    auto file = FakeFile(
        `{"2020-01-01":{"Habit 1":{"actual":false,"goal":true},`
        ~ `"Habit 2":{"actual":0,"goal":50},`
        ~ `"Habit 3":{"goal":50,"instances":[null,null]}}},`
        ~ `"Habit 4":{"goal":">50","instances":[null,null]}},`
        ~ `"version":"1.0.0"}`
    );

    SpecialRepeat habitFourRepeat = {
        interval: Repeat.Daily,
        numberOfIntervals: 1,
        numberPerInstance: 4,
        negative: false
    };

    const habits = [
        Habit(
            Schedule(Repeat.Daily),
            "Habit 1",
            Goal(GoalValue(true))
        ),
        Habit(
            Schedule(Repeat.Daily),
            "Habit 2",
            Goal(GoalValue(20))
        ),
        Habit(
            Schedule(habitFourRepeat),
            "Habit 3",
            Goal(GoalValue(50))
        ),
        Habit(
            Schedule(habitFourRepeat),
            "Habit 4",
            Goal(Ordering.GreaterThan, GoalValue(50))
        ),
    ];

    appendEmptyRecord(file, Date(2020, 1, 2), habits);

    char[] buf;

    // Read the previously-existing line.
    file.readln(buf);
    assert(buf.parseJSON() ==
        parseJSON(
            `{"2020-01-01":{"Habit 1":{"actual":false,"goal":true},`
            ~ `"Habit 2":{"actual":0,"goal":50},`
            ~ `"Habit 3":{"goal":50,"instances":[null,null]}}},`
            ~ `"Habit 4":{"goal":">50","instances":[null,null]}},`
            ~ `"version":"1.0.0"}`
        )
    );

    // Now read our added line.
    file.readln(buf);

    assert(buf.parseJSON() ==
        parseJSON(
            `{"2020-01-02":{"Habit 1":{"actual":false,"goal":true},`
            ~ `"Habit 2":{"actual":0,"goal":20},`
            ~ `"Habit 3":{"goal":50,"instances":[null,null,null,null]},`
            ~ `"Habit 4":{"goal":">50","instances":[null,null,null,null]}},`
            ~ `"version":"1.0.0"}`
        ),
        buf
    );
}

/** Update the specified `Habit` for the given date.

    Params:
        history = An opened file from which to read records.
        date    = the date to update.
        habit   = The habit whose status to update.
        update  = The action to record.

    Throws:

    [InvalidRecord] when an error processing a record occurs.

    [InvalidCommand] if an [Instance] is provided after they have all been
    previously updated.

    [std.json.JSONException] if attempting to make incompatible
    [camino.goal.GoalValue|Actual] updates.
*/
// TODO: Should I replace JSONException with InvalidRecord or InvalidCommand?
void update(FILE = File)(
    FILE history,
    in Date date,
    in Habit habit,
    in Update update
) {
    auto record = readRecord(history, date);

    // TODO: Throw exception if the record does not already include the habit?
    // We need to have a complete record, and requiring that it exist prior to
    // updating makes that simpler for us here.

    const newRecord = update.match!(
        (Task t) => JSONValue(t == Task.Complete),
        (Actual a) =>
            updateActual(record[date.toISOExtString()][habit.description], a),
        (Instance i) =>
            updateInstance(record[date.toISOExtString()][habit.description], i)
    );

    record[date.toISOExtString()][habit.description] = newRecord;
    record.writeToFile();
}

@("update can update a Task record.")
unittest {
    import camino.goal : Goal, GoalValue;
    import camino.schedule : Repeat, Schedule;
    import camino.test_util : FakeFile;

    auto file = FakeFile(`{"2020-01-01":{"Habit":false}}`);

    const habit = Habit(
        Schedule(Repeat.Daily),
        "Habit",
        Goal(GoalValue(true))
    );

    update(
        file,
        Date(2020, 1, 1),
        habit,
        Update(Task.Complete)
    );

    assert(file.readText() == `{"2020-01-01":{"Habit":true}}` ~ '\n',
        file.readText());
}

@("update can update an Actual record")
unittest {
    import camino.goal : Goal, GoalValue;
    import camino.schedule : Repeat, Schedule;
    import camino.test_util : FakeFile;

    auto file = FakeFile(`{"2020-01-01":{"Habit":{"actual":10}}}`);

    const habit = Habit(
        Schedule(Repeat.Daily),
        "Habit",
        Goal(GoalValue(50))
    );

    update(
        file,
        Date(2020, 1, 1),
        habit,
        Update(Actual(20))
    );

    assert(file.readText() == `{"2020-01-01":{"Habit":{"actual":30}}}` ~ '\n',
        file.readText());
}

@("update can update an Instance record")
unittest {
    import camino.goal : Goal, GoalValue;
    import camino.schedule : Repeat, SpecialRepeat, Schedule;
    import camino.test_util : FakeFile;

    auto file = FakeFile(`{"2020-01-01":{"Habit":{"instances":[1, null]}}}`);

    SpecialRepeat repeat = {
        interval: Repeat.Daily,
        numberOfIntervals: 1,
        numberPerInstance: 2,
        negative: false
    };

    const habit = Habit(
        Schedule(repeat),
        "Habit",
        Goal(GoalValue(50))
    );

    update(
        file,
        Date(2020, 1, 1),
        habit,
        Update(Instance(20))
    );

    assert(
        file.readText() ==
            `{"2020-01-01":{"Habit":{"instances":[1,20]}}}` ~ '\n',
        file.readText()
    );
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
Record!FILE readRecord(FILE = File)(FILE history, in Date date) {
    import std.json : parseJSON;

    size_t file_pos = 0;
    char[] buf;

    // TODO: Make this a do..while so I can use tell?
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
            return Record!FILE(history, parseJSON(buf), file_pos);
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
`{"2020-01-01": { "Eat lunch": false, "Read": {`
   ~ ` "goal": 500, "instances": [100, 350, 50, 1] }, "Get out of bed": {`
      ~ ` "goal" : "<6:31", "actual": "5:00" }}}
{"2020-01-02": { "Eat lunch": "skip", "Read": {`
   ~ ` "goal": 500, "instances": [100, 350, 50, 1] }, "Get out of bed": {`
      ~ ` "goal" : "<6:31", "actual": "5:00" }, "Litterbox": true }}
{"2020-01-03": { "Eat lunch": false, "Read": {`
   ~ ` "goal": 500, "instances": [100, 350, 50, 1] }, "Get out of bed": {`
      ~ ` "goal" : "<6:31", "actual": "5:00" }}}`;

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

/** Truncate a file to the specified size in bytes.

    On Windows the file must be opened for writing.

    The current file position after a `truncate()` call is undefined; if you
    need to keep your position within the file, call [File.tell] prior to
    truncating, then seek after truncation.

    Note that truncating a text file may mean there is no longer a newline at
    the end of the file.

    Throws:

    [std.stdio.FileException] on failure to truncate the file.

    On Windows, `truncate()` can also throw:

    * [Exception] if the file is unopened.
    * [std.exception.ErrnoException|ErrnoException] if the OS fails to seek to
      the position at the specified `size`.
*/
void truncate(File file, long size) {
    import std.file : FileException;

    version(Posix) {
        // https://linux.die.net/man/3/ftruncate
        import core.stdc.errno : errno;
        import core.sys.posix.unistd: ftruncate;

        const result = ftruncate(file.fileno(), size) == 0
            ? 0
            : errno();
    }

    version(Windows) {
        // https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-setendoffile
        import core.sys.windows.windows: SetEndOfFile, GetLastError;

        file.seek(size);
        const result = SetEndOfFile(file.windowsHandle())
            ? 0
            : GetLastError();
    }

    enforce(result == 0, new FileException(file.name, result));
}

@("truncate a file")
unittest {
    import std.path : buildPath;
    import unit_threaded.integration : Sandbox;

    with(immutable Sandbox()) {
        writeFile("test.txt", "abcde");

        auto file = File(buildPath(testPath, "test.txt"), "r+");
        file.truncate(3);

        shouldEqualContent("test.txt", "abc");
    }
}

/** Update the specified record with the provided instance data.

    Notes:

    This function is not able to update a previously-set instance; only the next
    unset instance.

    Throws:

    [InvalidRecord] if the JSON record is invalid.

    [InvalidCommand] if all instances have already been set.
*/
pure
JSONValue updateInstance(JSONValue record, in Instance newInstance) {
    import std.json : JSONType;

    // Helper function to insert the given value into the instances array.
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
        (Skip _) => {
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

/** Update the provided record.

    An integral value will be added to the current value. [TimeOfDay] or or
    boolean values replace whatever may be present.

    Throws:

    [std.json.JSONException] if the record does not contain a compatible
    "actual" object.
*/
pragma(inline)
pure
JSONValue updateActual(JSONValue record, in Actual newValue) {
    return newValue.match!(
        (TimeOfDay t) => JSONValue(["actual": t.toISOExtString()]),
        (bool b) => JSONValue(["actual": b]),
        (int i) => JSONValue(["actual": i + record["actual"].get!long()])
    );
}

/** Build and return the JSON string from the provided habits for the specified
    date.
*/
nothrow
string toJSONRecord(const Habit[] habits, in Date date) {
    import camino.schedule : Repeat, SpecialRepeat;
    import std.json : JSONType;

    scope(failure) {
        // Any exception we could get in this function will be due to either
        // failure to properly validate a [Habit] on creation or a programming
        // error interpreting a Habit in this function.
        assert(0, "Habit object is invalid.");
    }

    const key = date.toISOExtString();
    auto value = JSONValue([key: null]);

    foreach (habit; habits) {
        auto rec = habit.goal.toJSONValue();

        const numberOfInstances = habit.schedule.match!(
            (Repeat r) => 1,
            (SpecialRepeat r) => r.numberPerInstance
        );
        assert(numberOfInstances > 0);

        switch (rec["goal"].type) {
            case JSONType.true_:
            case JSONType.false_:
                rec["actual"] = false;
                break;
            case JSONType.string:
                if (numberOfInstances == 1) {
                    rec["actual"] = null;
                } else {
                    rec["instances"] = JSONValue([null]);
                    for (int i = 0; i < numberOfInstances - 1; ++i) {
                        // TODO: Why can I not append JSONValue(null)? Throws
                        // JSONException "not an array".
                        rec["instances"] ~= JSONValue([null]);
                    }
                }
                break;
            case JSONType.integer:
            case JSONType.uinteger:
                if (numberOfInstances == 1) {
                    rec["actual"] = 0;
                } else {
                    rec["instances"] = JSONValue([null]);
                    for (int i = 0; i < numberOfInstances - 1; ++i) {
                        // TODO: Why can I not append JSONValue(null)? Throws
                        // JSONException "not an array".
                        rec["instances"] ~= JSONValue([null]);
                    }
                }
                break;
            default:
                assert(0, "Invalid goal.");
        }

        value[key][habit.description] = rec;
    }

    // We cannot guarantee that version comes after the date with a JSONValue,
    // so we'll convert it to string then add it.
    return {
        auto json = value.toString();
        return json[0..$-1] ~ `,"version":"1.0.0"}`;
    }();
}


enum Symbol { Brace, Colon }
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
