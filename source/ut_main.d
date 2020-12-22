import unit_threaded.runner : runTestsMain;

mixin runTestsMain!(
    "camino.exception",
    "camino.goal",
    "camino.habit",
    "camino.history",
    "camino.optparse",
    "camino.schedule",
    "camino.test_util"
);
