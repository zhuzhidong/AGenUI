/**
 * JankStorySmoke.test.ets
 *
 * Smoke test for structural-jank A2UI stories under rawfile stories/Jank/.
 * Loads each generated jank story and asserts version / surfaceId / non-empty components,
 * exercising the resource + rawfile pipeline that the generator script produces.
 *
 * 适配本仓库既有 ohosTest 约定：getContext() 在 beforeEach 中取，
 * resourceManager 走 @ohos.resourceManager 默认导入，util 走 @ohos.util。
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';

export default function jankStorySmoke() {
  describe('JankStorySmoke', () => {
    const stories = ['MassiveTree', 'DeepNesting', 'HugePayload'];
    const expectedSurface = ['jank-massive', 'jank-deep', 'jank-huge'];

    let context: common.UIAbilityContext;

    beforeEach(() => {
      context = getContext() as common.UIAbilityContext;
    });

    it('parses_all_jank_stories', 0, async () => {
      const resMgr: resourceManager.ResourceManager = context.resourceManager;
      for (let i = 0; i < stories.length; i++) {
        const raw = await resMgr.getRawFileContent(`stories/Jank/${stories[i]}/updateComponents.json`);
        const text = new util.TextDecoder('utf-8').decodeWithStream(raw);
        const obj = JSON.parse(text) as Record<string, Object>;
        expect(obj['version']).assertEqual('v0.9');
        const uc = obj['updateComponents'] as Record<string, Object>;
        expect(uc['surfaceId']).assertEqual(expectedSurface[i]);
        expect((uc['components'] as Object[]).length > 0).assertTrue();
      }
    });
  });
}
