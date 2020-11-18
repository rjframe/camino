module camino.history;

import std.datetime.date : Date, TimeOfDay;
import std.exception : enforce;

import camino.goal;
import camino.habit;

import asdf;
import sumtype;

/** The number of bytes at a time to read from the history file. */
private enum FileChunkSize = 4096;

/* Asdf's undocumented Asdf.Kind values as of 0.6.7:
enum Kind : ubyte
{
    null_  = 0x00,
    true_  = 0x01,
    false_ = 0x02,
    number = 0x03,
    string = 0x05,
    array  = 0x09,
    object = 0x0A,
}
*/
alias Kind = Asdf.Kind;

// I cannot use something like `enum Complete;` with SumType so have a
// single-element enum.
/** Marks a task as fully completed. */
enum Task { Complete };

/** The type of update to make to a habit with any relevant value. */
alias Update = SumType!(Task, Goal);

/** Marks an instance of a habit as intentionally skipped. */
enum Skip { Instance }

/** Measure the instances of a task performed for unit-based goals. */
alias Instance = SumType!(Skip, bool, int);

/** Measure the actual performance of a habit without unit-based goals. */
alias Actual = SumType!(bool, TimeOfDay);

/** Represent a single record in our history of tasks. */
struct DailyHabit {
    string name;
    Ordering goalOrder;
    GoalValue goal;

    // TODO: Should I merge these? There will only be one initialized.
    Actual actual;
    Instance[] instances;
}

/** Read the record for the given `Date` from the specified file. */
Asdf readRecord(FILE)(FILE history, Date date) {
    import std.algorithm : each, filter;
    import std.conv : text;
    import std.range : tee;

    int total_lines = 1;
    // Line number of the match. Multiple matches is an error.
    int matched_line = 0;
    // Catch duplicate records.
    int total_matches = 0;

    auto current = history.byChunk(FileChunkSize)
        .parseJsonByLine()
        .tee!(_ => ++total_lines)
        // This will crash if the JSON isn't an object.
        .filter!(obj => obj.byKeyValue().front()[0] == date.toISOExtString())
        .tee!(_ => {
            ++total_matches;
            matched_line = total_lines;
        }())
        ;

    // `current` will destroy its data on a call to `popFront()` so we copy it
    // first, allowing us to then drain the range and ensure we have only one
    // matching record.
    auto record = Asdf(current.front().data.dup);
    current.each();

    enforce(total_matches == 1,
        "There are " ~ total_matches.text
            ~ " records for the date " ~ date.toISOExtString()
    );

    return record;
}

/** Update the specified `Habit` for the given date according to `Update`. */
void update(FILE = File)(FILE history, Date date, Habit habit, Update update) {
    import std.stdio : writeln; // tmp

    auto record = readRecord(history, date)
        .toHabitRecord();

    // Next steps: modify, reserialize, replace at line.

    writeln("\nCurrent: ", record);

}

private:

DailyHabit[] toHabitRecord(Asdf record) {
    import std.algorithm : startsWith;

    DailyHabit[] habits;

    auto date = record.byKeyValue().front()[0];

    foreach (elem; record[date].byKeyValue()) {
        // TODO: Assert actual xor instances is initialized once we're finished.
        DailyHabit habit;
        habit.name = elem.key.dup;

        switch (elem.value.kind()) {
            case Kind.true_:
                habit.actual = Actual(true);
                break;
            case Kind.false_:
                habit.actual = Actual(false);
                break;
            case Kind.object:
                foreach (obj; elem.value.byKeyValue()) {
                    if (obj.key == "goal") {
                        switch (obj.value.kind()) {
                            case Kind.true_:
                                habit.goal = GoalValue(true);
                                break;
                            case Kind.false_:
                                habit.goal = GoalValue(false);
                                break;
                            case Kind.number:
                                habit.goal = GoalValue(obj.value.get(1));
                                break;
                            case Kind.string:
                                auto val = obj.value.get("");

                                Ordering order = Ordering.Equal;
                                if (val.startsWith('<')) {
                                    order = Ordering.LessThan;
                                    val = val[1 ..$];
                                } else if (val.startsWith('>')) {
                                    order = Ordering.GreaterThan;
                                    val = val[1 ..$];
                                }
                                habit.goalOrder = order;
                                habit.goal = parseGoalValue(val)[0];

                                break;
                            default:
                                throw new Exception("Invalid goal.");
                        }
                    } else if (obj.key == "instances") {
                        foreach (instance; obj.value.byElement()) {
                            habit.instances ~= toInstance(instance);
                        }
                    } else if (obj.key == "actual") {
                        habit.actual = toActual(obj.value);
                    }
                }
                break;
            default:
                throw new Exception("Invalid habit data.");
        }

        habits ~= habit;
    }

    return habits;
}

// TODO: Unit tests on toHabitRecord.

/** Convert an `Asdf` object to an `Instance`.

    The provided object is assumed to be a valid instance and will throw an
    exception on any deserialization errors.
*/
// TODO: would it be cleaner to wrap Instance in a struct w/ alias this and
// write a deserialize method?
Instance toInstance(Asdf instance) {
    switch (instance.kind()) {
        case Kind.true_:
            return Instance(true);
        case Kind.false_:
            return Instance(false);
        case Kind.string:
            if (instance.get("") == "skip") {
                return Instance(Skip.Instance);
            } else {
                throw new Exception("Invalid instance value.");
            }
        case Kind.number:
            auto num = instance.get!int(-1);
            enforce(num >= 0,
                "Negative values for goals are not supported."
            );
            return Instance(num);
        default:
            throw new Exception("Invalid instance value.");
    }
}

@("toInstance parses boolean values")
unittest {
    assert(toInstance(parseJson("true")) == Instance(true));
    assert(toInstance(parseJson("false")) == Instance(false));
}

@("toInstance parses numeric literals")
unittest {
    assert(toInstance(parseJson("15")) == Instance(15));
}

@("toInstance parses skips")
unittest {
    assert(toInstance(Asdf("skip")) == Instance(Skip.Instance));
}

/** Convert an `Asdf` object to an `Actual` object. */
// TODO: would it be cleaner to wrap Actual in a struct w/ alias this and
// write a deserialize method?
Actual toActual(Asdf actual) {
    switch (actual.kind()) {
        case Kind.true_:
            return Actual(true);
        case Kind.false_:
            return Actual(false);
        case Kind.string:
            // We're reusing the parseGoalValue code since it's identical except
            // we won't have integers.
            auto value = parseGoalValue(actual.get(""))[0];

            return value.tryMatch!(
                (TimeOfDay t) => Actual(t),
            );
        default:
            throw new Exception(
                "Cannot convert object to an actual measurement."
            );
    }
}

@("toActual parses boolean values")
unittest {
    assert(toActual(parseJson("true")) == Actual(true));
    assert(toActual(parseJson("false")) == Actual(false));
}

@("toActual parses time values")
unittest {
    assert(toActual(Asdf("15:00")) == Actual(TimeOfDay(15, 0, 0)));
}
