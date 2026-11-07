// The simulated TV behind the hero demo. Pure state, so it can be tested
// without a browser. All titles are invented for this page.

export type Key =
  | 'up'
  | 'down'
  | 'left'
  | 'right'
  | 'ok'
  | 'back'
  | 'home'
  | 'volUp'
  | 'volDown'
  | 'mute';

export interface Title {
  id: string;
  name: string;
  kind: string;
  /** The tile's colour, which also lights the room around the TV. */
  hue: string;
}

export const WATCHING: Title[] = [
  { id: 'night-market', name: 'Night Market', kind: 'Documentary', hue: '#96600F' },
  { id: 'slow-train', name: 'The Slow Train', kind: 'Series', hue: '#0E7C86' },
  { id: 'harbour-lights', name: 'Harbour Lights', kind: 'Film', hue: '#BE3A6B' },
  { id: 'deep-field', name: 'Deep Field', kind: 'Series', hue: '#3D5AFE' },
];

export const APPS: Title[] = [
  { id: 'movies', name: 'Movies', kind: 'App', hue: '#2563EB' },
  { id: 'music', name: 'Music', kind: 'App', hue: '#7C3AED' },
  { id: 'news', name: 'News', kind: 'App', hue: '#DC2626' },
  { id: 'sports', name: 'Sports', kind: 'App', hue: '#15803D' },
];

const ALL_TITLES = [...WATCHING, ...APPS];
const ROWS: Title[][] = [[], WATCHING, APPS];
const SEARCH_ROW = 0;
const LAST_COL = 3;
const MAX_VOLUME = 20;

export type Screen = 'home' | 'search' | 'playing';

export interface TvState {
  screen: Screen;
  /** Home focus. Row 0 is the Search bar; the column survives a trip through it. */
  row: number;
  col: number;
  resultIndex: number;
  query: string;
  playingId: string | null;
  paused: boolean;
  volume: number;
  muted: boolean;
  /** Goes up on each volume change, so the TV knows to show its volume bar. */
  volumeTick: number;
}

export const initialTv: TvState = {
  screen: 'home',
  row: 1,
  col: 0,
  resultIndex: 0,
  query: '',
  playingId: null,
  paused: false,
  volume: 12,
  muted: false,
  volumeTick: 0,
};

export function searchResults(query: string): Title[] {
  const needle = query.trim().toLowerCase();
  if (!needle) return ALL_TITLES;
  return ALL_TITLES.filter((title) => title.name.toLowerCase().includes(needle));
}

/** The title on screen or under the focus ring, if there is one. */
export function focusedTitle(state: TvState): Title | null {
  switch (state.screen) {
    case 'playing':
      return ALL_TITLES.find((title) => title.id === state.playingId) ?? null;
    case 'search':
      return searchResults(state.query)[state.resultIndex] ?? null;
    case 'home':
      return ROWS[state.row][state.col] ?? null;
  }
}

function play(state: TvState, title: Title | null): TvState {
  if (!title) return state;
  return { ...state, screen: 'playing', playingId: title.id, paused: false };
}

function toHome(state: TvState): TvState {
  return { ...state, screen: 'home', playingId: null, paused: false, query: '', resultIndex: 0 };
}

function pressHome(state: TvState, key: Key): TvState {
  const onSearchRow = state.row === SEARCH_ROW;
  switch (key) {
    case 'up':
      return { ...state, row: Math.max(SEARCH_ROW, state.row - 1) };
    case 'down':
      return { ...state, row: Math.min(ROWS.length - 1, state.row + 1) };
    case 'left':
      return onSearchRow ? state : { ...state, col: Math.max(0, state.col - 1) };
    case 'right':
      return onSearchRow ? state : { ...state, col: Math.min(LAST_COL, state.col + 1) };
    case 'ok':
      return onSearchRow ? { ...state, screen: 'search' } : play(state, focusedTitle(state));
    default:
      return state;
  }
}

function pressSearch(state: TvState, key: Key): TvState {
  const last = Math.max(0, searchResults(state.query).length - 1);
  switch (key) {
    case 'left':
      return { ...state, resultIndex: Math.max(0, state.resultIndex - 1) };
    case 'right':
      return { ...state, resultIndex: Math.min(last, state.resultIndex + 1) };
    case 'ok':
      return play(state, focusedTitle(state));
    default:
      return state;
  }
}

export function press(state: TvState, key: Key): TvState {
  switch (key) {
    case 'volUp':
    case 'volDown': {
      const step = key === 'volUp' ? 1 : -1;
      return {
        ...state,
        volume: Math.min(MAX_VOLUME, Math.max(0, state.volume + step)),
        muted: false,
        volumeTick: state.volumeTick + 1,
      };
    }
    case 'mute':
      return { ...state, muted: !state.muted, volumeTick: state.volumeTick + 1 };
    case 'home':
    case 'back':
      return toHome(state);
  }
  if (state.screen === 'home') return pressHome(state, key);
  if (state.screen === 'search') return pressSearch(state, key);
  return key === 'ok' ? { ...state, paused: !state.paused } : state;
}

export function typeQuery(state: TvState, query: string): TvState {
  if (state.screen !== 'search') return state;
  return { ...state, query, resultIndex: 0 };
}
