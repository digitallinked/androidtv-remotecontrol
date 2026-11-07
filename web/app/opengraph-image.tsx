import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ImageResponse } from 'next/og';
import { site } from '@/lib/site';

export const alt = site.tagline;
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

const MARK =
  'M87.8 54A33.8 33.8 0 1 0 20.2 54A33.8 33.8 0 1 0 87.8 54ZM78.7 54A24.7 24.7 0 1 0 29.3 54A24.7 24.7 0 1 0 78.7 54ZM63.1 54A9.1 9.1 0 1 0 44.9 54A9.1 9.1 0 1 0 63.1 54ZM59.2 40.35L48.8 40.35L54 33.85ZM67.65 59.2L67.65 48.8L74.15 54ZM48.8 67.65L59.2 67.65L54 74.15ZM40.35 48.8L40.35 59.2L33.85 54Z';

export default function OpenGraphImage() {
  const font = readFileSync(join(process.cwd(), 'app/fonts/AtkinsonHyperlegibleNext-SemiBold.ttf'));
  return new ImageResponse(
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        padding: 72,
        background: '#3D5AFE',
        color: '#FFFFFF',
        fontFamily: 'Atkinson',
      }}
    >
      <svg width="120" height="120" viewBox="0 0 108 108">
        <path fill="#FFFFFF" fillRule="evenodd" d={MARK} />
      </svg>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ fontSize: 40 }}>{site.name}</div>
        <div style={{ fontSize: 76, lineHeight: 1.05, maxWidth: 980 }}>{site.tagline}</div>
      </div>
    </div>,
    { ...size, fonts: [{ name: 'Atkinson', data: font, weight: 600, style: 'normal' }] },
  );
}
