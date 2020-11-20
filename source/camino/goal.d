module camino.goal;

import std.datetime.date : TimeOfDay;
import std.exception : enforce;
import std.typecons : Tuple, tuple;

version(unittest) import std.exception : assertThrown;

import asdf;
import sumtype;

enum Ordering {
    Equal,
    LessThan,
    GreaterThan
}

alias GoalValue = SumType!(int, TimeOfDay, bool);

struct Goal {
    Ordering ordering;
    GoalValue goal;
    string unit;

    /** Deserialize an `Asdf` object into a `Goal`.

        We do not validate the newly created Goal against the relevant `Habit`
        because we may be reading an older version of a habit that no longer
        matches its current definition (or may no longer exist).
    */
    static typeof(this) deserialize(Asdf data) {
        return parseGoal(data.get(""));
    }

    void serialize(S)(ref S serializer)
        //if (is(S == JsonSerializer) || is(S == AsdfSerializer))
        // TODO: What should these be?
    {
        import std.conv : text;

        auto objState = serializer.objectBegin();
        serializer.putKey("goal");

        auto goalValue = goal.match!(
            (TimeOfDay t) => t.toISOExtString(),
            (bool b) => b.text,
            (int i) => i.text
        );

        string goalString =
            ordering == Ordering.LessThan ? "<"
            : ordering == Ordering.GreaterThan ? ">"
            : "";

        goalString ~= goalValue;

        import std.string : isNumeric;
        if (goalString.isNumeric()) {
            // We basically converted from int to string now back to int, but
            // the code is more straightforward than anything I can think of
            // without the conversions.
            serializer.putNumberValue(goalString);
        } else if (goalString == "true") {
            serializer.putValue(true);
        } else if (goalString == "false") {
            serializer.putValue(false);
        } else {
            serializer.putValue(goalString);
        }

        serializer.objectEnd(objState);
    }
}

@("Serialize a goal to JSON")
unittest {
    assert(
        serializeToJson(Goal(Ordering.Equal, GoalValue(5), "stuff"))
        == `{"goal":5}`,
        serializeToJson(Goal(Ordering.Equal, GoalValue(5), "stuff"))
    );
    assert(
        serializeToJson(Goal(Ordering.LessThan, GoalValue(5), "stuff"))
        == `{"goal":"<5"}`,
        serializeToJson(Goal(Ordering.LessThan, GoalValue(5), "stuff"))
    );
    assert(
        serializeToJson(Goal(
            Ordering.Equal, GoalValue(TimeOfDay(1, 2, 30)), "stuff"))
        == `{"goal":"01:02:30"}`,
        serializeToJson(Goal(
            Ordering.Equal, GoalValue(TimeOfDay(1, 2, 30)), "stuff"))
    );
    assert(
        serializeToJson(Goal(
            Ordering.GreaterThan, GoalValue(TimeOfDay(1, 2, 30)), "stuff"))
        == `{"goal":">01:02:30"}`,
        serializeToJson(Goal(
            Ordering.GreaterThan, GoalValue(TimeOfDay(1, 2, 30)), "stuff"))
    );
    assert(
        serializeToJson(Goal(Ordering.Equal, GoalValue(true), "stuff"))
        == `{"goal":true}`,
        serializeToJson(Goal(Ordering.Equal, GoalValue(true), "stuff"))
    );
    assert(
        serializeToJson(Goal(Ordering.Equal, GoalValue(false), "stuff"))
        == `{"goal":false}`,
        serializeToJson(Goal(Ordering.Equal, GoalValue(false), "stuff"))
    );
}

/** Parse a goal from a string. */
Goal parseGoal(string goal) {
    import std.uni : isNumber;
    import std.string : indexOf, strip, startsWith;
    import std.conv : to;

    if (goal.length == 0) {
        // An empty goal is just an implicit 1 undefined unit.
        return Goal(Ordering.Equal, GoalValue(1), "");
    }

    Ordering order;
    if (goal.startsWith('<')) {
        order = Ordering.LessThan;
        goal = goal[1 ..$];
    } else if (goal.startsWith('>')) {
        order = Ordering.GreaterThan;
        goal = goal[1 ..$];
    }

    enforce(goal.startsWith!isNumber(), "Missing goal value in " ~ goal);

    auto goalTuple = parseGoalValue(goal);
    GoalValue parsedGoal = goalTuple[0];
    ulong parsedLength = goalTuple[1];

    bool isTimeValue = parsedGoal.match!(
        (TimeOfDay _1) => true,
        _ => false
    );

    if (isTimeValue) {
        enforce(parsedLength == goal.length,
            "Time value cannot have units: " ~ goal
        );
    }

    return Goal(order, parsedGoal, goal[parsedLength..$].strip());
}

