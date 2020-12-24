/** Schedule parsing and management for [camino.habit.Habit|Habit]s. */
module camino.schedule;

import std.algorithm : startsWith;
import std.datetime.date : DayOfWeek;
import std.exception : enforce;

version(unittest) import std.exception : assertThrown;

import sumtype;

import camino.exception : InvalidSchedule;


@safe:

/** Set the repetition period for a goal.

    At least for now, only daily habits can be negative (undesired).
*/
enum Repeat {
    Daily,
    DailyNegative,
    Weekly,
    Monthly,
}

/** Describes the repeat method of a `SpecialRepeat` object.

    ## See also

    The [SpecialRepeat] struct.
*/
alias RepeatInterval = SumType!(Repeat, DayOfWeek);

/** Store the schedule data for special schedules.

    Special repetitions are not simple (daily, every Tuesday, etc.) but may
    repeat multiple times a period (three times daily) or cover a span of time
    period (every three weeks, etc.).
*/
struct SpecialRepeat {
    /** The interval at which the habit is expected to recur. */
    RepeatInterval interval;
    /** Specifies every three days, every other week, etc. */
    int numberOfIntervals;
    /** A number of repetitions per instance associated with the goal. */
    // TODO: This is set in the goals field; should it be in this struct?
    int numberPerInstance;
    // TODO assert: SpecialRepeat always uses this instead of
    // Repeat.DailyNegative.
    /** Sets whether this is an undesireable habit. A [SpecialRepeat] will
        always use this instead of the [Repeat].DailyNegative enum value.
    */
    bool negative;
}

alias Schedule = SumType!(Repeat, SpecialRepeat);

/** Parse a goal's schedule from the provided string.

    Throws:

    [InvalidSchedule] if unable to parse the schedule string or if the number of
    a habit's daily occurences is 0.
*/
pure
const(Schedule) parseSchedule(string schedule)
    in(schedule.length > 0)
{
    import std.uni : isNumber;
    import std.conv : to;

    if (startsWith!isNumber(schedule)) {
        import std.string : indexOf;

        auto splitIdx = schedule.indexOf(' ');

        if (splitIdx == -1) {
            throw new InvalidSchedule(
                "A number in the schedule must be followed by a unit.",
                schedule
            );
        }

        int number;
        string repeatType;
        try {
            number = schedule[0..splitIdx].to!int;
            repeatType = schedule[splitIdx+1 .. $];
        } catch (Exception e) {
            throw new InvalidSchedule(
                "Failed to parse repetition string.",
                schedule
            );
        }
        enforce(number > 0,
            new InvalidSchedule("Cannot have a repetition period of 0.",
                schedule));

        if (repeatType.isRepeatInterval()) {
            return Schedule(SpecialRepeat(
                RepeatInterval(repeatType.toRepeat()), number, 1, false
            ));
        } else {
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
            return Schedule(SpecialRepeat(
                RepeatInterval(sched.toDayOfWeek()),
                1,
                1,
                true
            ));
        }
    } else { // Does not start with a number or '-'.
        if (schedule.isRepeatInterval()) {
            return Schedule(schedule.toRepeat());
        } else {
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
    assert(parseSchedule("daily").tryMatch!(s => s == Repeat.Daily));
    assert(parseSchedule("weekly").tryMatch!(s => s == Repeat.Weekly));
    assert(parseSchedule("monthly").tryMatch!(s => s == Repeat.Monthly));

    assert(parseSchedule("Tue").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(DayOfWeek.tue), 1, 1, false)
    ));

    assertThrown(parseSchedule("other"));
}

@("Parse non-simple repeating schedules.")
unittest {
    assert(parseSchedule("2 days").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(Repeat.Daily), 2, 1, false)
    ));

    assert(parseSchedule("3 weeks").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(Repeat.Weekly), 3, 1, false)
    ));

    assert(parseSchedule("3 Wed").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(DayOfWeek.wed), 3, 1, false)
    ));
}

@("Parse negative schedules")
unittest {
    assert(parseSchedule("-daily").tryMatch!(s => s == Repeat.DailyNegative));

    assert(parseSchedule("-Mon").tryMatch!(s =>
        s == SpecialRepeat(RepeatInterval(DayOfWeek.mon), 1, 1, true)
    ));
}

private:

/** Convert the provided string to a [DayOfWeek] enumerated value.

    Any unique day abbreviations are allowed; for example, "Sun" will match
    Sunday, but "S" will be an error because it could match Sunday or Saturday.

    Matches are case-insensitive.

    Throws:

    [InvalidSchedule] if the day string is invalid.
*/
// TODO: Return an optional type instead of throw?
pure
DayOfWeek toDayOfWeek(string day) {
    import std.string : toLower;

    if (day.length == 0) throw new InvalidSchedule("No day provided.");

    auto day_ = day.toLower();

    if ("monday".startsWith(day_)) {
        return DayOfWeek.mon;
    } else if ("tuesday".startsWith(day_)) {
        return DayOfWeek.tue;
    } else if ("wednesday".startsWith(day_)) {
        return DayOfWeek.wed;
    } else if ("thursday".startsWith(day_)) {
        return DayOfWeek.thu;
    } else if ("friday".startsWith(day_)) {
        return DayOfWeek.fri;
    } else if ("saturday".startsWith(day_)) {
        return DayOfWeek.sat;
    } else if ("sunday".startsWith(day_)) {
        return DayOfWeek.sun;
    } else {
        throw new InvalidSchedule("Unrecognized day.", day);
    }
}

/** Returns true if the provided string matches a repeat interval; otherwise,
    returns false.
*/
pure @nogc nothrow
bool isRepeatInterval(in string interval) {
    return interval == "days" || interval == "daily"
        || interval == "weeks" || interval == "weekly"
        || interval == "months" || interval == "monthly";
}

/** Convert a string to a [Repeat] enumeration. */
pure
Repeat toRepeat(string interval) {
    switch (interval) {
        case "days":
        case "daily":
            return Repeat.Daily;
        case "weeks":
        case "weekly":
            return Repeat.Weekly;
        case "months":
        case "monthly":
            return Repeat.Monthly;
        default:
            throw new InvalidSchedule("Invalid repeat interval.", interval);
    }
}
