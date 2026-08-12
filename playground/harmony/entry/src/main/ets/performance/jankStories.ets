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

const LIST_ITEM_COUNT = 10;
const listItemIds: string[] = [];
for (let i = 0; i < LIST_ITEM_COUNT; i++) {
  listItemIds.push(`li-${i}`);
}

const baselineComponents: ComponentDef[] = [
  { id: 'root', component: 'Column', align: 'stretch', children: ['block', 'list', ...listItemIds] },
  { id: 'block', component: 'Text', text: '█', variant: 'h1' },
  { id: 'list', component: 'List', children: listItemIds }
];
for (let i = 0; i < LIST_ITEM_COUNT; i++) {
  baselineComponents.push({ id: `li-${i}`, component: 'Text', text: `Item ${i}`, variant: 'body' });
}

export const JANK_BASELINE_JSON: string = JSON.stringify({
  version: 'v0.9',
  updateComponents: { surfaceId: JANK_BASELINE_SURFACE_ID, components: baselineComponents }
});

/** Valid tiny payload spammed by TinyChunkStream to stress the stream parser. */
export const JANK_BASELINE_CHUNK: string = JSON.stringify({
  version: 'v0.9',
  updateComponents: { surfaceId: JANK_BASELINE_SURFACE_ID, components: [] }
});
