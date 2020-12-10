/** Read and write to the Camino history file. */
module camino.history;

import std.datetime.date : Date, TimeOfDay;
import std.exception : enforce;
import std.json : JSONValue;
import std.stdio : File;
import std.typecons : Tuple;

import camino.exception;
import camino.goal;
import camino.habit;

import sumtype;


enum Task { Complete, Incomplete };

alias Update = SumType!(Task, Goal);


/** Update the specified `Habit` for the given date according to `Update`. */
void update(FILE = File)(FILE history, Date date, Habit habit, Update update) {
    import std.stdio : writeln; // tmp

    auto record = readRecord(history, date);

    /* Next steps: modify, reserialize, replace at line.

       If we're not the last line of the file, copy everything to a temp file,
       fixing the updated record, then replace the temp w/ the history file.
       Otherwise, we can just replace the last line; this should be the common
       case
     */

    writeln("\nCurrent: ", record);
    //writeln("\nInner: ", record[date.toISOExtString()]);

    auto newRecord = update.match!(
        (Task t) => JSONValue(t == Task.Complete),
        (Goal g) => g.toJSONValue()
    );

    //record[date.toISOExtString()][habit.description] = newRecord;


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
JSONValue readRecord(FILE = File)(FILE history, in Date date) {
    import std.json : parseJSON;
    import std.range : stride;

    foreach (line; history.byLine()) {
        scope(failure) {
            import std.conv : text;
            throw new InvalidJSON("Record is not a JSON object.", line.text);
        }

        auto tokens = readTokenStream(line);
        enforce(tokens.length == 3);

        enforce(
            tokens[0].tryMatch!(
                (Symbol s) => s == Symbol.Brace
            )
        );

        // This check is technically not necessary, since this is when
        // readTokenStream returns.
        enforce(
            tokens[2].tryMatch!(
                (Symbol s) => s == Symbol.Colon
            )
        );

        auto rec_date = tokens[1].tryMatch!(
            (string s) => s
        );

        if (rec_date == date.toISOExtString()) return parseJSON(line);
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

    auto brokenDictionary = `{"2020-01-01": { "Get out of bed": }}`;
    auto notAnObject = `"2020-01-01"`;

    // TODO: This first is failing with InvalidRecord.
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

        auto do_break = tok[1].match!(
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

    // TODO: Custom exception type(s) for parse errors.

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
