/** Contains helper code and objects for use in unit tests. */
module camino.test_util;

/** Fake a [std.stdio.File] for unit tests.

    Instead of passing a file's path to the constructor, pass the text to be
    read. This allows unit testing functions that read from a file without
    needing to read from the filesystem.

    Examples:

    ---
    import std.stdio : File, writeln;

    void readFile(FILE = File)(FILE file) {
        foreach (line; file.byLine()) {
            writeln(line);
        }
    }

    unittest {
        auto file = FakeFile("line 1\nline 2\nline3");
        readFile(file);
    }

    void main() {
        auto file = File("path/to/file.txt");
        readFile(file);
    }
    ---
*/
struct FakeFile {
    /** Create a new [FakeFile].

        Params:
            text = The text of the "file" for callers to work with.
    */
    pure @nogc
    this(string text) { this.text = text; }

    /** Return a range to read the file line by line. */
    pure
    auto byLine() const {
        return FakeFileByLineRange(text);
    }

    size_t readln(C, R = dchar)(ref C[] buf, R terminator = '\n') {
        import std.algorithm : countUntil;
        auto len = text.countUntil(terminator);
        assert(len+1 <= text.length);
        buf = cast(C[])text[0..len+1];

        text = text[len + 1 .. $];
        return len + 1;
    }

    private:

    string text;
}

private struct FakeFileByLineRange {
    pure:

    this(string text) {
        import std.string : split;
        this.text = text.split('\n');
    }

    @nogc
    @property
    auto front() const {
        return text[0];
    }

    pure @nogc
    @property
    bool empty() const {
        return text.length == 0;
    }

    pure @nogc
    void popFront() {
        text = text[1..$];
    }

    pure
    auto moveFront() {
        auto tmp = front();
        popFront();
        return tmp;
    }

    private:

    string[] text;
}

@("FakeFile can read text byLine")
unittest {
    auto text =
`Line 1
Line 2
Line 3`;

    auto file = FakeFile(text);
    auto reader = file.byLine();

    assert(reader.moveFront() == "Line 1");
    assert(reader.moveFront() == "Line 2");
    assert(reader.front() == "Line 3");
}

@("FakeFile readln with buffer")
unittest {
    import std.conv : to;

    auto text =
`Line 1
Line 2
Line 3
`;

    auto file = FakeFile(text);
    size_t line;
    char[] buf;

    int count = 1;

    while (file.readln(buf) > 0) {
        assert(buf.length == 7, buf.length.to!string());
        assert(
            buf.to!string() == "Line " ~ count.to!string() ~ "\n",
            buf.to!string()
        );
        count += 1;
    }
}
