/** Contains code related to reading, writing, and inspecting goal data. */
module camino.goal;

import std.datetime.date : TimeOfDay;
import std.exception : enforce;
import std.json : JSONValue;
import std.typecons : Tuple, tuple;

version(unittest) import std.exception : assertThrown;

import sumtype;

@safe:

/** A Goal can be less than, equal to, or greater than some value.

    For example, "fewer than 3 instances", "100 steps", "more than 50 pages".
*/
enum Ordering : char {
    Equal = '=',
    LessThan = '<',
    GreaterThan = '>'
}

alias GoalValue = SumType!(int, TimeOfDay, bool);

/** Represents a goal as specified in a habits file. */
struct Goal {
    /** Specifies whether the goal is to be below, reach, or exceed its value.
    */
    Ordering ordering = Ordering.Equal;
    /** The value of the goal. */
    GoalValue value = GoalValue(true);
    /** An optional unit to describe the the goal's [Goal.value|value]. */
    string unit = "";

    pure
    this(Ordering ordering, GoalValue value, string unit = "") {
        this.ordering = ordering;
        this.value = value;
        this.unit = unit;
    }

    pure
    this(GoalValue value, string unit = "") {
        this.ordering = Ordering.Equal;
        this.value = value;
        this.unit = unit;
    }

    /** Serialize this goal to a [std.json.JSONValue]. */
    pure nothrow
    const(JSONValue) toJSONValue() const {
        import std.conv : text, to;
        import std.string : isNumeric;

        string goalString =
            ordering == Ordering.LessThan ? "<"
            : ordering == Ordering.GreaterThan ? ">"
            : "";

        goalString ~= value.match!(
            (TimeOfDay t) => t.toISOExtString(),
            (bool b) => b.text,
            (int i) => i.text
        );

        JSONValue val;
        if (goalString.isNumeric()) {
            try {
                // We converted from int to string above, now back to int. We
                // could alternatively unwrap goal again.
                val = JSONValue(goalString.to!int);
            } catch (Exception e) {
                // `conv.to` can throw if our input is numeric; this is safe
                // since we've just checked, short of any bugs in `conv.to`.
                // Eating the error here lets us make this method nothrow.
                assert(0, e.msg);
            }
        } else if (goalString == "true") {
            val = JSONValue(true);
        } else if (goalString == "false") {
            val = JSONValue(false);
        } else {
            val = JSONValue(goalString);
        }

        // This can be done without creating an associative array, at the
        // expense of @safety.
        return JSONValue(["goal": val]);
    }
}

@("Serialize a Goal to JSON")
unittest {
    import std.json : parseJSON;

    assert(
        Goal(Ordering.Equal, GoalValue(5), "stuff").toJSONValue()
        == parseJSON(`{"goal":5}`)
    );
    assert(
        Goal(Ordering.LessThan, GoalValue(5), "stuff").toJSONValue()
        == parseJSON(`{"goal":"<5"}`)
    );
    assert(
        Goal(Ordering.Equal, GoalValue(TimeOfDay(1, 2, 30)), "").toJSONValue()
        == parseJSON(`{"goal":"01:02:30"}`)
    );
    assert(
        Goal(
            Ordering.GreaterThan, GoalValue(TimeOfDay(1, 2, 30)), ""
        ).toJSONValue()
        == parseJSON(`{"goal":">01:02:30"}`)
    );
    assert(
        Goal(Ordering.Equal, GoalValue(true), "stuff").toJSONValue()
        == parseJSON(`{"goal":true}`)
    );
    assert(
        Goal(Ordering.Equal, GoalValue(false), "stuff").toJSONValue()
        == parseJSON(`{"goal":false}`)
    );
}

/** Parse a goal from the given goal string.

    An empty goal is an implicit goal of "1".

    Throws:

    [camino.exception.InvalidGoal|InvalidGoal] on invalid data.
*/
pure
Goal parseGoal(string goal) {
    import std.uni : isNumber;
    import std.string : strip, startsWith;
    import camino.exception : InvalidGoal;

    if (goal.length == 0) {
        // An empty goal is just an implicit 1 undefined unit.
        return Goal(Ordering.Equal, GoalValue(1), "");
    }

    Ordering order = Ordering.Equal;
    if (goal[0].isOrdering()) {
        order = cast(Ordering)goal[0];
        goal = goal[1..$];
    }

    if (! goal.startsWith!isNumber()) {
        throw new InvalidGoal("Missing goal value.", goal);
    }

    auto parsedGoal = parseGoalValue(goal);

    const isTimeValue = parsedGoal.value.match!(
        (TimeOfDay _) => true,
        _ => false
    );

    if (isTimeValue && parsedGoal.length != goal.length) {
        throw new InvalidGoal("Time value cannot have units.", goal);
    }

    return Goal(order, parsedGoal.value, goal[parsedGoal.length..$].strip());
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
    import camino.exception : InvalidGoal;
    assertThrown!InvalidGoal(parseGoal("12:30 books"));
    assertThrown!InvalidGoal(parseGoal("2:30 AM"));
}


