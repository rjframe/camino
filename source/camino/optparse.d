/** Parse and interpret command-line arguments. */
module camino.optparse;

import std.datetime.date : Date;

import camino.habit : Habit;


/** The action to perform on a `Habit` via a `Command`. */
enum Action {
    Do,
    Not,
    Skip
}

/** A `Command` describes the command input from the command-line arguments. */
struct Command {
    Action action;
    Date date;
    Habit habit;
    // TODO: <type> goalProgress;
}

enum ReturnCode : int {
    Success = 0,
    BadCommand = 1
}

static const helpText =  "Usage: camino [do|not|skip|list] <options>.\n"
    ~ "\tRun camino <command> --help for help with a specific command.";
