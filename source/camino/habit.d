module camino.habit;

import std.algorithm : startsWith;
import std.datetime.date : Date;
import std.exception : enforce;

version(unittest) import std.exception : assertThrown;

import sumtype;

enum Repeat {
    Daily,
    DailyNegative,
    Weekly,
    Monthly,
}

struct SpecialRepeat {
    Date next;
    int numberPerDay;
    bool negative;
}

alias Schedule = SumType!(Repeat, SpecialRepeat);

/** A `Habit` describes a habit that we need to track. */
struct Habit {
    Schedule schedule;
    string description;
    string goal; // TODO: type

    this(string schedule, string description, string goal = "") {
        // The shortest valid length is for shorthand days (like "Tue").
        enforce(schedule.length >= 3, "Invalid schedule: " ~ schedule);
        // TODO: enforce on goal. Also for description > 0?

        this.schedule = parse(schedule);
        this.description = description;
        //this.goal = parse(goal);
    }

    // Icky but convenient.
    this(string[] fields)
        in(fields.length == 2 || fields.length == 3)
    {
        if (fields.length == 2) {
            this(fields[0], fields[1]);
        } else {
            this(fields[0], fields[1], fields[2]);
        }
    }

    private:

    Schedule parse(string schedule) {
        import std.uni : isNumber;
        import std.string : indexOf;
        import std.conv : to;

        if (startsWith!isNumber(schedule)) {
            auto splitIdx = schedule.indexOf(' ');
            enforce(
                splitIdx > 0 && splitIdx != schedule.length,
                "A number in the schedule must be followed by a unit."
            );

            // TODO: Catch and rethrow parse error? Probably just let it pass.
            auto number = schedule[0..splitIdx].to!int;

            // TODO: Support "2 Mon" for every other Monday, etc.
            switch (schedule[splitIdx+1 .. $]) {
                case "days":
                    return Schedule(Repeat.Daily);
                case "weeks":
                    return Schedule(Repeat.Weekly);
                case "months":
                    return Schedule(Repeat.Monthly);
                default:
                    throw new Exception(
                        "Invalid schedule unit: " ~ schedule[splitIdx+1 .. $]
                    );
            }
        } else if (schedule.startsWith('-')) {
            // -daily and actual days ("-Wed") are currently all that make
            // sense to me so that's all we're supporting right now.
            assert(0, "Unimplemented.");
        } else {
            // TODO: Support specific days.
            switch (schedule) {
                case "daily":
                    return Schedule(Repeat.Daily);
                case "weekly":
                    return Schedule(Repeat.Weekly);
                case "monthly":
                    return Schedule(Repeat.Monthly);
                default:
                    throw new Exception("Invalid schedule unit: " ~ schedule);
            }
        }

        assert(0);
    }
}

@("Parse simple habit schedules.")
unittest {
    auto habit = Habit("daily", "Eat lunch");
    assert(habit.schedule.tryMatch!(s => s == Repeat.Daily));
    habit = Habit("weekly", "Read a book");
    assert(habit.schedule.tryMatch!(s => s == Repeat.Weekly));
    habit = Habit("monthly", "Pay bills");
    assert(habit.schedule.tryMatch!(s => s == Repeat.Monthly));

    habit = Habit("Tue", "Get out of bed");
    // TODO: assert

    assertThrown(Habit("other", "There is no other"));
}

@("Parse non-simple repeating schedules.")
unittest {
    auto habit = Habit("2 days", "Eat dessert");
    // TODO: assert

    habit = Habit("3 weeks", "Run a marathon");
    // TODO: assert

    habit = Habit("3 Wed", "Get out of bed");
    // TODO: assert
}

@("Parse negative schedules")
unittest {
    auto habit = Habit("-daily", "Go to work");
    // TODO: assert

    habit = Habit("-Mon", "Start the week");
    // TODO: assert
}
