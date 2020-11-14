module camino.schedule;

import std.algorithm : startsWith;
import std.datetime.date : DayOfWeek;
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

        if (repeatType.isRepeatInterval()) {
            return Schedule(SpecialRepeat(
                RepeatInterval(repeatType.toRepeat()), number, 1, false
            ));
        } else {
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
        if (schedule.isRepeatInterval()) {
            return Schedule(schedule.toRepeat());
        } else {
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

@("Parse simple habit schedules.")
unittest {
    assert(parse("daily").tryMatch!(s => s == Repeat.Daily));
    assert(parse("weekly").tryMatch!(s => s == Repeat.Weekly));
    assert(parse("monthly").tryMatch!(s => s == Repeat.Monthly));

    assert(parse("Tue").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(DayOfWeek.tue), 1, 1, false)
    ));

    assertThrown(parse("other"));
}

@("Parse non-simple repeating schedules.")
unittest {
    assert(parse("2 days").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(Repeat.Daily), 2, 1, false)
    ));

    assert(parse("3 weeks").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(Repeat.Weekly), 3, 1, false)
    ));

    assert(parse("3 Wed").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(DayOfWeek.wed), 3, 1, false)
    ));
}

@("Parse negative schedules")
unittest {
    assert(parse("-daily").tryMatch!(s => s == Repeat.DailyNegative));

    assert(parse("-Mon").tryMatch!(s =>
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
// TODO: Use an optional type?
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

// TODO: See the comments for toDayOfWeek() -> same problems.
bool isRepeatInterval(string interval) {
    return (interval == "days" || interval == "daily"
        || interval == "weeks" || interval == "weekly"
        || interval == "months" || interval == "monthly");
}

Repeat toRepeat(string interval) {
    if (interval == "days" || interval == "daily") {
        return Repeat.Daily;
    } else if (interval == "weeks" || interval == "weekly") {
        return Repeat.Weekly;
    } else if (interval == "months" || interval == "monthly") {
        return Repeat.Monthly;
    } else {
        throw new Exception("Invalid repeat interval: " ~ interval);
    }
}
