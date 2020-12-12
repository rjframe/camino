# Camino

Flexible command-line habit tracking.


## Table of Contents

* [Introduction](#introduction)
    * [License](#license)
* [Getting Started](#getting-started)
    * [Build](#build)
    * [Usage](#usage)
    * [Known Issues](#known-issues)
* [Contributing](#contributing)
    * [Acknowledgements](#acknowledgments)
* [Contact](#contact)
* [Related Projects](#related-projects)


## Introduction

Camino will be a flexible command-line tool to track various kinds of habits,
goals, and recurring tasks.

Camino is still in the very early stages and is not yet usable. It should run on
Linux, BSD, Windows, macOS (as well as any OS that the GCC or LLVM-backed
compilers can build for if you build it), but is only tested on Linux.

We provide a simple and consistent interface to manage:

* daily, weekly, monthly tasks (every week, every Tuesday, etc.)
* every x days (every three days, etc.)
* yes/no habits ("Eat lunch")
* unit-based habits ("Read 500 pages")
* multiple instances per day/week/month (twice a day, etc.)
* low-number goals ("fewer than 2500 calories")
* negative/undesired habits ("Don't sleep in")

The above habit types can typically be combined -- "two exercises three times a
day." If something makes sense for your needs, we need to support it.

See [Usage](#usage) below or [Design.md](docs-src/Design.md) for the
planned user interface.


### Why?

I use pencil and paper for scheduling. The major problem with paper for habit
tracking is the difficulty in generating reports; if I want to see how well I've
done overall (or for a specific habit) in the course of a year, or compare month
to month, I have to do the work of generating that report, every time.

I looked for other solutions but couldn't find anything flexible enough to
manage the variety of habit types I want to track, so sat down one day to work
out a design.


### License

Unless otherwise noted (typically specifications or other documentation),
everything in this project is licensed under the MIT license - see
[LICENSE.md](LICENSE.md) for details.


## Getting Started

### Build

To build camino, you'll need the D compiler and dub (a build tool). On Linux you
can likely use your package manager; install dub and one of the dmd (reference
compiler), gdc (GCC-backend) or ldc (LLVM-backend) compilers. Otherwise you can
obtain them from [the D website](https://dlang.org).

You can run unit tests by running `dub test` and build the application via
`dub build -b release`.


### Usage

Camino uses a tab-delimited (with four spaces converted to tab) habits file to
list the habits you wish to track.

An example habits file:

```
# Anything after a '#' is a comment, but it must begin the line.

#Schedule   Description         Goal

daily       Eat lunch
Tue         Clean house         2 rooms
daily       Caloric intake      <2501 calories
daily       Get out of bed      <6:31

# Do this every other day.
2 days      Clean litterbox

# Do this twice a day.
2 daily     Practice guitar

# You can track your partial progress throughout the week.
weekly      Read a book         500 pages

# Three exercises, three times a day.
3 daily     Spanish             3 exercises

# The '-' makes it an undesireable habit.
-daily      Sleep in
```

Habit tracking will be in a JSON list file, so you can easily edit it if
necessary and have options for tooling, integrations, and reporting outside of
camino.

See [Design.md](docs-src/Design.md) for the probable command-line interface.
There is also a draft specification for
[history tracking](https://rjframe.github.io/camino/history_spec.html).


### Known Issues

It isn't ready yet!


## Contributing

Pull requests are welcome. For major features or breaking changes, please open
an issue first so we can discuss what you would like to do.

And don't forget the tests!

You can find generated documentation
[here](https://rjframe.github.io/camino/index.html) (it is missing private
members, and links to standard library functions are currently dead).  You can
generate the documentation locally with
[adrdox](https://github.com/adamdruppe/adrdox). Documentation syntax is
available with
[adrdox's documentation](http://dpldocs.info/experimental-docs/adrdox.syntax.html).

For now, the only hard rule in code style is 80 characters per line, with the
possible exception of long strings in unit tests. I personally think that
community rules and guidelines should be made by the community, which by
definition requires the presence of more than one person. If you'd like guidance
on anything feel free to ask in a discussion or ticket, or submit a draft PR.


### Acknowledgments

Your name here?


## Contact

- Email: code@ryanjframe.com
- Website: [www.ryanjframe.com](https://www.ryanjframe.com)
- diaspora*: rjframe@diasp.org


## Related Projects

These are all usable today, so be sure to check them out. If you have or use
something not on the list, an issue or PR to add them would be great!

All of these are command-line applications; some also have web/mobile/other
interfaces.

Time/schedule/project management:

* [Taskwarrior](https://taskwarrior.org)
* [Todo.txt](http://todotxt.org)

Habits management:

* [dijo](https://github.com/NerdyPepper/dijo)
* [Habitctl](https://github.com/blinry/habitctl)
* [Habito](http://codito.github.io/habito/)
