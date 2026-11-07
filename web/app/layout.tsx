import type { Metadata, Viewport } from 'next';
import localFont from 'next/font/local';
import type { ReactNode } from 'react';
import { site } from '@/lib/site';
import './globals.css';

const text = localFont({
  src: [
    { path: './fonts/AtkinsonHyperlegibleNext-Regular.ttf', weight: '400', style: 'normal' },
    { path: './fonts/AtkinsonHyperlegibleNext-Medium.ttf', weight: '500', style: 'normal' },
    { path: './fonts/AtkinsonHyperlegibleNext-SemiBold.ttf', weight: '600', style: 'normal' },
  ],
  variable: '--font-text',
  display: 'swap',
});

const mono = localFont({
  src: './fonts/AtkinsonHyperlegibleMono-Medium.ttf',
  weight: '500',
  variable: '--font-mono',
  display: 'swap',
  preload: false,
});

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: `${site.name}: ${site.tagline}`, template: `%s | ${site.name}` },
  description: site.description,
  openGraph: {
    title: site.tagline,
    description: site.description,
    siteName: site.name,
    type: 'website',
    url: '/',
  },
  twitter: { card: 'summary_large_image' },
};

export const viewport: Viewport = {
  themeColor: '#0B0D18',
  colorScheme: 'light dark',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${text.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
