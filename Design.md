# Habit Tracking Design Document

Types of habits:
- daily, weekly (fixed-date), monthly
- every x days
- yes/no or unit-based
- multiple times per day
- goal or just tracking completion
- negative (do not) habits
- low number goals
- time goals

Text files for creation/management

Sample habits file:

```
#Schedule   Description         Goal
daily       Eat lunch
2 days      Litterbox
Tue         Clean house         2 rooms
2 daily     Practice guitar
# DECISION: Allow a schedule like "2 every 3 days"?
weekly      Read                500 pages
3 daily     Spanish             3 exercises
daily       Caloric intake      <2501 calories
-daily      Sleep in
daily       Get out of bed      <6:31
```

Sample tracking file:

JSON/YAML? They'd evolve well as habits change over time and tooling exists to
work with them.

I will need to handle problematic edits of partially-completed goals (ie,
positive goal becomes negative).

I probably need to explicitly record all goals the first time we run for a day;
this way we can differentiate failure versus non-existent goals in reports.

```
{
    "2020-01-01": {
        // shorthand for "Eat lunch": { "complete": true }
        // if "goal" not specified, implicitly `true`.
        "Eat lunch": true,
        "Practice guitar": {
            "instances": [true, true],
        },
        "Caloric intake": {
            "goal": "<2501",
            "instances": [1200, 1200, 100, 1],
        },
        "Read": {
            "goal": 500,
            "instances": [100, 350, 50, 1],
        },
        "Spanish": {
            "goal": 3,
            "instances": [3, 3, 2]
        },
        "Get out of bed": {
            // If we were twice daily, etc. We'd have instances that contained
            // the actuals for each instance.
            "goal: "<6:31",
            "actual": "5:00"
        },
        "Sleep in": {
            "goal": false,
            "actual": false
        },
        "Litterbox": true
    },
    "2020-01-02": {
        "Eat lunch": "skip",
        "Practice guitar": {
            "instances": [true, "skip"],
        },
        # Scheduled every other day, so implicitly a skip since was complete
        # yesterday.
        "Litterbox": "skip"

    }

}
```

## Possible Usage Examples

Sample UI:
- need to be able to mark habits in the past too.
- TODO:
    - editing the file can come later
    - undo?
    - a review/cycle command to prompt on the status of each habit for the day


On a Wednesday:
```
$ camino list
1. Eat lunch (daily)
3. Practice guitar (2 times daily)
4. Read (500 pages weekly)
5. Spanish (3 exercises, 3 times daily)
6. Caloric intake (less than 2500 calories)
8. Get out of bed (before 6:31)

$ camino list --all # would include
2. Clean house (2 rooms, Tuesdays)
7. (do not) Sleep in (daily)
```

On Tuesdays, the Tuesday task would also be shown by default.

```
$ camino do 1
Eat lunch is completed for today.
# Also allow by name/partial name if its the only match?
$ camino do Eat lunch
$ camino do Eat
$ camino do E

$ camino do 2
Practice guitar is partially done today. You still need to do this 1 more time.
$ camino do 2
Practice guitar is completed for today.

# First two are equivalent - three exercises each instance.
$ camino do 6
Spanish is partially done today. You still need to do this 2 more times.
$ camino do 6 3
Spanish is partially done today. You still need to do this 1 more time.
$ camino do 6 2
Spanish is partially done today. Spanish is near today's goal (2/3 exercises = 33%).

$ camino do 7 1200
Caloric intake is partially done today (1200/2500 = 48%).
$ camino do 7 1200
Caloric intake is near today's limit (2400/2500 = 96%).
$ camino do 7
Caloric intake is at today's limit.
$ camino do 7 1
You have exceeded your limit for Caloric intake by 1.

$ camino do 5 100
Read is partially done for this week (100/500 = 20%).
$ camino do 5 350
Read is near this week's goal (450/500 = 90%).
$ camino do 5
Read is completed for this week.
$ camino do 5 1
You have exceeded your weekly goal for Read by 1.

$ camino do 8
Get out of bed is completed for today.
$ camino do 8 5:30
Get out of bed is completed early for today.
$ camino do 8 7:00
Get out of bed is completed late today.

# Explicitly fail a habit instance. Only one instance of a repeating goal.
# Does not actually change anything in the tracker though unless it was
# previously marked as completed -- all goals are recorded as incomplete when
# the day is created.
$ camino not 2
Clean house is not completed today.
$ camino not 7
Sleep in was successfully avoided today.

# Or skip (if not able to do it, etc.) Only one instance of a repeating goal.
# This does need to be recorded as a skip in the tracking file.
$ camino skip 2
Clean house is skipped today.

# Mark previous days; accept date or "yesterday"
$ camino do 2 --date yesterday
$ camino do 2 --date 2020-01-30
```


# Reports

TODO

Most likely make it easy for custom reports and customizing default reports.
Wait until we have significant usage/experience to start adding official
reports.


# Configuration options:

- command-line or environment variable: configuration location
- habits file location (also via command-line. env var?)
- date/time format
- use/don't use units in messages?
- max history?
