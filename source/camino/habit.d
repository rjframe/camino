module camino.habit;

import camino.goal;
import camino.schedule;

import std.exception : enforce;

import sumtype;


@safe:

/** A [Habit] describes a habit that we need to track. */
struct Habit {
    /** The recurrence schedule for the habit. */
    Schedule schedule;
    /** The name by which the habit is identified. */
    string description;
    /** The goal to track. */
    Goal goal;

    /** Create a new [Habit] object.

        Params:
            schedule =    The repetition [Schedule|schedule] for the habit.
            description = The name of the habit.
            goal =        A [Goal] for the habit.
    */
    this(Schedule schedule, string description, Goal goal) {
        this.schedule = schedule;
        this.description = description;
        this.goal = goal;
    }

    /** Create a new [Habit] from the provided strings.

        Params:
            schedule =    A string denoting the habit's repetition schedule
                          that can be parsed as a [Schedule] object.
            description = The name of the habit.
            goal =        An optional string that can be parsed to a [Goal] object.
    */
    this(string schedule, string description, string goal = "") {
        // The shortest valid length is for shorthand days (like "M").
        enforce(schedule.length >= 1, "Invalid schedule: " ~ schedule);
        enforce(description.length > 0,
            "No habit description provided in: " ~ schedule
        );

        this.schedule = parseSchedule(schedule);
        this.description = description;
        this.goal = parseGoal(goal);
    }

    /** Determine whether two [Habit]s are equal.

        Equality is determined by the content of their descriptions.
    */
    bool opEquals()(auto ref const typeof(this) other) const {
        return this.description == other.description;
    }

    /** Return a hash value of this [Habit]. */
    pure nothrow
    size_t toHash() const
    {
        // toHash() must be consistent with opEquals().
        return this.description.hashOf();
    }
}
