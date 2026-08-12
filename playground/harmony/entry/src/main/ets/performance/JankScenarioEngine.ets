import { SurfaceManager } from '@agenui/agenui';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { JankLoopScheduler } from './JankLoopScheduler';
import {
  JANK_BASELINE_SURFACE_ID,
  JANK_BASELINE_JSON,
  JANK_BASELINE_CHUNK
} from './jankStories';

const TAG = 'JankEngine';
const DOMAIN = 0x0000;
const CATALOG = 'https://a2ui.org/specification/v0_9/basic_catalog.json';

export type JankRunState = (name: string, running: boolean, error: string | null) => void;
export type JankAnimTick = (pos: number) => void;

/**
 * Runs temporal-jank scenarios against a visible baseline surface held by
 * JankTestPage. Each scenario schedules work via setInterval and is
 * registered with a JankLoopScheduler so stop() can abort everything.
 */
export class JankScenarioEngine {
  static readonly SCENARIO_NAMES: string[] = [
    'MainThreadBlock', 'StateChurn', 'TinyChunkStream',
    'SetTimeoutAnimation', 'SurfaceThrash', 'MemoryChurn'
  ];

  static isKnown(name: string): boolean {
    return JankScenarioEngine.SCENARIO_NAMES.includes(name);
  }

  private context: common.UIAbilityContext;
  private sm: SurfaceManager;
  private scheduler: JankLoopScheduler = new JankLoopScheduler();
  private onState: JankRunState;
  private onAnimTick: JankAnimTick;
  private animPos: number = 0;

  constructor(
    context: common.UIAbilityContext,
    sm: SurfaceManager,
    onState: JankRunState,
    onAnimTick: JankAnimTick
  ) {
    this.context = context;
    this.sm = sm;
    this.onState = onState;
    this.onAnimTick = onAnimTick;
  }

  /** Create + populate the baseline surface so there is something visible to jank. */
  loadBaseline(): void {
    this.sm.beginTextStream();
    this.sm.receiveTextChunk(
      `{"version":"v0.9","createSurface":{"surfaceId":"${JANK_BASELINE_SURFACE_ID}","catalogId":"${CATALOG}"}}`
    );
    this.sm.receiveTextChunk(JANK_BASELINE_JSON);
    this.sm.endTextStream();
    hilog.info(DOMAIN, TAG, 'baseline surface loaded');
  }

  /** Run a scenario by name. Unknown names are a no-op (logged). */
  run(name: string): void {
    if (!JankScenarioEngine.isKnown(name)) {
      hilog.warn(DOMAIN, TAG, 'unknown scenario: %{public}s', name);
      return;
    }
    this.stop();
    this.animPos = 0;
    this.onState(name, true, null);
    try {
      switch (name) {
        case 'MainThreadBlock': this.mainThreadBlock(); break;
        case 'StateChurn': this.stateChurn(); break;
        case 'TinyChunkStream': this.tinyChunkStream(); break;
        case 'SetTimeoutAnimation': this.setTimeoutAnimation(); break;
        case 'SurfaceThrash': this.surfaceThrash(); break;
        case 'MemoryChurn': this.memoryChurn(); break;
      }
    } catch (e) {
      this.onState(name, false, (e as Error).message);
      hilog.error(DOMAIN, TAG, 'scenario crashed: %{public}s', String(e));
    }
  }

  /** Stop all running loops. Idempotent. */
  stop(): void {
    this.scheduler.stopAll();
    this.onState('', false, null);
  }

  private mainThreadBlock(): void {
    let round = 0;
    const tick = (): void => {
      if (JankLoopScheduler.isRoundCapped(round, JankLoopScheduler.MAX_ROUNDS)) { this.stop(); return; }
      const end = Date.now() + 50;
      while (Date.now() < end) { /* busy-wait 50ms on main thread */ }
      round++;
    };
    const h = setInterval(tick, 100);
    this.scheduler.register(h);
  }

  private stateChurn(): void {
    let round = 0;
    const tick = (): void => {
      if (JankLoopScheduler.isRoundCapped(round, JankLoopScheduler.MAX_ROUNDS)) { this.stop(); return; }
      this.sm.syncState(JANK_BASELINE_SURFACE_ID, 'block', JSON.stringify({ t: round }));
      round++;
    };
    const h = setInterval(tick, 5);
    this.scheduler.register(h);
  }

  private tinyChunkStream(): void {
    let round = 0;
    const tick = (): void => {
      if (JankLoopScheduler.isRoundCapped(round, JankLoopScheduler.MAX_ROUNDS)) { this.stop(); return; }
      this.sm.beginTextStream();
      this.sm.receiveTextChunk(JANK_BASELINE_CHUNK);
      this.sm.endTextStream();
      round++;
    };
    const h = setInterval(tick, 30);
    this.scheduler.register(h);
  }

  private setTimeoutAnimation(): void {
    let round = 0;
    const tick = (): void => {
      if (JankLoopScheduler.isRoundCapped(round, JankLoopScheduler.MAX_ROUNDS)) { this.stop(); return; }
      this.animPos = (this.animPos + 4) % 200;
      this.onAnimTick(this.animPos);
      round++;
    };
    const h = setInterval(tick, 16);
    this.scheduler.register(h);
  }

  private surfaceThrash(): void {
    let round = 0;
    const tick = (): void => {
      if (JankLoopScheduler.isRoundCapped(round, JankLoopScheduler.MAX_ROUNDS)) { this.stop(); return; }
      this.sm.beginTextStream();
      this.sm.receiveTextChunk(
        `{"version":"v0.9","deleteSurface":{"surfaceId":"${JANK_BASELINE_SURFACE_ID}"}}`
      );
      this.sm.receiveTextChunk(
        `{"version":"v0.9","createSurface":{"surfaceId":"${JANK_BASELINE_SURFACE_ID}","catalogId":"${CATALOG}"}}`
      );
      this.sm.receiveTextChunk(JANK_BASELINE_JSON);
      this.sm.endTextStream();
      round++;
    };
    const h = setInterval(tick, 50);
    this.scheduler.register(h);
  }

  private memoryChurn(): void {
    let round = 0;
    const tick = (): void => {
      if (JankLoopScheduler.isRoundCapped(round, JankLoopScheduler.MAX_ROUNDS)) { this.stop(); return; }
      // Allocate ~5MB then drop the reference, forcing periodic GC pauses.
      const buf: number[] = new Array(655360);
      buf[0] = round;
      round++;
    };
    const h = setInterval(tick, 16);
    this.scheduler.register(h);
  }
}
