import Link from 'next/link';
import { SiteFooter, SiteHeader } from '@/components/SiteChrome';

export default function NotFound() {
  return (
    <>
      <div className="paper">
        <SiteHeader tone="light" />
        <main className="prose-page">
          <h1>This page isn&rsquo;t here</h1>
          <p>
            The address may be wrong, or the page may have moved. <Link href="/">Go to the home page</Link>
          </p>
        </main>
      </div>
      <SiteFooter />
    </>
  );
}
