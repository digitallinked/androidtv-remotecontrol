import { LegalPage, legalMetadata, type LegalDoc } from '@/components/LegalPage';

const DOC: LegalDoc = {
  file: 'terms.ms.md',
  lang: 'ms',
  path: '/terms/ms',
  other: { path: '/terms', label: 'Read in English', lang: 'en' },
};

export const metadata = legalMetadata(DOC, 'Terma penggunaan');

export default function TermsMalayPage() {
  return <LegalPage doc={DOC} />;
}
