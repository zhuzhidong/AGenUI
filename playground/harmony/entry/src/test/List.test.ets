import localUnitTest from './LocalUnit.test';
import styleHelperTest from './StyleHelperTest.test';
import jankLoopSchedulerTest from './JankLoopSchedulerTest.test';

export default function testsuite() {
  localUnitTest();
  styleHelperTest();
  jankLoopSchedulerTest();
}
