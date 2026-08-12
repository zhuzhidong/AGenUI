import displaySync from '@ohos.graphics.displaySync';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'FpsOverlay';
const DOMAIN = 0x0000;

/**
 * Semi-transparent overlay that measures effective main-thread frame rate
 * using displaySync.on('frame'). When the main thread is blocked, the frame
 * callback itself is delayed, so callback spacing reflects real jank.
 *
 * Drop-in usable from any page: set @Prop scenario/errorText, mount in a
 * Stack. Cleans up its displaySync + timer in aboutToDisappear.
 */
@Component
export struct FpsOverlay {
  @Prop scenario: string = '';
  @Prop errorText: string = '';
  @State fps: number = 0;
  @State avgFrameMs: number = 0;
  @State dropped: number = 0;

  private ds: displaySync.DisplaySync | null = null;
  private frameTimes: number[] = [];
  private aggregateTimer: number = -1;
  private lastFrameWall: number = -1;
  private droppedCount: number = 0;
  private readonly expectedIntervalMs: number = 1000 / 60;

  aboutToAppear() {
    this.ds = displaySync.create();
    this.ds.setExpectedFrameRateRange({ min: 0, max: 120, expected: 60 });
    this.ds.on('frame', () => {
      const now = Date.now();
      if (this.lastFrameWall >= 0) {
        const delta = now - this.lastFrameWall;
        if (delta > this.expectedIntervalMs * 1.5) {
          this.droppedCount++;
        }
      }
      this.lastFrameWall = now;
      this.frameTimes.push(now);
      if (this.frameTimes.length > 240) {
        this.frameTimes.shift();
      }
    });
    this.ds.start();
    this.aggregateTimer = setInterval((): void => { this.aggregate(); }, 500);
    hilog.info(DOMAIN, TAG, 'displaySync started');
  }

  private aggregate() {
    if (this.frameTimes.length === 0) {
      this.fps = 0;
      this.avgFrameMs = 0;
      return;
    }
    const now = Date.now();
    const oneSecondAgo = now - 1000;
    let recentStart = 0;
    for (let i = this.frameTimes.length - 1; i >= 0; i--) {
      if (this.frameTimes[i] < oneSecondAgo) {
        recentStart = i + 1;
        break;
      }
    }
    const recent = this.frameTimes.slice(recentStart);
    const count = recent.length;
    if (count === 0) {
      this.fps = 0;
      return;
    }
    const span = count > 1 ? (recent[count - 1] - recent[0]) : 0;
    let fps = span > 0 ? Math.round(((count - 1) / span) * 1000) : count;
    if (fps > 120) { fps = 120; }
    this.fps = fps;
    let sumDelta = 0;
    let deltaCount = 0;
    for (let i = 1; i < recent.length; i++) {
      sumDelta += recent[i] - recent[i - 1];
      deltaCount++;
    }
    this.avgFrameMs = deltaCount > 0 ? Math.round((sumDelta / deltaCount) * 10) / 10 : 0;
    this.dropped = this.droppedCount;
  }

  aboutToDisappear() {
    if (this.aggregateTimer !== -1) {
      clearInterval(this.aggregateTimer);
      this.aggregateTimer = -1;
    }
    if (this.ds) {
      this.ds.stop();
      this.ds.off('frame');
      this.ds = null;
      hilog.info(DOMAIN, TAG, 'displaySync stopped');
    }
  }

  build() {
    Column() {
      Text(this.scenario || 'IDLE')
        .fontSize(11).fontColor('#FFFFFF').fontFamily('monospace').margin({ bottom: 2 })
      Text(`FPS:${this.fps}`)
        .fontSize(13)
        .fontColor(this.fps >= 55 ? '#4CFF4C' : (this.fps >= 30 ? '#FFCC33' : '#FF6666'))
        .fontFamily('monospace').margin({ bottom: 2 })
      Text(`frame:${this.avgFrameMs}ms`)
        .fontSize(11).fontColor('#FFFFFF').fontFamily('monospace').margin({ bottom: 2 })
      Text(`dropped:${this.dropped}`)
        .fontSize(11).fontColor(this.dropped > 0 ? '#FF6666' : '#FFFFFF').fontFamily('monospace').margin({ bottom: 2 })
      if (this.errorText) {
        Text(this.errorText).fontSize(10).fontColor('#FF6666').fontFamily('monospace').maxLines(2)
      }
    }
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(12)
    .backgroundColor('rgba(0, 0, 0, 0.7)')
    .margin({ left: 16, top: 60 })
    .alignItems(HorizontalAlign.Start)
  }
}
