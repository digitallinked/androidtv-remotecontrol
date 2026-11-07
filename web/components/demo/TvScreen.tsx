'use client';

import { Icon } from '@/components/icons';
import { APPS, WATCHING, focusedTitle, searchResults, type Title, type TvState } from '@/lib/tv';

function Tile({ title, focused }: { title: Title; focused: boolean }) {
  return (
    <li className="tv-tile" data-focused={focused || undefined} style={{ background: title.hue }}>
      <span>{title.name}</span>
    </li>
  );
}

function Home({ state }: { state: TvState }) {
  return (
    <div className="tv-home">
      <div className="tv-search-bar" data-focused={state.row === 0 || undefined}>
        <Icon name="search" size={16} />
        <span>Search</span>
      </div>
      <p className="tv-row-title">Keep watching</p>
      <ul className="tv-row">
        {WATCHING.map((title, col) => (
          <Tile key={title.id} title={title} focused={state.row === 1 && state.col === col} />
        ))}
      </ul>
      <p className="tv-row-title">Your apps</p>
      <ul className="tv-row">
        {APPS.map((title, col) => (
          <Tile key={title.id} title={title} focused={state.row === 2 && state.col === col} />
        ))}
      </ul>
    </div>
  );
}

function Search({ state }: { state: TvState }) {
  const results = searchResults(state.query);
  return (
    <div className="tv-home">
      <div className="tv-search-bar" data-focused="true">
        <Icon name="search" size={16} />
        <span>{state.query || 'Type on your phone'}</span>
        <span className="tv-caret" aria-hidden="true" />
      </div>
      {results.length > 0 ? (
        <>
          <p className="tv-row-title">Results</p>
          <ul className="tv-row tv-row-scroll">
            {results.map((title, index) => (
              <Tile key={title.id} title={title} focused={state.resultIndex === index} />
            ))}
          </ul>
        </>
      ) : (
        <p className="tv-row-title">Nothing matches that. Try another word.</p>
      )}
    </div>
  );
}

function Playing({ title, paused }: { title: Title; paused: boolean }) {
  return (
    <div className="tv-playing" style={{ background: title.hue }} data-paused={paused || undefined}>
      <div className="tv-playing-caption">
        <p>{title.kind}</p>
        <h3>{title.name}</h3>
      </div>
      <div className="tv-transport">
        <Icon name={paused ? 'play' : 'pause'} size={18} />
        <span className="tv-progress">
          <span className="tv-progress-fill" />
        </span>
      </div>
    </div>
  );
}

function VolumeBar({ state }: { state: TvState }) {
  return (
    <div className="tv-volume" key={state.volumeTick}>
      <Icon name={state.muted ? 'mute' : 'volume'} size={18} />
      <span className="tv-volume-track">
        <span
          className="tv-volume-fill"
          style={{ width: state.muted ? 0 : `${(state.volume / 20) * 100}%` }}
        />
      </span>
      <span className="tv-volume-number">{state.muted ? 'Muted' : state.volume}</span>
    </div>
  );
}

interface TvScreenProps {
  state: TvState;
  notice: string | null;
}

export function TvScreen({ state, notice }: TvScreenProps) {
  const title = focusedTitle(state);
  return (
    <div className="tv" role="img" aria-label="A simulated TV that responds to the remote">
      <div className="tv-panel">
        {state.screen === 'home' && <Home state={state} />}
        {state.screen === 'search' && <Search state={state} />}
        {state.screen === 'playing' && title && <Playing title={title} paused={state.paused} />}
        {state.volumeTick > 0 && <VolumeBar state={state} />}
        {notice && <p className="tv-notice">{notice}</p>}
      </div>
    </div>
  );
}
