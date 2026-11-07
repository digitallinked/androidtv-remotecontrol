import { LegalPage, legalMetadata } from '@/components/LegalPage';

const FILE = 'terms.md';

export const metadata = legalMetadata(FILE, 'Terms of use');

export default function TermsPage() {
  return <LegalPage file={FILE} />;
}
