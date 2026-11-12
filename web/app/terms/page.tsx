import { LegalPage, legalMetadata, type LegalDoc } from '@/components/LegalPage';

const DOC: LegalDoc = {
  file: 'terms.md',
  lang: 'en',
  path: '/terms',
  other: { path: '/terms/ms', label: 'Baca dalam Bahasa Melayu', lang: 'ms' },
};

export const metadata = legalMetadata(DOC, 'Terms of use');

export default function TermsPage() {
  return <LegalPage doc={DOC} />;
}
