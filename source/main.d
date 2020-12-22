import std.datetime.date : Date;

import camino.habit : Habit;
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

// TODO: Turn all exceptions that reach us into nicer error messages.
int main(string[] args) {
    import std.stdio : File;
    import camino.habit : readHabits;

    auto habitsFile = File("habits.txt", "r");
    auto historyFile = File("history.jsonl", "r+");

    auto habits = readHabits(habitsFile);

    return ReturnCode.Success;
}
