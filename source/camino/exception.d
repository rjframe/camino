/** Camino custom exceptions.

    Note: I do not postfix the names with "Exception"; since I only catch and
    throw exceptions, that's redundant. I like the way it reads with the shorter
    names, and it easily differentiates my exceptions from third-party
    exceptions.
*/
module camino.exception;

/** Thrown upon failure to parse a JSON object. */
class ParseJSON : Exception {
    @nogc nothrow pure @safe
    this(string msg) {
        super(msg);
    }

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

    override void toString (scope void delegate(scope const char[]) sink) const
    {
        sink(this.msg);
        if (parsedLine) {
            sink("\n\tWhile parsing line: \"");
            sink(this.parsedLine);
            sink(`"`);
        }
    }

    private string parsedLine;
}

/** Thrown when parsing or working with an object that is valid JSON but not a
    valid Camino record.
*/
class InvalidRecord : Exception {
    import std.json : JSONValue;

    @nogc nothrow pure @safe
    this(string msg) {
        super(msg);
    }

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

    override void toString (scope void delegate(scope const char[]) sink) const
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
