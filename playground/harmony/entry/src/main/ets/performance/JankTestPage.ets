import { AGenUIContainer, SurfaceManager, ISurfaceManagerListener, Surface } from '@agenui/agenui';
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FpsOverlay } from '../components/FpsOverlay';
import { JankScenarioEngine } from './JankScenarioEngine';

const TAG = 'JankTestPage';
const DOMAIN = 0x0000;
const COLORS = ['#6200EE', '#3700B3', '#4D95E5', '#BB86FC', '#03DAC5', '#FF6666'];

@Entry
@Component
struct JankTestPage {
  @State surfaceId: string = '';
  @State surfaceVersion: number = 0;
  @State activeScenario: string = '';
  @State isRunning: boolean = false;
  @State errorText: string = '';
  @State animPos: number = 0;
  @State smoothRunning: boolean = false;

  private sm: SurfaceManager | null = null;
  private engine: JankScenarioEngine | null = null;
  private smoothDir: number = 1;

  aboutToAppear() {
    const context = getContext(this) as common.UIAbilityContext;
    this.sm = new SurfaceManager(context);
    this.sm.addListener({
      onCreateSurface: (s: Surface) => {
        this.surfaceVersion++;
        this.surfaceId = s.surfaceId;
        hilog.info(DOMAIN, TAG, 'surface created: %{public}s', s.surfaceId);
      },
      onDeleteSurface: (s: Surface) => {
        if (this.surfaceId === s.surfaceId) { this.surfaceId = ''; }
      }
    } as ISurfaceManagerListener);

    this.engine = new JankScenarioEngine(
      context,
      this.sm,
      (name: string, running: boolean, err: string | null) => {
        this.activeScenario = name;
        this.isRunning = running;
        this.errorText = err ?? '';
      },
      (pos: number) => { this.animPos = pos; }
    );
    this.engine.loadBaseline();
  }

  aboutToDisappear() {
    this.stopEverything();
    if (this.sm) { this.sm.destroy(); this.sm = null; }
    this.engine = null;
  }

  private stopEverything() {
    this.engine?.stop();
    this.smoothRunning = false;
  }

  private runScenario(name: string) {
    this.smoothRunning = false;
    this.animPos = 0;
    this.engine?.run(name);
  }

  private startSmoothAnim() {
    this.stopEverything();
    this.smoothRunning = true;
    this.animPos = 0;
    this.smoothDir = 1;
    this.kickSmoothAnim();
  }

  private kickSmoothAnim(): void {
    if (!this.smoothRunning) {
      return;
    }
    this.getUIContext().animateTo(
      {
        duration: 1000,
        curve: Curve.EaseInOut,
        onFinish: () => {
          if (this.smoothRunning) {
            this.smoothDir = -this.smoothDir;
            this.kickSmoothAnim();
          }
        }
      },
      () => {
        this.animPos = this.smoothDir > 0 ? 200 : 0;
      }
    );
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // Top bar
        Row() {
          Text('‹')
            .fontSize(22).fontColor(Color.White).margin({ left: 16 })
            .onClick(() => router.back())
          Text('Jank Lab')
            .fontSize(18).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .margin({ left: 8 }).layoutWeight(1)
        }
        .width('100%').height(56).backgroundColor('#6200EE').alignItems(VerticalAlign.Center)

        // Visible baseline surface (the "canvas")
        Scroll() {
          Column() {
            // ArkUI moving square (for SetTimeoutAnimation / smooth compare)
            Row() {
              Column()
                .width(40).height(40)
                .backgroundColor('#BB86FC')
                .margin({ left: this.animPos })
            }
            .width('100%').height(60)

            ForEach(
              this.surfaceId ? [this.surfaceId] : [],
              (sid: string) => {
                AGenUIContainer({ surfaceId: sid, instanceId: this.sm?.getInstanceId() ?? 0 })
                  .width('100%')
              },
              (_sid: string) => `jank_${this.surfaceVersion}`
            )
          }
          .width('100%')
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
        .backgroundColor(Color.White)

        // Scenario buttons
        Scroll() {
          Row() {
            ForEach(JankScenarioEngine.SCENARIO_NAMES, (name: string, i: number) => {
              Button(name)
                .fontSize(11)
                .backgroundColor(this.activeScenario === name && this.isRunning ? '#03DAC5' : COLORS[i % COLORS.length])
                .fontColor(Color.White)
                .margin({ left: 6, right: 6 })
                .onClick(() => this.runScenario(name))
            })
            Button('Stop')
              .fontSize(11).backgroundColor('#FF6666').fontColor(Color.White).margin({ left: 6, right: 6 })
              .onClick(() => this.stopEverything())
            Button('animateTo')
              .fontSize(11).backgroundColor('#4D95E5').fontColor(Color.White).margin({ left: 6, right: 6 })
              .onClick(() => this.startSmoothAnim())
          }
          .padding(8)
        }
        .width('100%').scrollBar(BarState.Off).align(Alignment.Center)
      }
      .width('100%').height('100%')

      // FPS overlay — remounted (keyed on activeScenario) so droppedCount
      // resets to zero for each scenario run, giving a fresh per-scenario
      // dropped-frame counter instead of the cumulative, never-reset value.
      ForEach(
        [this.activeScenario],
        (_s: string) => {
          FpsOverlay({ scenario: this.activeScenario, errorText: this.errorText })
        },
        (_s: string) => this.activeScenario
      )
    }
    .width('100%').height('100%')
  }
}
