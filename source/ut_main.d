import unit_threaded.runner : runTestsMain;

mixin runTestsMain!(
    "camino.habit",
    "camino.schedule"
);
