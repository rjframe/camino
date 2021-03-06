/** Camino custom exceptions.

    Note: Names are not postfixed with "Exception"; since we only catch and
    throw exceptions, that's redundant. I like the way it reads with the shorter
    names, especially when using the try/catch syntax; and it easily
    differentiates my exceptions from third-party exceptions.
*/
module camino.exception;


/** Thrown upon failure to parse a JSON object. */
class InvalidJSON : Exception {
    /** Create a new [InvalidJSON] exception. */
    @nogc nothrow pure @safe
    this(string msg) {
        super(msg);
    }

    /** Create a new [InvalidJSON] exception. */
    @nogc nothrow pure @safe
    this(
        string msg,
        string parsedLine,
        string file = __FILE__,
        ulong line = cast(ulong)__LINE__,
        Throwable inner = null
    ) {
        super(msg, file, line, inner);
        this.parsedLine = parsedLine;
    }

    /** Output the exception's message to the provided sink. */
    override void toString(scope void delegate(in char[]) sink) const
    {
        sink(this.msg);
        if (parsedLine.length > 0) {
            sink("\n\tWhile parsing line: \"");
            sink(this.parsedLine);
            sink(`"`);
        }
    }

    private string parsedLine;
}

/** Thrown upon failure to parse a Goal value. */
class InvalidGoal : Exception {
    /** Create a new [InvalidGoal] exception. */
    @nogc nothrow pure @safe
    this(string msg) {
        super(msg);
    }

    /** Create a new [InvalidGoal] exception. */
    @nogc nothrow pure @safe
    this(
        string msg,
        string goalString,
        string file = __FILE__,
        ulong line = cast(ulong)__LINE__,
        Throwable inner = null
    ) {
        super(msg, file, line, inner);
        this.goalString = goalString;
    }

    /** Output the exception's message to the provided sink. */
    override void toString (scope void delegate(in char[]) sink) const
    {
        sink(this.msg);
        if (goalString.length > 0) {
            sink("\n\tWhile parsing goal: \"");
            sink(this.goalString);
            sink(`"`);
        }
    }

    private:

    string goalString;
}

/** Thrown upon failure to parse a Schedule from the habits file. */
class InvalidSchedule : Exception {
    /** Create a new [InvalidSchedule] exception. */
    @nogc nothrow pure @safe
    this(string msg) {
        super(msg);
    }

    /** Create a new [InvalidSchedule] exception. */
    @nogc nothrow pure @safe
    this(
        string msg,
        string scheduleString,
        string file = __FILE__,
        ulong line = cast(ulong)__LINE__,
        Throwable inner = null
    ) {
        super(msg, file, line, inner);
        this.scheduleString = scheduleString;
    }

    /** Output the exception's message to the provided sink. */
    override void toString (scope void delegate(in char[]) sink) const
    {
        sink(this.msg);
        if (scheduleString.length > 0) {
            sink("\n\tWhile parsing goal: \"");
            sink(this.scheduleString);
            sink(`"`);
        }
    }

    private:

    string scheduleString;
}

/** Thrown when parsing or working with an object that is valid JSON but not a
    valid Camino record.
*/
class InvalidRecord : Exception {
    import std.json : JSONValue;

    /** Create a new [InvalidRecord] exception. */
    @nogc nothrow pure @safe
    this(string msg) {
        super(msg);
    }

    /** Create a new [InvalidRecord] exception. */
    @nogc nothrow pure @safe
    this(
        string msg,
        JSONValue record,
        string file = __FILE__,
        ulong line = cast(ulong)__LINE__,
        Throwable inner = null
    ) {
        super(msg, file, line, inner);
        this.record = record;
    }

    /** Output the exception's message to the provided sink. */
    override void toString (scope void delegate(in char[]) sink) const
    {
        sink(this.msg);
        if (this.record != this.record.init) {
            sink("\n\tRecord is: \"");
            this.record.toString(sink);
            sink(`"`);
        }
    }

    private JSONValue record;
}

/** Thrown when a user command or input does not make sense in the current
    context.
*/
class InvalidCommand : Exception {

    /** Create a new [InvalidCommand] exception. */
    @nogc nothrow pure @safe
    this(string msg) {
        super(msg);
    }

    /** Create a new [InvalidCommand] exception. */
    @nogc nothrow pure @safe
    this(
        string msg,
        string file = __FILE__,
        ulong line = cast(ulong)__LINE__,
        Throwable inner = null
    ) {
        super(msg, file, line, inner);
    }
}
