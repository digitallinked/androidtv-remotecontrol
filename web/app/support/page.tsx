import type { Metadata } from 'next';
import { SiteFooter, SiteHeader } from '@/components/SiteChrome';
import { site } from '@/lib/site';

export const metadata: Metadata = {
  title: 'Support',
  description: `Find your TV, fix pairing and connection problems, and get answers about ${site.name}.`,
};

const CHECKS = [
  'Connect your phone and TV to the same Wi-Fi network, not a guest network.',
  "Turn the TV on. Some TVs can't be found while in standby.",
  'On the TV, make sure "Android TV Remote Service" is installed and up to date in the Play Store.',
  'On iPhone, allow Local Network access for this app in Settings, then Privacy & Security, then Local Network.',
  'Still nothing? Restart the TV and your router, then scan again.',
  "You can also enter the TV's IP address. Find it on the TV under Settings, then Network & Internet.",
];

const QUESTIONS = [
  {
    q: 'Which TVs does this app work with?',
    a: "TVs and streaming boxes that run Android TV or Google TV, on the same Wi-Fi network as your phone. TVs with other systems, such as Samsung (Tizen), LG (webOS), Roku or Fire TV, can't be controlled by this app.",
  },
  {
    q: 'Why does the TV ask for a code again?',
    a: "Pairing makes the TV and your phone trust each other. Clearing the app's data, reinstalling the app or resetting the TV removes that trust, so you pair once more with a new code.",
  },
  {
    q: "Why can't the app turn my TV on?",
    a: "A TV that is fully off can't hear the app. The app can send a wake-up signal if you add the TV's MAC address under Settings, then Your TVs, but some TVs ignore it in deep standby. On iPhone this isn't available yet.",
  },
  {
    q: "What I type doesn't show up on the TV.",
    a: 'Select a text field on the TV first, such as a search box. When the TV asks for text, the keyboard opens on your phone by itself.',
  },
  {
    q: "An app shortcut doesn't open.",
    a: "The app has to be installed on the TV. Some apps have a different version in each country: add the right one by its app ID under Settings, then Apps.",
  },
  {
    q: 'What does the app keep about my TV?',
    a: "Your TV's name, network address and MAC address stay on your phone. The app can send usage statistics and crash reports, which never include them. You can turn each on or off in Settings, then Privacy choices.",
  },
  {
    q: 'I moved to a new phone. Where are my TVs?',
    a: "Your TVs and their pairing stay on the phone you paired them with. They aren't copied by backups or when you move to a new phone, so pair each TV again on the new phone.",
  },
];

export default function SupportPage() {
  return (
    <>
      <div className="paper">
        <SiteHeader tone="light" />
        <main className="prose-page">
          <h1>Support</h1>

          <h2>Can&rsquo;t find your TV?</h2>
          <p>Go through these one at a time. Most problems come from the Wi-Fi network or the TV&rsquo;s remote service.</p>
          <ol className="check-list">
            {CHECKS.map((check) => (
              <li key={check}>{check}</li>
            ))}
          </ol>

          <h2>Common questions</h2>
          <div className="faq">
            {QUESTIONS.map(({ q, a }) => (
              <details key={q}>
                <summary>{q}</summary>
                <p>{a}</p>
              </details>
            ))}
          </div>

          {site.supportEmail && (
            <>
              <h2>Still stuck?</h2>
              <p>
                Write to <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>. In the app,
                Settings, then Help, then Error log shows the last errors, which you can copy into
                your message.
              </p>
            </>
          )}
        </main>
      </div>
      <SiteFooter />
    </>
  );
}
