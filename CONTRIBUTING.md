# Contributing to Camino

This is mostly a set of guidelines, not fixed rules. They are also changeable --
if you have questions or think something can be improved please submit an
issue/PR or start a discussion.


## Table of Contents

* [How Can I Contribute?](#how-can-i-contribute)
* [What Do I Need for Development?](#what-do-i-need-for-development)
    * [Using Dub](#using-dub)
    * [Optional Tools](#optional-tools)
* [Style Guidelines](#style-guidelines)
    * [Commit and PR Style](#commit-and-pr-style)
    * [Code Style](#code-style)
    * [Documentation Style](#documentation-style)


## How Can I Contribute?

There are many ways to help!

Testing: Test that camino works like you'd expect; even try to break it. But
back up your habit and tracking file before you try to break something, because
you probably will.

Bug and enhancement reports: Have an idea to make things better? [File an
issue](https://github.com/rjframe/camino/issues)!

Write documentation: this ranges from tutorials and reference material to
answering questions other people have.

Write code: Even if you're not comfortable with your programming skill, you can
use camino to learn and practice.


## What Do I Need for Development?

To build camino, you'll need the D compiler and dub. You can obtain them from
[the D website](https://dlang.org) or via your system's package manager. In
addition to dmd (the reference compiler), you can also use gdc or ldc (using gcc
or LLVM, respectively). I personally use dmd for development, and official
releases will probably use ldc.

If you're not familiar with the D language, you may want to work through the
online book [Programming in D](http://ddili.org/ders/d.en/index.html) by Ali
Çehreli.

If you're coming from another programming language, you can find tips on the [D
wiki](https://wiki.dlang.org/Coming_From) coming from various popular languages.


### Using Dub

The first time you use dub to build or run the application, it will
automatically download any needed dependencies.

The most common commands will be:

* `dub test`: Build and run the unit tests.
* `dub run`: Build and run the applicaton.
* `dub build`: Build but do not run the application.

When you run the tests, coverage reports will be automatically generated in the
project root with an `lst` extension. On Un*x you can easily get a test coverage
overview for all modules by running either `tail -n 1 *.lst` or `grep covered
*.lst`, depending on your preferred report format.


### Optional Tools

#### Generating Documentation

This process will be automated eventually; in the meantime, you are not required
or expected to generate the documentation yourself for PRs, but are welcome to
do so.

To generate the documentation you'll need
[adrdox](https://github.com/adamdruppe/adrdox). I have both camino and adrdox in
my "src" folder, so the command I use to run it (from the adrdox directory) is
`./doc2 -i ../camino --document-undocumented -o ../camino/docs`.


#### Static analysis

This will eventually be done by the CI. Until then, passing static analysis is
not required.

If you want to run some basic checks against your code, use
[dscanner](https://github.com/dlang-community/D-Scanner). It may have been
bundled with the compiler, or you can use dub, which will install dscanner on
your first use of it:

```
# Use one of:
dscanner -S
dub lint --style-check
```


## Style Guidelines

### Commit and PR Style

The first line of a commit message should summarize the purpose of the commit.
It should be a full sentence and end with a period to signify the end of the
thought. The subject should be no more than 72 characters.

Write the subject in imperative style (like you're telling someone what to do);
use "Add xyz" instead of "Added xyz", "Fix" instead of "Fixed", etc.

If relevant, later paragraphs should provide context and explain anything that
may not be apparent; e.g., if you made a design decision that may not be
obvious, why did you choose that over an alternative?

Answer the question "why?"; we can see "what" from the code itself. For example,
use "Fix typo in schedule documentation." rather than "Change schedull to
schedule.".

Text should be wrapped at 72 characters.

If a commit references, is related to, or fixes an issue, list it at the end.

A commit message might look something like:

```
Add a widget to the box.

The box was looking empty with nothing inside it.

We could also have used a gadget, but widgets are shiny which should
make looking inside the box a more pleasant experience going forward.

This does mean we will no longer be able to fit some things inside the
box:

* contrivances will be too big
* devices might break nearby widgets
* gimmicks would no longer be relevant

Resolves: #45
```

It's best to keep commits small when possible, doing only one thing.

PRs that are only cosmetic (style) fixes will not be accepted since this messes
up `git blame`. Style-only commits in the code you're working with while doing
something else are fine though.


### Code Style

In general, follow the [D style guide](https://dlang.org/dstyle.html). In
particular:

* Use four spaces for indentation.
* Follow the [D standard naming
  conventions](https://dlang.org/dstyle.html#naming_conventions); notably:
    * Module names are all `lowercase`.
    * Classes, interfaces, structs, and enums are `PascalCased`.
    * Functions, variables, constants, enum members, and UDAs are `camelCased`.
    * Names that conflict with keywords should be postfixed with an underscore.
    * All letters in an acronym should use the same case (the same as the first
      character according to the other rules).
* Prefer local imports over global imports.
* Explicitly state the return types of functions whenever possible.
* Prefer the expression-form for function contracts.


#### Additions or exceptions to the D style

* Use an 80 character line length limit.
* Write code with understandability and future maintainability in mind.
* Write tests whenever practical; exercise error conditions and edge cases as
  well as the happy path.
* Document all public declarations. Also document non-trivial private
  declarations.
* Global imports are fine if used throughout a module (common examples are
  `std.json.JSONValue` and `std.exception.enforce`). Imports should be sorted
  alphabetically unless another order makes sense (e.g.,
  `import std.algorithm : startsWith, endsWith;`).
* Public fields in a struct or class should come before methods; private fields
  should be placed at the end.
* Make functions `@safe` whenever possible.


##### Function Declarations and Braces

Place opening braces on the same line, unless the function definition/statement
itself takes multiple lines, in which case it should be on a new line on the
same indentation level as the first declaration line.

If a function declaration or call requires multiple lines, place each
argument/parameter on a new line, indented once, and the closing parenthesis on
a new line.  Sometimes exceptions to this rule will look better or be easier to
read (notably `assert()` and `enforce()`) -- this is not a hard rule. Use
whatever is easiest to read and scan.

Contracts on functions should be indented a level.

Examples:

```d
void myFunction() {
    // Code goes here.
}

void otherFunction(
    int parameterList,
    int thatWouldExtendBeyond,
    int eightyCharacters
) {
    // Code goes here.
    assert(someVariable == someValue,
        "someVariable was not someValue");
}

/** Add two numbers.

    It is an error if overflow would occur.
*/
long add(long a, long b)
    in(a >= 0 ? b <= (long.max - a) : b >= (long.min - a))
{
    return a + b;
}
```


### Documentation Style

Documentation is formatted as described in the [adrdox
syntax](dpldocs.info/experimental-docs/adrdox.syntax.html) documentation.

Document any exceptions that can be thrown. Provide examples when appropriate,
either inline with the documentation comments or as documented unittests.

Example:

```d
/** Truncate a file to the specified size in bytes.

    On Windows the file must be opened for writing.

    The current file position after a `truncate()` call is undefined; if you
    need to keep your position within the file, call [File.tell] prior to
    truncating, then seek after truncation.

    Note that truncating a text file may mean there is no longer a newline at
    the end of the file.

    Throws:

    [std.stdio.FileException] on failure to truncate the file.

    On Windows, `truncate()` can also throw:

    * [Exception] if the file is unopened.
    * [std.exception.ErrnoException] if the OS fails to seek to
      the position at the specified `size`.
*/
void truncate(File file, long size) {
    // ...
}
```
