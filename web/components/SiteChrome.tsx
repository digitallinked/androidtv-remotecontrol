import Link from 'next/link';
import { Mark } from '@/components/icons';
import { site, trademarkNotice } from '@/lib/site';

export function SiteHeader({ tone }: { tone: 'dark' | 'light' }) {
  return (
    <header className="site-header" data-tone={tone}>
      <Link href="/" className="brand">
        <Mark />
        <span>{site.name}</span>
      </Link>
      <nav aria-label="Main">
        <Link href="/#how-it-works">How it works</Link>
        <Link href="/#plans">Free and Premium</Link>
        <Link href="/support">Support</Link>
      </nav>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="site-footer-inner">
        <Link href="/" className="brand">
          <Mark />
          <span>{site.name}</span>
        </Link>
        <nav aria-label="Footer">
          <Link href="/support">Support</Link>
          <Link href="/privacy">Privacy policy</Link>
          <Link href="/terms">Terms of use</Link>
        </nav>
        <p className="site-footer-notice">{trademarkNotice}</p>
      </div>
    </footer>
  );
}

/** Store links once they exist; a plain statement until then. */
export function Availability() {
  const { play, appStore } = site.stores;
  if (!play && !appStore) {
    return <p className="availability">Coming soon to Google Play and the App Store.</p>;
  }
  return (
    <p className="availability availability-links">
      {play && <a href={play}>Get it on Google Play</a>}
      {appStore && <a href={appStore}>Download on the App Store</a>}
    </p>
  );
}
