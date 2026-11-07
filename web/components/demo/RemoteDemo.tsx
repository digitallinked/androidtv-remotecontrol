'use client';

import {
  useCallback,
  useEffect,
  useReducer,
  useRef,
  useState,
  type CSSProperties,
  type KeyboardEvent,
} from 'react';
import { Icon } from '@/components/icons';
import { Dpad } from '@/components/demo/Dpad';
import { PressKey } from '@/components/demo/PressKey';
import { Touchpad } from '@/components/demo/Touchpad';
import { TvScreen } from '@/components/demo/TvScreen';
import { focusedTitle, initialTv, press, typeQuery, type Key, type TvState } from '@/lib/tv';

type Action = { type: 'key'; key: Key } | { type: 'text'; text: string };

function reducer(state: TvState, action: Action): TvState {
  return action.type === 'key' ? press(state, action.key) : typeQuery(state, action.text);
}

const ARROWS: Record<string, Key> = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
};

const LIT_MS = 180;
const NOTICE_MS = 2200;
const NEUTRAL_LIGHT = '#3D5AFE';

function announce(state: TvState): string {
  const title = focusedTitle(state);
  if (state.screen === 'playing' && title) return `${state.paused ? 'Paused' : 'Playing'} ${title.name}`;
  if (state.screen === 'search') return title ? `Search result ${title.name}` : 'No results';
  if (state.row === 0) return 'Search';
  return title?.name ?? '';
}

export function RemoteDemo() {
  const [state, dispatch] = useReducer(reducer, initialTv);
  const [pad, setPad] = useState<'dpad' | 'touchpad'>('dpad');
  const [lit, setLit] = useState<Key | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);
  const litTimer = useRef<number | undefined>(undefined);
  const noticeTimer = useRef<number | undefined>(undefined);
  const input = useRef<HTMLInputElement>(null);

  const keyboardOpen = state.screen === 'search';

  const send = useCallback((key: Key) => {
    setTouched(true);
    setNotice(null);
    dispatch({ type: 'key', key });
    setLit(key);
    window.clearTimeout(litTimer.current);
    litTimer.current = window.setTimeout(() => setLit(null), LIT_MS);
    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) navigator.vibrate?.(8);
  }, []);

  // The keyboard opens by itself when the TV asks for text, as it does in the app.
  // Keys fire on pointer down, and the browser then focuses the key itself, so
  // take focus again once the click has finished. A tap's click is also the
  // gesture iOS asks for before it shows the on-screen keyboard.
  useEffect(() => {
    if (!keyboardOpen) return;
    const focusInput = () => input.current?.focus({ preventScroll: true });
    focusInput();
    window.addEventListener('click', focusInput, { once: true });
    return () => window.removeEventListener('click', focusInput);
  }, [keyboardOpen]);

  useEffect(
    () => () => {
      window.clearTimeout(litTimer.current);
      window.clearTimeout(noticeTimer.current);
    },
    [],
  );

  const onKeyboardKey = () => {
    if (keyboardOpen) {
      input.current?.focus();
      return;
    }
    setTouched(true);
    setNotice('Select Search on the TV first');
    window.clearTimeout(noticeTimer.current);
    noticeTimer.current = window.setTimeout(() => setNotice(null), NOTICE_MS);
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const key = ARROWS[event.key];
    if (!key) return;
    if (event.target instanceof HTMLInputElement && (key === 'left' || key === 'right')) return;
    event.preventDefault();
    send(key);
  };

  const light = focusedTitle(state)?.hue ?? NEUTRAL_LIGHT;
  const stageStyle = { '--light': light } as CSSProperties;

  return (
    <div className="stage" data-screen={state.screen} style={stageStyle}>
      <div className="stage-light" aria-hidden="true" />
      <div className="stage-tv">
        <TvScreen state={state} notice={notice} />
        <p className="stage-caption">
          {touched
            ? 'A simulated TV, so you can feel how it works.'
            : 'Try it: press the arrows on the remote, then OK.'}
        </p>
      </div>

      <div className="phone" onKeyDown={onKeyDown}>
        <div className="phone-top">
          <span className="phone-tv-name">Living Room TV</span>
          <span className="demo-badge">Demo</span>
        </div>
        <div className="status-strip">
          <span className="status-lamp" data-state="connected" aria-hidden="true" />
          Connected
        </div>

        <div className="pad-tabs" role="group" aria-label="Choose a control">
          {(['dpad', 'touchpad'] as const).map((name) => (
            <button
              key={name}
              type="button"
              className="pad-tab"
              aria-pressed={pad === name}
              onClick={() => setPad(name)}
            >
              {name === 'dpad' ? 'D-pad' : 'Touchpad'}
            </button>
          ))}
        </div>

        <div className="pad-area">
          {pad === 'dpad' ? <Dpad lit={lit} onKey={send} /> : <Touchpad onKey={send} />}
        </div>

        {keyboardOpen ? (
          <label className="keyboard-sheet">
            <span className="keyboard-label">Keyboard</span>
            <input
              ref={input}
              className="keyboard-input"
              type="text"
              autoComplete="off"
              spellCheck={false}
              placeholder="Type a title"
              aria-label="Type on the TV"
              value={state.query}
              onChange={(event) => dispatch({ type: 'text', text: event.target.value })}
              onKeyDown={(event) => {
                if (event.key === 'Enter') send('ok');
              }}
            />
          </label>
        ) : null}

        <div className="cluster">
          <div className="rocker" role="group" aria-label="Volume">
            <PressKey label="Volume up" className="rocker-key" repeat onPress={() => send('volUp')}>
              <Icon name="plus" />
            </PressKey>
            <span className="rocker-label" aria-hidden="true">
              <span>Vol</span>
              <span className="rocker-value">{state.muted ? '0' : state.volume}</span>
            </span>
            <PressKey label="Volume down" className="rocker-key" repeat onPress={() => send('volDown')}>
              <Icon name="minus" />
            </PressKey>
          </div>
          <div className="key-grid">
            <PressKey
              label={state.muted ? 'Unmute' : 'Mute'}
              className="key"
              onPress={() => send('mute')}
            >
              <Icon name={state.muted ? 'mute' : 'volume'} />
            </PressKey>
            <PressKey label="Keyboard" className="key" onPress={onKeyboardKey}>
              <Icon name="keyboard" />
            </PressKey>
            <PressKey label="Back" className="key" onPress={() => send('back')}>
              <Icon name="back" />
            </PressKey>
            <PressKey label="Home" className="key" onPress={() => send('home')}>
              <Icon name="home" />
            </PressKey>
          </div>
        </div>
      </div>

      <p className="visually-hidden" aria-live="polite">
        {announce(state)}
      </p>
    </div>
  );
}
