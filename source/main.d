import camino.history;


// TODO: Turn all exceptions that reach us into nicer error messages.
int main(string[] args) {
    import std.stdio : File, writeln;
    import camino.habit : readHabits;
    import camino.optparse;

    switch (args[1]) {
        case "do":
            break;
        case "list":
            break;
        case "not":
            break;
        case "skip":
            break;
        case "-h":
        case "--help":
            writeln(helpText);
            break;
        default:
            writeln(helpText);
            return ReturnCode.BadCommand;
    }

    // These will likely not be opened in main.
    auto habitsFile = File("habits.txt", "r");
    auto historyFile = File("history.jsonl", "r+");
    auto habits = readHabits(habitsFile);

    return ReturnCode.Success;
}
