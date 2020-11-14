module camino.goal;

import std.string : startsWith;
import std.conv : to;
import std.datetime.date : TimeOfDay;
import std.exception : enforce;
import std.typecons : Tuple, tuple;

version(unittest) import std.exception : assertThrown;

import sumtype;

enum Ordering {
    Equal,
    LessThan,
    GreaterThan
}

alias GoalValue = SumType!(int, TimeOfDay);

struct Goal {
    Ordering ordering;
    GoalValue goal;
    string unit;
}

Goal parseGoal(string goal) {
    import std.uni : isNumber;
    import std.string : indexOf, strip;
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

    auto goalTuple = parseValue(goal);
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

private:

/** Return the integral or time value in the goal string, and the number of
    characters read comprising the returned value.
*/
Tuple!(GoalValue, ulong) parseValue(string goal) {
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
        // TODO: I want to allow flexible time parsing (esp allow AM/PM).
        return tuple(GoalValue(parseTime(val)), val.length);
    } else {
        return tuple(GoalValue(val.to!int), val.length);
    }
}

@("parseValue can parse a number as a number")
unittest {
    auto s = GoalValue(23);
    assert(parseValue("23") == tuple(GoalValue(23), 2));
    assert(parseValue("23 somethings") == tuple(GoalValue(23), 2));
}

@("parseValue can parse a 24-hour time value")
unittest {
    assert(parseValue("4:34") == tuple(GoalValue(TimeOfDay(4, 34, 00)), 4));
    assert(parseValue("14:34") == tuple(GoalValue(TimeOfDay(14, 34, 00)), 5));
}

/** Parse a time string to a `TimeOfDay` object.

    No validation of the time is performed; insufficient time parts will yield
    an `Exception`; invalid time values will throw a
    `std.datetime.date.DateTimeException`.
*/
// TODO: We can also throw parse errors on string to int conversion; document.
TimeOfDay parseTime(const(char[]) time) {
    // TODO: Throw DateTimeException for parse errors.
    import std.array : split;

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
