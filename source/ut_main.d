import unit_threaded.runner : runTestsMain;

mixin runTestsMain!(
    "camino.goal",
    "camino.habit",
    "camino.history",
    "camino.schedule",
    "camino.test_util"
);
