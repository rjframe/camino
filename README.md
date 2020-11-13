# Camino Habit Tracker

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
day."

See [Usage](#usage) below or [Design.md](Design.md) for the
planned interface.


### Why?

I use pencil and paper for scheduling. I've begun experimenting with electronic
scheduling systems but haven't found anything flexible enough to manage my habit
tracking. I think that it can be done with the design I've come up with, so am
giving it a try.


### License

This project is licensed under the MIT license - see [LICENSE.md](LICENSE.md)
for details.


## Getting Started

### Build

To build camino, you'll need the D compiler and dub. On Linux you can likely use
your package manager; install dub and one of dmd (reference compiler), gdc
(GCC-backed) or ldc (LLVM-backed) compilers. Otherwise you can obtain them from
[the D website](https://dlang.org/download.html).

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

# Do this every other day.
2 days      Clean litterbox

Tue         Clean house         2 rooms

# Do this twice a day.
2 daily     Practice guitar

# You can track your partial progress throughout the week.
weekly      Read a book         500 pages

# Three exercises, three times a day.
3 daily     Spanish             3 exercises

daily       Caloric intake      <2501 calories

# The '-' makes it an undesireable habit. It only matters in reports.
-daily      Sleep in

daily       Get out of bed      <6:31
```

Habit tracking will likely be in a JSON file, so you can easily edit it if
necessary and have options for tooling and reporting outside of camino (easy
integration with inotify, etc.).

See [Design.md](Design.md) for the probable command-line interface.


### Known Issues


## Contributing

Pull requests are welcome. For major features or breaking changes, please open
an issue first so we can discuss what you would like to do.

And don't forget the tests!


### Acknowledgments

Your name here?


## Contact

- Email: <code@ryanjframe.com>


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
