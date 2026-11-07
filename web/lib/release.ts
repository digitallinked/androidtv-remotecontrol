// Public values and legal pages, read from the copies of docs/release in
// web/content. `npm run sync:release` refreshes them.

import placeholders from '@/content/placeholders.json';

type Values = Record<string, string | null>;

/** A real value, or null for anything still unset or a known placeholder. */
export function publicValue(value: string | null | undefined): string | null {
  if (!value) return null;
  if (value.includes('example.com') || /^0+$/.test(value)) return null;
  return value;
}

export function releaseValues(): Values {
  const values: Values = {};
  for (const [token, entry] of Object.entries(placeholders)) {
    values[token] = publicValue(entry.value);
  }
  return values;
}

export interface LegalPage {
  title: string;
  markdown: string;
  /** True until the owner has reviewed the source and every value is real. */
  draft: boolean;
}

const OWNER_SECTION = /\n---\s*\n+## Owner to confirm[\s\S]*$/;
const DRAFT_NOTICE = /^> DRAFT.*\n+/;
const OWNER_NOTE = /\s*\[owner to confirm[^\]]*\]/gi;
const TOKEN = /\{\{([A-Z_]+)\}\}/g;
const UNSET = '(to be confirmed)';

/** Turns a release doc into what the site publishes, without the owner's notes. */
export function prepareLegal(source: string, values: Values): LegalPage {
  // Git checks these out with CRLF on Windows, and `.` doesn't match `\r`.
  const raw = source.replace(/\r\n/g, '\n');
  let missing = false;
  const body = raw
    .replace(OWNER_SECTION, '\n')
    .replace(DRAFT_NOTICE, '')
    .replace(OWNER_NOTE, '')
    .replace(TOKEN, (_, token: string) => {
      const value = values[token];
      if (value) return value;
      missing = true;
      return UNSET;
    });

  const heading = body.match(/^# (.+)$/m);
  return {
    title: heading ? heading[1].trim() : '',
    markdown: body.replace(/^# .+\n+/m, '').trim(),
    draft: missing || DRAFT_NOTICE.test(raw),
  };
}
