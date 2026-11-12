/**
 * A real screen of the app in a phone outline. The images are rendered from
 * the app itself with made-up data (tool/web_screens.ps1 or .sh); the names
 * match the files in public/screens/.
 */
export type ScreenName =
  | 'touchpad'
  | 'dpad'
  | 'touchpad_dark'
  | 'dpad_dark'
  | 'apps'
  | 'keyboard'
  | 'discovery'
  | 'pairing'
  | 'styles'
  | 'tvs';

/** The size every screen is written at: a 412 × 732 dp phone, 720 px wide. */
export const SCREEN_WIDTH = 720;
export const SCREEN_HEIGHT = 1279;

export function AppScreen({
  name,
  alt,
  priority = false,
  className,
}: {
  name: ScreenName;
  alt: string;
  priority?: boolean;
  className?: string;
}) {
  return (
    <div className={className ? `device ${className}` : 'device'}>
      {/* eslint-disable-next-line @next/next/no-img-element -- already sized WebP, no optimiser needed */}
      <img
        src={`/screens/${name}.webp`}
        alt={alt}
        width={SCREEN_WIDTH}
        height={SCREEN_HEIGHT}
        loading={priority ? 'eager' : 'lazy'}
        fetchPriority={priority ? 'high' : undefined}
        decoding="async"
      />
    </div>
  );
}
