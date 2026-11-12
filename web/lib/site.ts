import { releaseValues } from '@/lib/release';

const release = releaseValues();

const productionHost = process.env.VERCEL_PROJECT_PRODUCTION_URL;

export const site = {
  /** The short brand. Change it with docs/release/rename-checklist.md. */
  name: 'Remotely',
  fullName: release.APP_NAME ?? 'Remotely',
  tagline: 'The TV remote that lives on your phone',
  description:
    'A free TV remote app for Android TV and Google TV. Use your phone as the remote: touchpad, D-pad, keyboard and your apps, over your home Wi-Fi.',
  url: process.env.NEXT_PUBLIC_SITE_URL ?? (productionHost ? `https://${productionHost}` : 'http://localhost:3000'),
  supportEmail: release.SUPPORT_EMAIL,
  publisher: release.DEVELOPER_NAME,
  /**
   * Set each link once the listing is live; until then the page says "coming
   * soon" and links to nothing. The Play address can't be derived from the
   * package name alone because the listing doesn't exist yet.
   */
  stores: {
    play: null as string | null,
    appStore: release.APP_STORE_ID ? `https://apps.apple.com/app/id${release.APP_STORE_ID}` : null,
  },
};

export const trademarkNotice =
  "Android TV and Google TV are trademarks of Google LLC. This app isn't made or endorsed by Google.";