@("parseGoal provides a default for implicit goals")
unittest {
    assert(parseGoal("") == Goal(Ordering.Equal, GoalValue(1), ""));
}

@("parseGoal parses integral goals with and without units")
unittest {
    assert(parseGoal("2 rooms") == Goal(Ordering.Equal, GoalValue(2), "rooms"));
    assert(parseGoal("2") == Goal(Ordering.Equal, GoalValue(2), ""));
}

@("parseGoal parses time values")
unittest {
    assert(parseGoal("6:30") ==
        Goal(Ordering.Equal, GoalValue(TimeOfDay(6, 30, 0)),"")
    );
}

@("parseGoal understands comparisons")
unittest {
    assert(parseGoal("<10 units") ==
        Goal(Ordering.LessThan, GoalValue(10), "units")
    );
    assert(parseGoal(">10 units") ==
        Goal(Ordering.GreaterThan, GoalValue(10), "units")
    );

    assert(parseGoal("<12:40") ==
        Goal(Ordering.LessThan, GoalValue(TimeOfDay(12, 40, 0)), "")
    );
    assert(parseGoal(">12:40") ==
        Goal(Ordering.GreaterThan, GoalValue(TimeOfDay(12, 40, 0)), "")
    );
}

@("parseGoal does not allow units with time values")
unittest {
    assertThrown(parseGoal("12:30 books"));
}

/** Return the integral or time value in the goal string, and the number of
    characters read comprising the returned value.
*/
Tuple!(GoalValue, ulong) parseGoalValue(string goal) {
    import std.conv : to;
    import std.uni : isNumber;

    char[] val;
    val.reserve(goal.length);
    bool isTime = false;

    foreach (ch; goal) {
        if (ch.isNumber()) {
            val ~= ch;
        } else if (ch == ':') {
            val ~= ch;
            isTime = true;
        } else {
            break;
        }
    }

    if (isTime) {
        return tuple(GoalValue(parseTime(val)), val.length);
    } else {
        return tuple(GoalValue(val.to!int), val.length);
    }
}

@("parseGoalValue can parse a number as a number")
unittest {
    auto s = GoalValue(23);
    assert(parseGoalValue("23") == tuple(GoalValue(23), 2));
    assert(parseGoalValue("23 somethings") == tuple(GoalValue(23), 2));
}

@("parseGoalValue can parse a 24-hour time value")
unittest {
    assert(parseGoalValue("4:34") == tuple(GoalValue(TimeOfDay(4, 34, 00)), 4));
    assert(parseGoalValue("14:34") == tuple(GoalValue(TimeOfDay(14, 34, 00)), 5));
}

private:

/** Parse a time string to a `TimeOfDay` object.

    No validation of the time is performed; insufficient time parts will yield
    an `Exception`; invalid time values will throw a
    `std.datetime.date.DateTimeException`.
*/
// TODO: We can also throw parse errors on string to int conversion; document.
TimeOfDay parseTime(const(char[]) time) {
    // TODO: I want to allow flexible time parsing (esp allow AM/PM).
    // TODO: Throw DateTimeException for parse errors.
    import std.array : split;
    import std.conv : to;

    auto parts = time.split(':');
    enforce(parts[0].length > 0 && parts[0].length < 3, "Invalid hour.");
    enforce(parts[1].length == 2, "Invalid minute.");

    if (parts.length == 2) {
        return TimeOfDay(parts[0].to!int, parts[1].to!int);
    } else if (parts.length == 3) {
        enforce(parts[2].length == 2, "Invalid second.");
        return TimeOfDay(parts[0].to!int, parts[1].to!int, parts[2].to!int);
    } else {
        throw new Exception("Invalid time: " ~ cast(string)time);
    }
}

@("parseTime can parse a 24-hour strings.")
unittest {
    assert(parseTime("12:34") == TimeOfDay(12, 34, 0));
    assert(parseTime("2:34") == TimeOfDay(2, 34, 0));
}
