'use client';

import { Icon, type IconName } from '@/components/icons';
import { PressKey } from '@/components/demo/PressKey';
import type { Key } from '@/lib/tv';

const WEDGES: { key: Key; label: string; icon: IconName }[] = [
  { key: 'up', label: 'Up', icon: 'chevronUp' },
  { key: 'right', label: 'Right', icon: 'chevronRight' },
  { key: 'down', label: 'Down', icon: 'chevronDown' },
  { key: 'left', label: 'Left', icon: 'chevronLeft' },
];

interface DpadProps {
  /** The direction lit by the last press. */
  lit: Key | null;
  onKey: (key: Key) => void;
}

/** The app's mark made into a control: a ring that lights where you press. */
export function Dpad({ lit, onKey }: DpadProps) {
  return (
    <div className="dpad" data-lit={lit ?? undefined}>
      <span className="dpad-ring" aria-hidden="true" />
      <span className="dpad-arc" aria-hidden="true" />
      {WEDGES.map(({ key, label, icon }) => (
        <PressKey
          key={key}
          label={label}
          className={`dpad-wedge dpad-wedge-${key}`}
          repeat
          onPress={() => onKey(key)}
        >
          <span className="dpad-glyph">
            <Icon name={icon} size={26} />
          </span>
        </PressKey>
      ))}
      <PressKey label="OK" className="dpad-ok" onPress={() => onKey('ok')}>
        OK
      </PressKey>
    </div>
  );
}
