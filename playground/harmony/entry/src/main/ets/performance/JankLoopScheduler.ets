import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'JankScheduler';
const DOMAIN = 0x0000;

/**
 * Manages setInterval/setTimeout handles for jank scenarios.
 *
 * Pure round-cap logic is static and unit-tested; handle accounting is
 * thin so all running loops can be stopped from one place.
 */
export class JankLoopScheduler {
  /** Hard ceiling on scenario iterations (backstop for forgetting to press Stop). */
  static readonly MAX_ROUNDS: number = 2000;

  /**
   * True when `round` has reached/exceeded `maxRounds`. A `maxRounds` of 0
   * means "no cap" (returns false). Used by each scenario's tick to decide
   * whether to keep looping.
   */
  static isRoundCapped(round: number, maxRounds: number): boolean {
    return maxRounds > 0 && round >= maxRounds;
  }

  private handles: number[] = [];

  /** Register a timer handle so stopAll() can clear it. Returns the handle. */
  register(handle: number): number {
    this.handles.push(handle);
    return handle;
  }

  /** True if at least one registered handle is active. */
  hasActive(): boolean {
    return this.handles.length > 0;
  }

  /** Clear all registered handles and return how many were cleared. Idempotent. */
  stopAll(): number {
    const n = this.handles.length;
    for (let i = 0; i < this.handles.length; i++) {
      const h = this.handles[i];
      clearInterval(h);
      clearTimeout(h);
    }
    this.handles = [];
    if (n > 0) {
      hilog.info(DOMAIN, TAG, 'stopped %{public}d handle(s)', n);
    }
    return n;
  }
}
