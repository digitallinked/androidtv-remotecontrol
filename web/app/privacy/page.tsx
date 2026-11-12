import { LegalPage, legalMetadata, type LegalDoc } from '@/components/LegalPage';

const DOC: LegalDoc = {
  file: 'privacy-policy.md',
  lang: 'en',
  path: '/privacy',
  other: { path: '/privacy/ms', label: 'Baca dalam Bahasa Melayu', lang: 'ms' },
};

export const metadata = legalMetadata(DOC, 'Privacy policy');

export default function PrivacyPage() {
  return <LegalPage doc={DOC} />;
}
