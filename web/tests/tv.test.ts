import { describe, expect, it } from 'vitest';
import {
  focusedTitle,
  initialTv,
  press,
  searchResults,
  typeQuery,
  type Key,
  type TvState,
} from '@/lib/tv';

const run = (keys: Key[], from: TvState = initialTv) => keys.reduce(press, from);

describe('home screen', () => {
  it('starts on the first tile, not on Search', () => {
    expect(initialTv.screen).toBe('home');
    expect(focusedTitle(initialTv)?.name).toBe('Night Market');
  });

  it('moves focus along a row and stops at the edges', () => {
    expect(run(['right']).col).toBe(1);
    expect(run(['left']).col).toBe(0);
    expect(run(['right', 'right', 'right', 'right', 'right']).col).toBe(3);
  });

  it('keeps the column when focus passes through the Search row', () => {
    const state = run(['right', 'right', 'up', 'down']);
    expect(state.row).toBe(1);
    expect(state.col).toBe(2);
  });

  it('stops at the top and the bottom', () => {
    expect(run(['up', 'up', 'up']).row).toBe(0);
    expect(run(['down', 'down', 'down']).row).toBe(2);
  });

  it('ignores left and right on the Search row', () => {
    expect(run(['right', 'up', 'right']).col).toBe(1);
  });
});

describe('opening things', () => {
  it('OK on a tile plays it, Back returns to the same tile', () => {
    const playing = run(['right', 'ok']);
    expect(playing.screen).toBe('playing');
    expect(playing.playingId).toBe(focusedTitle(run(['right']))?.id);
    const back = press(playing, 'back');
    expect(back.screen).toBe('home');
    expect(back.col).toBe(1);
    expect(back.playingId).toBeNull();
  });

  it('OK while playing pauses and resumes', () => {
    const paused = run(['ok', 'ok']);
    expect(paused.paused).toBe(true);
    expect(press(paused, 'ok').paused).toBe(false);
  });

  it('a new title does not start paused', () => {
    expect(run(['ok', 'ok', 'back', 'ok']).paused).toBe(false);
  });

  it('Home always goes back to the home screen', () => {
    expect(run(['ok', 'home']).screen).toBe('home');
    expect(run(['up', 'ok', 'home']).screen).toBe('home');
  });
});

describe('search', () => {
  const search = run(['up', 'ok']);

  it('OK on Search opens the search screen', () => {
    expect(search.screen).toBe('search');
  });

  it('filters by what was typed, ignoring case', () => {
    expect(searchResults('night').map((t) => t.name)).toEqual(['Night Market']);
    expect(searchResults('')).toHaveLength(8);
    expect(searchResults('zzz')).toEqual([]);
  });

  it('typing resets the result focus', () => {
    const moved = press(search, 'right');
    expect(moved.resultIndex).toBe(1);
    expect(typeQuery(moved, 'm').resultIndex).toBe(0);
  });

  it('plays the focused result', () => {
    const typed = typeQuery(search, 'harbour');
    const playing = press(typed, 'ok');
    expect(playing.screen).toBe('playing');
    expect(focusedTitle(playing)?.name).toBe('Harbour Lights');
  });

  it('OK with no results does nothing', () => {
    expect(press(typeQuery(search, 'zzz'), 'ok').screen).toBe('search');
  });

  it('leaving search clears the query', () => {
    expect(press(typeQuery(search, 'x'), 'back').query).toBe('');
  });

  it('ignores typing on other screens', () => {
    expect(typeQuery(initialTv, 'x').query).toBe('');
  });
});

describe('volume', () => {
  it('steps between 0 and 20', () => {
    expect(run(['volUp']).volume).toBe(initialTv.volume + 1);
    expect(run(Array<Key>(30).fill('volUp')).volume).toBe(20);
    expect(run(Array<Key>(30).fill('volDown')).volume).toBe(0);
  });

  it('changing the volume unmutes', () => {
    const muted = run(['mute']);
    expect(muted.muted).toBe(true);
    expect(press(muted, 'volUp').muted).toBe(false);
  });

  it('bumps the tick so the TV shows its volume bar', () => {
    expect(run(['volUp']).volumeTick).toBe(initialTv.volumeTick + 1);
    expect(run(['mute']).volumeTick).toBe(initialTv.volumeTick + 1);
    expect(run(['right']).volumeTick).toBe(initialTv.volumeTick);
  });
});
