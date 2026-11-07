import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Metadata } from 'next';
import { marked } from 'marked';
import { SiteFooter, SiteHeader } from '@/components/SiteChrome';
import { prepareLegal, releaseValues } from '@/lib/release';
import { site } from '@/lib/site';

function load(file: string) {
  const raw = readFileSync(join(process.cwd(), 'content', file), 'utf8');
  return prepareLegal(raw, {
    ...releaseValues(),
    PRIVACY_POLICY_URL: `${site.url}/privacy`,
    TERMS_URL: `${site.url}/terms`,
    SUPPORT_URL: `${site.url}/support`,
  });
}

export function legalMetadata(file: string, title: string): Metadata {
  const { draft } = load(file);
  return { title, robots: draft ? { index: false, follow: true } : undefined };
}

export function LegalPage({ file }: { file: string }) {
  const page = load(file);
  return (
    <>
      <div className="paper">
        <SiteHeader tone="light" />
        <main className="prose-page">
          <h1>{page.title}</h1>
          {page.draft && (
            <p className="draft-note">
              This is a draft under review. It isn&rsquo;t in effect yet, and values marked
              &ldquo;to be confirmed&rdquo; will be filled in before launch.
            </p>
          )}
          <div className="prose" dangerouslySetInnerHTML={{ __html: marked.parse(page.markdown, { async: false }) }} />
        </main>
      </div>
      <SiteFooter />
    </>
  );
}
