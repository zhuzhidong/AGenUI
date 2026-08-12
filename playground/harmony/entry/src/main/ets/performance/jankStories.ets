/**
 * Baseline surface for the temporal-jank page.
 *
 * Deliberately small and smooth so it is the *canvas* that temporal
 * bad-behavior drivers jank — NOT a jank source itself. Contrast with the
 * structural stories under stories/A2UI Show/Jank/, where the tree IS the
 * jank source.
 */

export const JANK_BASELINE_SURFACE_ID: string = 'jank-baseline';

interface ComponentDef {
  id: string;
  component: string;
  text?: string;
  variant?: string;
  align?: string;
  children?: string[];
}

interface UpdateComponentsPayload {
  surfaceId: string;
  components: ComponentDef[];
}

interface BaselinePayload {
  version: string;
  updateComponents: UpdateComponentsPayload;
}

const LIST_ITEM_COUNT = 10;
const listItemIds: string[] = [];
for (let i = 0; i < LIST_ITEM_COUNT; i++) {
  listItemIds.push(`li-${i}`);
}

const baselineComponents: ComponentDef[] = [
  { id: 'root', component: 'Column', align: 'stretch', children: ['block', 'list'] },
  { id: 'block', component: 'Text', text: '█', variant: 'h1' },
  { id: 'list', component: 'List', children: listItemIds }
];
for (let i = 0; i < LIST_ITEM_COUNT; i++) {
  baselineComponents.push({ id: `li-${i}`, component: 'Text', text: `Item ${i}`, variant: 'body' });
}

const baselineJson: BaselinePayload = {
  version: 'v0.9',
  updateComponents: { surfaceId: JANK_BASELINE_SURFACE_ID, components: baselineComponents }
};
export const JANK_BASELINE_JSON: string = JSON.stringify(baselineJson);

/** Valid tiny payload spammed by TinyChunkStream to stress the stream parser. */
const baselineChunk: BaselinePayload = {
  version: 'v0.9',
  updateComponents: { surfaceId: JANK_BASELINE_SURFACE_ID, components: [] }
};
export const JANK_BASELINE_CHUNK: string = JSON.stringify(baselineChunk);
