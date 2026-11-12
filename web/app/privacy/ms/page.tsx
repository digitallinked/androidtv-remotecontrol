import { LegalPage, legalMetadata, type LegalDoc } from '@/components/LegalPage';

const DOC: LegalDoc = {
  file: 'privacy-policy.ms.md',
  lang: 'ms',
  path: '/privacy/ms',
  other: { path: '/privacy', label: 'Read in English', lang: 'en' },
};

export const metadata = legalMetadata(DOC, 'Dasar privasi');

export default function PrivacyMalayPage() {
  return <LegalPage doc={DOC} />;
}
