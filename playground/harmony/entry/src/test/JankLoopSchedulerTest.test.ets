import { describe, it, expect } from '@ohos/hypium';
import { JankLoopScheduler } from '../main/ets/performance/JankLoopScheduler';

export default function jankLoopSchedulerTest() {
  describe('JankLoopScheduler', () => {
    it('isRoundCapped_false_when_maxZero', 0, () => {
      expect(JankLoopScheduler.isRoundCapped(999, 0)).assertFalse();
    });
    it('isRoundCapped_false_when_below_max', 0, () => {
      expect(JankLoopScheduler.isRoundCapped(5, 10)).assertFalse();
    });
    it('isRoundCapped_true_at_max', 0, () => {
      expect(JankLoopScheduler.isRoundCapped(10, 10)).assertTrue();
    });
    it('isRoundCapped_true_above_max', 0, () => {
      expect(JankLoopScheduler.isRoundCapped(11, 10)).assertTrue();
    });
    it('register_and_hasActive', 0, () => {
      const s = new JankLoopScheduler();
      expect(s.hasActive()).assertFalse();
      s.register(42);
      expect(s.hasActive()).assertTrue();
    });
    it('stopAll_clears_and_returns_count', 0, () => {
      const s = new JankLoopScheduler();
      s.register(1);
      s.register(2);
      s.register(3);
      const n = s.stopAll();
      expect(n).assertEqual(3);
      expect(s.hasActive()).assertFalse();
    });
    it('stopAll_idempotent', 0, () => {
      const s = new JankLoopScheduler();
      s.register(1);
      s.stopAll();
      expect(s.stopAll()).assertEqual(0);
    });
  });
}
