module camino.habit;

import std.algorithm : startsWith;
import std.datetime.date : Date, DayOfWeek;
import std.exception : enforce;

version(unittest) import std.exception : assertThrown;

import sumtype;

enum Repeat {
    Daily,
    DailyNegative,
    Weekly,
    Monthly,
}

/** Describes the repeat method of a `SpecialRepeat` object. */
alias RepeatInterval = SumType!(Repeat, DayOfWeek);

struct SpecialRepeat {
    RepeatInterval interval;
    /** Specifies every three days, every other week, etc. */
    int numberOfIntervals;
    // TODO: This is set in the goals field; should it be in this struct?
    int numberPerInstance;
    // TODO doc+assert: An interval of type Repeat will have a DailyNegative;
    // I'll always use this instead.
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

            // TODO: Catch and rethrow parse error or let it pass?
            auto number = schedule[0..splitIdx].to!int;

            auto repeatType = schedule[splitIdx+1 .. $];

            switch (repeatType) {
                case "days":
                    return Schedule(SpecialRepeat(
                        RepeatInterval(Repeat.Daily),
                        number,
                        1,
                        false
                    ));
                case "weeks":
                    return Schedule(SpecialRepeat(
                        RepeatInterval(Repeat.Weekly),
                        number,
                        1,
                        false
                    ));
                case "months":
                    return Schedule(SpecialRepeat(
                        RepeatInterval(Repeat.Monthly),
                        number,
                        1,
                        false
                    ));
                default:
                    enforce(isDayOfWeek(repeatType),
                        "Invalid schedule unit: " ~ repeatType
                    );

                    return Schedule(SpecialRepeat(
                        RepeatInterval(repeatType.toDayOfWeek()),
                        number,
                        1,
                        false
                    ));
            }
        } else if (schedule.startsWith('-')) {
            // -daily and actual days ("-Wed") are currently all that make
            // sense to me so that's all we're supporting right now.

            auto sched = schedule[1..$];

            if (sched == "daily") {
                return Schedule(Repeat.DailyNegative);
            } else {
                enforce(sched.isDayOfWeek(),
                    "Invalid schedule unit: " ~ sched
                );

                return Schedule(SpecialRepeat(
                    RepeatInterval(sched.toDayOfWeek()),
                    1,
                    1,
                    true
                ));
            }
        } else {
            switch (schedule) {
                case "daily":
                    return Schedule(Repeat.Daily);
                case "weekly":
                    return Schedule(Repeat.Weekly);
                case "monthly":
                    return Schedule(Repeat.Monthly);
                default:
                    enforce(schedule.isDayOfWeek(),
                        "Invalid schedule unit: " ~ schedule
                    );

                    return Schedule(SpecialRepeat(
                        RepeatInterval(schedule.toDayOfWeek()),
                        1,
                        1,
                        false
                    ));
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
    assert(habit.schedule.tryMatch!((SpecialRepeat s) =>
        s == SpecialRepeat(RepeatInterval(DayOfWeek.tue), 1, 1, false)
    ));

    assertThrown(Habit("other", "There is no other"));
}

@("Parse non-simple repeating schedules.")
unittest {
    auto habit = Habit("2 days", "Eat dessert");
    assert(habit.schedule.tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(Repeat.Daily), 2, 1, false)
    ));

    habit = Habit("3 weeks", "Run a marathon");
    assert(habit.schedule.tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(Repeat.Weekly), 3, 1, false)
    ));

    habit = Habit("3 Wed", "Get out of bed");
    assert(habit.schedule.tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(DayOfWeek.wed), 3, 1, false)
    ));
}

@("Parse negative schedules")
unittest {
    auto habit = Habit("-daily", "Go to work");
    assert(habit.schedule.tryMatch!(s => s == Repeat.DailyNegative));

    habit = Habit("-Mon", "Start the week");
    assert(habit.schedule.tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(DayOfWeek.mon), 1, 1, true)
    ));
}


private:

/** Return true if the provided string matches a day of the week; otherwise,
    false.

    Any unique abbreviation is acceptable; "Mon", "Mond", "M" all match Monday.
    However, "S" will return false.
*/
bool isDayOfWeek(string day) {
    // TODO: Should this be an assert/enforce here? It will error later on
    // toDayOfWeek().
    // TODO: Allow lowercase
    if (day.length == 0) return false;
    return "Monday".startsWith(day)
        || ("Tuesday".startsWith(day) && day.length > 1)
        || "Wednesday".startsWith(day)
        || ("Thursday".startsWith(day) && day.length > 1)
        || "Friday".startsWith(day)
        || ("Saturday".startsWith(day) && day.length > 1)
        || ("Sunday".startsWith(day) && day.length > 1);
}

// Separating this from isDayOfWeek means we parse day strings twice for every
// day-specific habit; we're not likely to ever have enough habits for that to
// be noticeable and we get cleaner code.
DayOfWeek toDayOfWeek(string day) {
    enforce(day.length > 0, "No day provided.");

    // TODO: Allow lowercase
    if ("Monday".startsWith(day)) {
        return DayOfWeek.mon;
    } else if ("Tuesday".startsWith(day)) {
        return DayOfWeek.tue;
    } else if ("Wednesday".startsWith(day)) {
        return DayOfWeek.wed;
    } else if ("Thursday".startsWith(day)) {
        return DayOfWeek.thu;
    } else if ("Friday".startsWith(day)) {
        return DayOfWeek.fri;
    } else if ("Saturday".startsWith(day)) {
        return DayOfWeek.sat;
    } else if ("Sunday".startsWith(day)) {
        return DayOfWeek.sun;
    } else {
        throw new Exception("Unrecognized day: " ~ day);
    }
}
