import std.algorithm : splitter;
import std.datetime.date : Date;

import camino.habit;
import camino.history;

/** A `Command` describes the command input from the command-line arguments. */
struct Command {
    Action action;
    Date date;
    Habit habit;
    // TODO: <type> goalProgress;
}

/** The action to perform on a `Habit` via a `Command`. */
enum Action {
    Do,
    Not,
    Skip
}

enum ReturnCode : int {
    Success = 0,
    BadCommand = 1
}

int main(string[] args) {
    // TODO: Turn all exceptions that reach us into nicer error messages.
    readHabits("habits.txt");


    import std.stdio : File;
    update(File("history.jsonl"), Date(2020, 1, 1));

    return 0;
}

Habit[] readHabits(string filePath) {
    import std.stdio : File;
    import std.string : entab, strip;

    auto file = File(filePath, "r");
    Habit[] habits;
    char[] buf;

    while (file.readln(buf)) {
        if (buf[0] == '#' || buf[0] == '\n') continue;
        string[] fields;
        fields.reserve(3);

        foreach (field; buf.entab(4).splitter('\t')) {
            if (field == "") continue;
            fields ~= field.strip().dup();
        }

        if (fields.length != 2 && fields.length != 3) {
            throw new Exception(
                "Invalid number of fields in habits file:\n\t" ~ cast(string)buf
            );
        }

        habits ~= Habit(fields);
    }

    return habits;
}
