module camino.history;

import std.datetime.date : Date, TimeOfDay;
import std.exception : enforce;
import std.json : JSONValue;
import std.stdio : File;
import std.typecons : Tuple;

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

JSONValue readRecord(FILE = File)(FILE history, Date date) {
    import std.json : parseJSON;
    import std.range : stride;

    foreach (line; history.byLine()) {
        auto tokens = readTokenStream(line);
        // TODO: Custom parse error exception
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

        auto rec_date = tokens[1].tryMatch!(
            (string s) => s
        );

        if (rec_date == date.toISOExtString) return parseJSON(line);
    }

    throw new Exception("No record found for specified date.");
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

    auto noDate = `{"Eat Lunch": true}`;
    auto brokenDictionary = `{"2020-01-01": { "Get out of bed": }}`;
    auto notAnObject = `"2020-01-01"`;

    assertThrown(readRecord(FakeFile(noDate), Date(2020-01-01)));
    assertThrown(readRecord(FakeFile(brokenDictionary), Date(2020-01-01)));
    assertThrown(readRecord(FakeFile(notAnObject), Date(2020-01-01)));
}

@("readRecord throws an exception if the desired record is not found")
unittest {
    import std.exception : assertThrown;
    import camino.test_util : FakeFile;

    auto text = `{"2020-01-01": { "Get out of bed": false }}`;

    assertThrown(readRecord(FakeFile(text), Date(2020-01-02)));
}

private:

enum Symbol { Brace, Colon, Invalid};

alias Token = SumType!(Symbol, string);

Token[] readTokenStream(const(char[]) line) {
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

/** Read the next token from the JSON stream.

    We only recognize a small subset of valid token, since we only need to read
    the beginning of an object.
*/
Tuple!(size_t, Token) readToken(const(char[]) line)
    in(line.length > 0)
{
    import std.typecons : tuple;
    import std.uni : isWhite;

    size_t len = 0;
    char[] token;
    bool inString = false;

    // TODO: Custom exception type for parse errors.

    // Our parsing here does not allow for { or : in strings; any such string
    // would be invalid and readRecord() will check that so we don't need to
    // care here.
    foreach (ch; line) {
        if (ch.isWhite()) {
            // We are reading from a JSONL file.
            enforce(ch != '\n', "Unexpected newline in JSON line.");
            ++len;
        } else if (ch == '{') {
            return tuple(len + 1, Token(Symbol.Brace));
        } else if (ch == ':') {
            return tuple(len + 1, Token(Symbol.Colon));
        } else if (ch == '"') {
            if (inString) {
                return tuple(len, Token(cast(string) token));
            } else {
                ++len;
                inString = true;
            }
        } else {
            if (inString) {
                token ~= ch;
                ++len;
            } else {
                throw new Exception("Unexpected token in JSON object: " ~ ch);
            }
        }
    }

    // Invalid records (i.e., not a JSON object) may reach here; we do the
    // validation in readRecord() so we just return the incomplete token stream
    // here as Symbol.Invalid.
    return tuple(len, Token(Symbol.Invalid));
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

@("readToken throws on newline")
unittest {
    import std.exception : assertThrown;

    assertThrown(readToken("\n"));
    assertThrown(readToken(" \n\"asdf\""));
    assertThrown(readToken("\"jk\nl;\""));
    assertThrown(readToken("\n\"key\""));
}

@("readToken throws on non-object creation tokens")
unittest {
    import std.exception : assertThrown;

    assertThrown(readToken("asdf"));
    assertThrown(readToken("[1]"));
    assertThrown(readToken("1"));
    assertThrown(readToken("}"));
}
