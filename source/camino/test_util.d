/** Contains helper code and objects for use in unit tests. */
module camino.test_util;

@safe:

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

@("FakeFile can read text line by line")
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