private:

/** Return whether a character is a valid [Ordering] character. */
pragma(inline)
pure @nogc nothrow
bool isOrdering(char ch) {
    return ch == '=' || ch == '<' || ch == '>';
}

/** Parse the integral or time value from a goal string.

    We scan until we reach whitespace, parsing the text until then. If anything
    that follows the whitespace could make the value invalid, it is the caller's
    responsibility to validate it.

    Returns:

    A tuple of the parsed value and the number of characters read from the
    string.

    Throws:

    [camino.exception.InvalidGoal|InvalidGoal] if the string is not a valid time
    or numeric value.
*/
pure
Tuple!(GoalValue, "value", size_t, "length") parseGoalValue(string goal)
    in(goal.length > 0, "Empty goal string.")
{
    import std.uni : isNumber, isWhite;
    import camino.exception : InvalidGoal;

    char[] val;
    val.reserve(goal.length);
    bool isTime = false;

    foreach (ch; goal) {
        if (ch.isNumber()) {
            val ~= ch;
        } else if (ch == ':') {
            val ~= ch;
            isTime = true;
        } else if (ch.isWhite()) {
            break;
        } else {
            throw new InvalidGoal("Invalid value.", goal);
        }
    }

    try {
        alias tup = Tuple!(GoalValue, "value", size_t, "length");

        if (isTime) {
            return tup(GoalValue(parseTime(val)), val.length);
        } else {
            import std.conv : to;
            return tup(GoalValue(val.to!int), val.length);
        }
    } catch (Exception e) {
        // `e` can be a DateTimeException or ConvException.
        // TODO: Cannot chain the exception due to scope rules.
        throw new InvalidGoal("Invalid goal.", goal);
    }
}

@("parseGoalValue can parse a number as a number")
unittest {
    assert(parseGoalValue("23") == tuple(GoalValue(23), 2));
    assert(parseGoalValue("23 somethings") == tuple(GoalValue(23), 2));
}

@("parseGoalValue can parse a 24-hour time value")
unittest {
    assert(parseGoalValue("4:34") == tuple(GoalValue(TimeOfDay(4, 34, 00)), 4));
    assert(parseGoalValue("14:34")
        == tuple(GoalValue(TimeOfDay(14, 34, 00)), 5));
}

@("parseGoalValue throws on invalid input")
unittest {
    import camino.exception : InvalidGoal;
    assertThrown!InvalidGoal(parseGoalValue("123a"));
}

/** Parse a time string to a [TimeOfDay] object.

    The input string must be a 24-hour time in the format `[H]H:MM[:SS]`.

    Throws:

    [std.conv.ConvException] if the value is not formatted as a time or if time
    values are not numeric.

    [std.datetime.DateTimeException] if the specified time is not valid.
*/
pure
TimeOfDay parseTime(in const(char[]) time) {
    // TODO: I want to allow flexible time parsing (esp allow AM/PM).
    import std.array : split;
    import std.conv : to, ConvException;
    import std.datetime : DateTimeException;

    auto parts = time.split(':');
    enforce!ConvException(parts.length == 2 || parts.length == 3,
        "No time value provided.");

    enforce!DateTimeException(parts[0].length == 1 || parts[0].length == 2,
        "Invalid hour provided.");
    enforce!DateTimeException(parts[1].length == 2, "Invalid minute provided.");

    if (parts.length == 2) {
        return TimeOfDay(parts[0].to!int, parts[1].to!int);
    } else if (parts.length == 3) {
        enforce!DateTimeException(parts[2].length == 2,
            "Invalid second provided.");
        return TimeOfDay(parts[0].to!int, parts[1].to!int, parts[2].to!int);
    } else {
        throw new DateTimeException("Invalid time: " ~ time.to!string);
    }
}

@("parseTime can parse a 24-hour strings.")
unittest {
    assert(parseTime("12:34") == TimeOfDay(12, 34, 0));
    assert(parseTime("2:34") == TimeOfDay(2, 34, 0));
    assert(parseTime("2:34:16") == TimeOfDay(2, 34, 16));
}

@("parseTime throws on invalid time strings.")
unittest {
    import std.conv : ConvException;
    import std.datetime : DateTimeException;

    auto twelveHour = "12:34 AM";
    auto hasLabel = "12:10 something";
    assertThrown!DateTimeException(parseTime(twelveHour));
    assertThrown!DateTimeException(parseTime(hasLabel));

    auto notNumeric = "12:AB";
    auto notATimeString = "some string";
    assertThrown!ConvException(parseTime(notNumeric));
    assertThrown!ConvException(parseTime(notATimeString));
}
