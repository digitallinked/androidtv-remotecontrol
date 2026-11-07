'use client';

import { useRef, useState, type CSSProperties, type KeyboardEvent, type PointerEvent } from 'react';
import type { Key } from '@/lib/tv';

const SWIPE_STEP_PX = 44;
const TAP_SLOP_PX = 10;

const ARROWS: Record<string, Key> = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
};

/** A recessed pad with a dot matrix that lights under the thumb. */
export function Touchpad({ onKey }: { onKey: (key: Key) => void }) {
  const anchor = useRef<{ x: number; y: number } | null>(null);
  const moved = useRef(0);
  const [glow, setGlow] = useState<{ x: number; y: number } | null>(null);

  const locate = (event: PointerEvent<HTMLDivElement>) => {
    const box = event.currentTarget.getBoundingClientRect();
    setGlow({ x: event.clientX - box.left, y: event.clientY - box.top });
  };

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    event.currentTarget.setPointerCapture(event.pointerId);
    anchor.current = { x: event.clientX, y: event.clientY };
    moved.current = 0;
    locate(event);
  };

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (!anchor.current) return;
    locate(event);
    const dx = event.clientX - anchor.current.x;
    const dy = event.clientY - anchor.current.y;
    moved.current = Math.max(moved.current, Math.abs(dx), Math.abs(dy));
    if (Math.max(Math.abs(dx), Math.abs(dy)) < SWIPE_STEP_PX) return;
    if (Math.abs(dx) >= Math.abs(dy)) onKey(dx < 0 ? 'left' : 'right');
    else onKey(dy < 0 ? 'up' : 'down');
    anchor.current = { x: event.clientX, y: event.clientY };
  };

  const onPointerUp = () => {
    if (anchor.current && moved.current < TAP_SLOP_PX) onKey('ok');
    anchor.current = null;
    setGlow(null);
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const key = ARROWS[event.key];
    if (key) {
      event.preventDefault();
      event.stopPropagation();
      onKey(key);
    } else if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      onKey('ok');
    }
  };

  const style = glow ? ({ '--x': `${glow.x}px`, '--y': `${glow.y}px` } as CSSProperties) : undefined;

  return (
    <div
      className="touchpad"
      data-active={glow ? 'true' : undefined}
      style={style}
      role="button"
      tabIndex={0}
      aria-label="Touchpad. Arrow keys move, Enter selects."
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={() => {
        anchor.current = null;
        setGlow(null);
      }}
      onKeyDown={onKeyDown}
    >
      <span className="touchpad-lit" aria-hidden="true" />
      <span className="touchpad-hint">Swipe to move, tap to select</span>
    </div>
  );
}
