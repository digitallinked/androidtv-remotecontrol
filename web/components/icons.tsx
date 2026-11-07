import type { ReactNode } from 'react';

const PATHS = {
  chevronUp: <path d="m6 15 6-6 6 6" />,
  chevronDown: <path d="m6 9 6 6 6-6" />,
  chevronLeft: <path d="m15 6-6 6 6 6" />,
  chevronRight: <path d="m9 6 6 6-6 6" />,
  back: <path d="M20 12H5m6-6-6 6 6 6" />,
  home: <path d="M4 11.5 12 5l8 6.5M6.5 10v9h11v-9M10 19v-5h4v5" />,
  plus: <path d="M12 6v12M6 12h12" />,
  minus: <path d="M6 12h12" />,
  volume: <path d="M4 10v4h3l5 4V6L7 10H4Zm12 -1a4 4 0 0 1 0 6m2.5-8.5a7.5 7.5 0 0 1 0 11" />,
  mute: <path d="M4 10v4h3l5 4V6L7 10H4Zm12 0 4 4m0-4-4 4" />,
  keyboard: (
    <path d="M3.5 7.5h17v10h-17zM7 11h.01M10.3 11h.01M13.7 11h.01M17 11h.01M8 14.5h8" />
  ),
  search: <path d="M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14Zm9 2-4-4" />,
  touchpad: <path d="M4.5 5.5h15v13h-15zM12 15v-3.5m-2.5 1.2L12 10l2.5 2.700" />,
  dpad: (
    <path d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0-6a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z" />
  ),
  numbers: (
    <g fill="currentColor" stroke="none">
      {[6, 12, 18].flatMap((y) =>
        [6, 12, 18].map((x) => <circle key={`${x}-${y}`} cx={x} cy={y} r={1.6} />),
      )}
    </g>
  ),
  apps: <path d="M5 5h5v5H5zM14 5h5v5h-5zM5 14h5v5H5zM14 14h5v5h-5z" />,
  tv: <path d="M3.500 6h17v11h-17zM9 20.500h6" />,
  power: <path d="M12 4v8m5.500-5a8 8 0 1 1-11 0" />,
  moon: <path d="M19 14.500A7.500 7.500 0 0 1 9.500 5a7.500 7.500 0 1 0 9.500 9.500Z" />,
  play: <path d="M8 5.500v13l10-6.500-10-6.500Z" />,
  pause: <path d="M8.500 6v12m7-12v12" />,
} satisfies Record<string, ReactNode>;

export type IconName = keyof typeof PATHS;

export function Icon({ name, size = 24 }: { name: IconName; size?: number }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {PATHS[name]}
    </svg>
  );
}

/** The app's mark: the ring, the centre dot and four triangles. */
export function Mark({ size = 28 }: { size?: number }) {
  return (
    <svg viewBox="0 0 108 108" width={size} height={size} aria-hidden="true">
      <rect width="108" height="108" rx="24" fill="#3D5AFE" />
      <path
        fill="#fff"
        fillRule="evenodd"
        d="M87.8 54A33.8 33.8 0 1 0 20.2 54A33.8 33.8 0 1 0 87.8 54ZM78.7 54A24.7 24.7 0 1 0 29.3 54A24.7 24.7 0 1 0 78.7 54ZM63.1 54A9.1 9.1 0 1 0 44.9 54A9.1 9.1 0 1 0 63.1 54ZM59.2 40.35L48.8 40.35L54 33.85ZM67.65 59.2L67.65 48.8L74.15 54ZM48.8 67.65L59.2 67.65L54 74.15ZM40.35 48.8L40.35 59.2L33.85 54Z"
      />
    </svg>
  );
}
