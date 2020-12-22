/** Contains helper code and objects for use in unit tests. */
module camino.test_util;

/** Fake a [std.stdio.File] for unit tests.

    Instead of passing a file's path to the constructor, pass the text to be
    read. This allows unit testing functions that read from a file without
    needing to read from the filesystem.

    Only text-mode reading and writing is supported.

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
    import std.stdio : LockType;

    /** Create a new [FakeFile].

        Params:
            text = The text of the "file" for callers to work with. If the
            string does not end with a new line, one will be added.
    */
    pure
    this(string text) {
        this.data = new FileData(text);
    }

    /** Copy constructor.

        The new [FakeFile] will share the underlying file with the source
        object.
    */
    pure nothrow
    this(FakeFile other) {
        this.data = other.data;
    }

    /** Return a range to read the file line by line. */
    pure
    auto byLine() const {
        return FakeFileByLineRange(this.data.text.dup);
    }

    /** Read a line from the file into the provided buffer.

        The buffer will be expanded if necessary to fit the data on the line. If
        the buffer is larger than necessary, a slice of the buffer whose length
        matches that of the data is returned.

        Returns the number of characters read (this will always match
        buf.length).
    */
    size_t readln(C, R = dchar)(ref C[] buf, R terminator = '\n') {
        import std.algorithm : countUntil;

        auto len = this.data.text[this.data.pos..$].countUntil(terminator) + 1;
        assert(len <= this.data.text.length - this.data.pos);

        buf = cast(C[]) this.data.text[this.data.pos..this.data.pos + len];
        this.data.pos += len;

        return len;
    }

    /** Write to the FakeFile's text buffer at its current file position.

        The type of `S` must be a range implicitly convertible to an array of
        `dchar`.
    */
    void write(S...)(S args) {
        foreach (arg; args) {
            // TODO: We should handle any non-range argument; not only chars.
            static if (is(typeof(arg) == char)) {
                if (this.data.text.length == this.data.pos) {
                    // We're at the end of the string so we append.
                    this.data.text ~= arg;
                    this.data.pos += 1;
                } else {
                    this.data.text[this.data.pos] = arg;
                    this.data.pos += 1;
                }
            } else {
                import std.algorithm : min;
                import std.array : replaceInPlace;

                const end_idx = min(this.data.pos + arg.length, this.data.text.length);
                this.data.text.replaceInPlace(this.data.pos, end_idx, arg);

                this.data.pos += arg.length;
            }
        }
    }

    /** Write to the FakeFile's text buffer at its current file position, with a
        trailing newline.
    */
    void writeln(S...)(S args) {
        if (args.length == 0) this.write('\n');
        else {
            foreach (const(char[]) arg; args) {
                this.write(arg, '\n');
            }
        }
    }

    /** Set the FakeFile's file position. */
    @trusted
    void seek(long offset) {
        this.data.pos = offset;
    }

    /** Get the FakeFile's current file position. */
    @property
    @trusted
    ulong tell() const {
        return this.data.pos;
    }

    /** No-op. For API compatibility. */
    void lock(
        LockType lockType = LockType.readWrite,
        ulong start = 0,
        ulong length = 0
    ) {}

    /** No-op. For API compatibility. */
    void unlock(ulong start = 0, ulong length = 0) {}

    /** Truncate (or grow) the file to the specified size.

        NOTE: This is not a part of the [std.stdio.File] API. An equivalent
        function for production code would be something like:

        ---
        import std.stdio : File;

        void truncate(File file, long size) {
            import std.file : FileException;

            version(Posix) {
                import core.stdc.errno : errno;
                import core.sys.posix.unistd: ftruncate;

                auto result = ftruncate(file.fileno(), size)
                    ? 0
                    : errno();
            }

            version(Windows) {
                import core.sys.windows.windows: SetEndOfFile, GetLastError;

                file.seek(size);
                auto result = SetEndOfFile(file.windowsHandle())
                    ? 0
                    : GetLastError();
            }

            if (result != 0) {
                throw new FileException(file.name, result);
            }
        }
        ---
    */
    void truncate(long size) {
        this.data.text = this.data.text[0..size];
    }

    /** Get the full text of the file.

        NOTE: This is not part of the [std.stdio.File] API but is provided for
        easy assertions.
     */
    @property
    const(char[]) readText() {
        return this.data.text;
    }

    private:

    /** Pointer to file data, making sharing the underlying file among copies of
        [FakeFile] easy.
    */
    FileData data;

    class FileData {
        char[] text;
        ulong pos = 0;

        pure
        this(const(char[]) text) {
            this.text = text.dup;

            if (this.text[$-1] != '\n') {
                this.text ~= "\n";
            }
        }
    }
}

@("FakeFile writes text to file")
unittest {
    auto text = "12\n34";
    auto file = FakeFile(text);

    file.write("5");
    assert(file.readText() == "52\n34\n", file.readText());
    file.write("67", "89", "0", '\n');
    assert(file.readText() == "567890\n", file.readText());
}

@("FakeFile readln with buffer")
unittest {
    import std.conv : to;

    auto text = "Line 1\nLine 2\nLine 3\n";

    auto file = FakeFile(text);
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

private struct FakeFileByLineRange {
    pure:

    this(string text) {
        import std.string : split;

        // We don't want to return the trailing newline in front().
        if (text[$-1] == '\n') {
            this.text = text[0..$-1].split('\n');
        } else {
            this.text = text.split('\n');
        }
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
    auto text = "Line 1\nLine 2\nLine 3\n";

    auto file = FakeFile(text);
    auto reader = file.byLine();

    assert(reader.moveFront() == "Line 1");
    assert(reader.moveFront() == "Line 2");
    assert(reader.front() == "Line 3");
}
