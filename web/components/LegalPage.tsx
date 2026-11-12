import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Metadata } from 'next';
import Link from 'next/link';
import { marked } from 'marked';
import { SiteFooter, SiteHeader } from '@/components/SiteChrome';
import { prepareLegal, releaseValues } from '@/lib/release';
import { site } from '@/lib/site';

/** A legal page and its translation: the English path and the Malay one. */
export interface LegalDoc {
  file: string;
  lang: 'en' | 'ms';
  path: string;
  other: { path: string; label: string; lang: 'en' | 'ms' };
}

function load(file: string) {
  const raw = readFileSync(join(process.cwd(), 'content', file), 'utf8');
  return prepareLegal(raw, {
    ...releaseValues(),
    PRIVACY_POLICY_URL: `${site.url}/privacy`,
    TERMS_URL: `${site.url}/terms`,
    SUPPORT_URL: `${site.url}/support`,
  });
}

export function legalMetadata(doc: LegalDoc, title: string): Metadata {
  const { draft } = load(doc.file);
  const en = doc.lang === 'en' ? doc.path : doc.other.path;
  const ms = doc.lang === 'ms' ? doc.path : doc.other.path;
  return {
    title,
    robots: draft ? { index: false, follow: true } : undefined,
    alternates: { canonical: doc.path, languages: { en, ms, 'x-default': en } },
  };
}

export function LegalPage({ doc }: { doc: LegalDoc }) {
  const page = load(doc.file);
  return (
    <>
      <div className="paper">
        <SiteHeader tone="light" />
        <main className="prose-page" lang={doc.lang}>
          <p className="lang-switch">
            <Link href={doc.other.path} hrefLang={doc.other.lang} lang={doc.other.lang}>
              {doc.other.label}
            </Link>
          </p>
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
