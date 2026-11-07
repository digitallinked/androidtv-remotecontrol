import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { prepareLegal, publicValue } from '@/lib/release';

const raw = `> DRAFT — not legal advice. The owner reviews this.

# {{APP_NAME}} privacy policy

Effective date: {{EFFECTIVE_DATE}}

Write to {{SUPPORT_EMAIL}}. Kept for 90 days. [owner to confirm the retention] Done.

---

## Owner to confirm (remove this section before hosting)

1. A private note.
`;

const values = { APP_NAME: 'Remotely for Android TV', SUPPORT_EMAIL: null, EFFECTIVE_DATE: null };

describe('publicValue', () => {
  it('treats placeholders as unset', () => {
    expect(publicValue('https://example.com/privacy')).toBeNull();
    expect(publicValue('support@example.com')).toBeNull();
    expect(publicValue('0000000000')).toBeNull();
    expect(publicValue(null)).toBeNull();
    expect(publicValue('Remotely')).toBe('Remotely');
  });
});

describe('prepareLegal', () => {
  const page = prepareLegal(raw, values);

  it('never publishes the owner notes', () => {
    expect(page.markdown).not.toContain('private note');
    expect(page.markdown).not.toContain('owner to confirm');
    expect(page.markdown).not.toContain('DRAFT');
    expect(page.markdown).not.toContain('Owner to confirm');
  });

  it('handles Windows line endings, which is how the real files arrive', () => {
    const crlf = prepareLegal(raw.replace(/\n/g, '\r\n'), { ...values, SUPPORT_EMAIL: 'a@b.co', EFFECTIVE_DATE: 'soon' });
    expect(crlf.markdown).not.toContain('DRAFT');
    expect(crlf.markdown).not.toContain('private note');
    expect(crlf.markdown).not.toContain('privacy policy');
    expect(crlf.title).toBe('Remotely for Android TV privacy policy');
    // The notice alone must keep the page a draft, with every value filled.
    expect(crlf.draft).toBe(true);
  });

  it('fills known tokens and leaves no raw token behind', () => {
    expect(page.title).toBe('Remotely for Android TV privacy policy');
    expect(page.markdown).not.toContain('{{');
  });

  it('stays a draft while the source says so or a value is missing', () => {
    expect(page.draft).toBe(true);
    expect(prepareLegal('# T\n\nHello {{SUPPORT_EMAIL}}', { SUPPORT_EMAIL: null }).draft).toBe(true);
    expect(prepareLegal('# T\n\nHello {{SUPPORT_EMAIL}}', { SUPPORT_EMAIL: 'a@b.co' }).draft).toBe(false);
  });
});

describe('content copies', () => {
  const release = join(__dirname, '..', '..', 'docs', 'release');
  const content = join(__dirname, '..', 'content');

  it.each([
    ['placeholders.json', 'placeholders.json'],
    ['legal/privacy-policy.md', 'privacy-policy.md'],
    ['legal/terms.md', 'terms.md'],
  ])('%s matches web/content (run npm run sync:release)', (from, to) => {
    if (!existsSync(release)) return;
    expect(readFileSync(join(content, to), 'utf8')).toBe(readFileSync(join(release, from), 'utf8'));
  });
});
