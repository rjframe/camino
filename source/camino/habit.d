module camino.habit;

import camino.schedule;

import std.exception : enforce;

import sumtype;

/** A `Habit` describes a habit that we need to track. */
struct Habit {
    Schedule schedule;
    string description;
    string goal; // TODO: type

    this(string schedule, string description, string goal = "") {
        // The shortest valid length is for shorthand days (like "Tue").
        enforce(schedule.length >= 3, "Invalid schedule: " ~ schedule);
        // TODO: enforce on goal. Also for description > 0?

        this.schedule = parse(schedule);
        this.description = description;
        //this.goal = parse(goal);
    }

    // Icky but convenient.
    this(string[] fields)
        in(fields.length == 2 || fields.length == 3)
    {
        if (fields.length == 2) {
            this(fields[0], fields[1]);
        } else {
            this(fields[0], fields[1], fields[2]);
        }
    }

}
