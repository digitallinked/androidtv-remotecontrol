import { LegalPage, legalMetadata } from '@/components/LegalPage';

const FILE = 'privacy-policy.md';

export const metadata = legalMetadata(FILE, 'Privacy policy');

export default function PrivacyPage() {
  return <LegalPage file={FILE} />;
}
