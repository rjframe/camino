import unit_threaded.runner : runTestsMain;

mixin runTestsMain!(
    "camino.goal",
    "camino.habit",
    "camino.schedule"
);
