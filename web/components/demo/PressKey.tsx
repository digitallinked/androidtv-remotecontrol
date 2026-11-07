'use client';

import { useEffect, useRef, type ReactNode } from 'react';

const HOLD_DELAY_MS = 400;
const REPEAT_MS = 120;

interface PressKeyProps {
  label: string;
  className: string;
  onPress: () => void;
  /** Holding repeats the key, as the app does with Natural hold off. */
  repeat?: boolean;
  children: ReactNode;
}

/** A key that reacts on touch down, and repeats while held if asked to. */
export function PressKey({ label, className, onPress, repeat = false, children }: PressKeyProps) {
  const timers = useRef<number[]>([]);
  const latest = useRef(onPress);
  latest.current = onPress;

  const stop = () => {
    timers.current.forEach((id) => {
      window.clearTimeout(id);
      window.clearInterval(id);
    });
    timers.current = [];
  };

  useEffect(() => stop, []);

  return (
    <button
      type="button"
      className={className}
      aria-label={label}
      onPointerDown={(event) => {
        if (event.button !== 0) return;
        latest.current();
        if (!repeat) return;
        const delay = window.setTimeout(() => {
          timers.current.push(window.setInterval(() => latest.current(), REPEAT_MS));
        }, HOLD_DELAY_MS);
        timers.current.push(delay);
      }}
      onPointerUp={stop}
      onPointerLeave={stop}
      onPointerCancel={stop}
      // Pointers already fired on press. detail is 0 for keyboards and screen readers.
      onClick={(event) => {
        if (event.detail === 0) latest.current();
      }}
    >
      {children}
    </button>
  );
}
