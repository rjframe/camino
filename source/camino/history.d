module camino.history;

import std.datetime.date : Date, TimeOfDay;
import std.exception : enforce;
import std.json : JSONValue;
import std.stdio : File;
import std.typecons : Tuple;

import camino.goal;
import camino.habit;

import sumtype;


/** Update the specified `Habit` for the given date according to `Update`. */
void update(FILE = File)(FILE history, Date date) { // , Habit habit, Update update) {
    import std.stdio : writeln; // tmp

    auto record = readRecord(history, date);

    /* Next steps: modify, reserialize, replace at line.

       If we're not the last line of the file, copy everything to a temp file,
       fixing the updated record, then replace the temp w/ the history file.
       Otherwise, we can just replace the last line; this should be the common
       case
     */

    writeln("\nCurrent: ", record);

}

JSONValue readRecord(FILE = File)(FILE history, Date date) {
    import std.stdio;
    import std.range : stride;
    foreach (line; history.byLine()) {
        auto tokens = readTokenStream(line);
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

        if (rec_date == date.toISOExtString) return JSONValue(line);
    }

    throw new Exception("No record found for specified date.");
}


private:

enum Symbol { Brace, Colon };

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
Tuple!(size_t, Token) readToken(const(char[]) line) {
    import std.typecons : tuple;
    import std.uni : isWhite;

    size_t len = 0;
    char[] token;
    bool inString = false;

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

    assert(0, "Should have returned before reaching end of function.");
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
