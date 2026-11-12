import Link from 'next/link';
import { AppScreen, type ScreenName } from '@/components/AppScreen';
import { RemoteDemo } from '@/components/demo/RemoteDemo';
import { Icon, type IconName } from '@/components/icons';
import { Availability, SiteFooter, SiteHeader } from '@/components/SiteChrome';
import { site } from '@/lib/site';

const STEPS: { title: string; body: string; screen: ScreenName; alt: string }[] = [
  {
    screen: 'discovery',
    alt: 'The app listing two TVs it found on the network, Bedroom TV and Living Room TV.',
    title: 'Find your TV',
    body: "The app finds TVs on your Wi-Fi network by itself. If yours doesn't show up, enter its IP address.",
  },
  {
    screen: 'pairing',
    alt: 'The pairing page asking for the code shown on Kitchen TV.',
    title: 'Pair once',
    body: 'Type the code your TV shows. You only do this once for each TV.',
  },
  {
    screen: 'touchpad',
    alt: 'The remote connected to Living Room TV, with app shortcuts, the touchpad, and volume and channel keys.',
    title: 'Pick up your phone',
    body: 'After that, the app reconnects by itself, so the remote is ready when you are.',
  },
];

// Captions from docs/release/store-listing/en.md (shot.phone.*).
const TOUR: { screen: ScreenName; caption: string; alt: string }[] = [
  {
    screen: 'dpad',
    caption: "A D-pad that's easy to hit",
    alt: 'The remote with a large D-pad around an OK button.',
  },
  {
    screen: 'apps',
    caption: 'Open your TV apps in one tap',
    alt: 'The Apps screen with shortcuts for Movies, Music, News, Sports, Kids and Photos.',
  },
  {
    screen: 'keyboard',
    caption: "Type with your phone's keyboard",
    alt: 'The keyboard sheet over the remote, with Hello typed and an Enter button.',
  },
  {
    screen: 'tvs',
    caption: 'Switch between all your TVs',
    alt: 'Your TVs: Living Room TV in use, Bedroom TV and Kitchen TV.',
  },
  {
    screen: 'styles',
    caption: 'Dark mode and Premium colour styles',
    alt: 'Appearance settings in dark mode with the Ocean colour style chosen.',
  },
];

const CONTROLS: { icon: IconName; title: string; body: string }[] = [
  { icon: 'touchpad', title: 'Touchpad', body: 'Swipe to move, tap to select.' },
  { icon: 'dpad', title: 'D-pad', body: 'Arrow keys around an OK button, like a TV remote.' },
  { icon: 'numbers', title: 'Number pad', body: 'For channels and codes.' },
  {
    icon: 'volume',
    title: 'Volume and channel',
    body: 'Hold a key and the TV responds as if you held its own remote.',
  },
  {
    icon: 'keyboard',
    title: 'Your own keyboard',
    body: 'It opens by itself when the TV asks for text, like in a search box.',
  },
  {
    icon: 'apps',
    title: 'Your apps in a row',
    body: 'Keep your favourite TV apps on the remote and open them with one tap.',
  },
  {
    icon: 'tv',
    title: 'All your TVs',
    body: 'Save as many as you like, rename them and switch between them from the remote.',
  },
  {
    icon: 'power',
    title: 'Turn the TV on',
    body: "On Android, add the TV's MAC address once and the power key wakes it over the network, if your TV supports it.",
  },
  {
    icon: 'moon',
    title: 'Theater mode',
    body: 'Dims the phone in a dark room, so the only bright screen is the TV.',
  },
];

const STATUSES = [
  { state: 'connected', label: 'Connected' },
  { state: 'reconnecting', label: 'Reconnecting' },
  { state: 'offline', label: 'Offline' },
];

export default function HomePage() {
  const structuredData = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: site.name,
    description: site.description,
    applicationCategory: 'UtilitiesApplication',
    operatingSystem: 'Android, iOS',
    url: site.url,
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <div className="hero">
        <SiteHeader tone="dark" />
        <main>
          <section className="hero-intro" aria-labelledby="hero-title">
            <div className="hero-copy">
              <h1 id="hero-title">{site.tagline}</h1>
              <p className="hero-lead">
                Swipe, tap and type on your Android TV or Google TV over your home Wi-Fi. Pair
                once, and the remote is ready every time you pick up your phone.
              </p>
              <Availability />
              <p className="hero-more">
                <a href="#try">Try the controls in your browser</a>
              </p>
            </div>
            <div className="hero-phones">
              <AppScreen
                name="touchpad_dark"
                className="device-back"
                alt="The remote in dark mode with the touchpad."
                priority
              />
              <AppScreen
                name="dpad_dark"
                className="device-front"
                alt="The remote in dark mode, connected to Living Room TV, with the D-pad, volume and channel keys."
                priority
              />
            </div>
          </section>
        </main>
      </div>

      <div className="paper">
        <section className="section" id="how-it-works" aria-labelledby="steps-title">
          <h2 id="steps-title">Pair once. After that, it reconnects by itself.</h2>
          <ol className="steps">
            {STEPS.map((step, index) => (
              <li key={step.title} className="step">
                <AppScreen name={step.screen} alt={step.alt} className="step-screen" />
                <span className="step-number" aria-hidden="true">
                  {index + 1}
                </span>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </li>
            ))}
          </ol>
        </section>

        <section className="section status-section" aria-labelledby="status-title">
          <div>
            <h2 id="status-title">You can always see whether the TV is listening.</h2>
            <p className="section-lead">
              The status at the top of the remote shows the live connection, so you know where
              your taps go. If the connection drops, the app says so and offers to reconnect.
            </p>
          </div>
          <ul className="status-list" aria-label="The three connection states">
            {STATUSES.map(({ state, label }) => (
              <li key={state} className="status-row">
                <span className="status-lamp" data-state={state} aria-hidden="true" />
                {label}
              </li>
            ))}
          </ul>
        </section>

        <section className="section" aria-labelledby="tour-title">
          <h2 id="tour-title">Here&rsquo;s the app, as it looks on your phone.</h2>
          <ul className="tour" tabIndex={0} aria-label="Screens from the app">
            {TOUR.map(({ screen, caption, alt }) => (
              <li key={screen}>
                <figure>
                  <AppScreen name={screen} alt={alt} />
                  <figcaption>{caption}</figcaption>
                </figure>
              </li>
            ))}
          </ul>
        </section>

        <section className="section" aria-labelledby="controls-title">
          <h2 id="controls-title">The keys you reach for, plus a real keyboard.</h2>
          <ul className="controls">
            {CONTROLS.map(({ icon, title, body }) => (
              <li key={title} className="control">
                <span className="control-key">
                  <Icon name={icon} />
                </span>
                <div>
                  <h3>{title}</h3>
                  <p>{body}</p>
                </div>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="hero try" id="try" aria-labelledby="try-title">
        <div className="hero-inner">
          <div className="hero-copy">
            <h2 id="try-title">Try the controls here.</h2>
            <p className="hero-lead">
              A simplified remote drives a simulated TV, so you can get a feel for the D-pad, the
              touchpad and the keyboard before you install the app.
            </p>
          </div>
          <RemoteDemo />
        </div>
      </section>

      <section className="privacy-band" aria-labelledby="privacy-title">
        <div className="privacy-band-inner">
          <h2 id="privacy-title">No account. No sign-in. Your TVs stay on your phone.</h2>
          <div>
            <p>
              The app talks to your TV directly over your home network. Your TVs&rsquo; names,
              network addresses and MAC addresses never leave your phone, and backups don&rsquo;t
              copy them.
            </p>
            <p>
              You decide whether the app shares usage statistics and crash reports, and you can
              change that at any time.
            </p>
            <Link href="/privacy">Read the privacy policy</Link>
          </div>
        </div>
      </section>

      <div className="paper">
        <section className="section" id="plans" aria-labelledby="plans-title">
          <h2 id="plans-title">Free to use. Premium removes the ads.</h2>
          <div className="plans">
            <div className="plan">
              <h3>Free</h3>
              <ul>
                <li>Every TV and every remote control</li>
                <li>App shortcuts and the keyboard</li>
                <li>Turning your TV on, on Android</li>
                <li>Light and dark themes</li>
              </ul>
              <p className="plan-note">
                Shows banner ads at the bottom of the Apps and Settings screens, never on the
                remote. We may also switch on an occasional full-screen ad when you leave
                Settings, never while you pair a TV.
              </p>
            </div>
            <div className="plan">
              <h3>Premium</h3>
              <ul>
                <li>Everything in Free, with no ads</li>
                <li>Three colour styles: Ocean, Ember and Midnight, in light and dark</li>
              </ul>
              <p className="plan-note">
                Choose monthly, yearly or a one-time lifetime purchase. The app shows the price
                before you buy.
              </p>
            </div>
          </div>
        </section>

        <section className="section needs" aria-labelledby="needs-title">
          <div>
            <h2 id="needs-title">What you need</h2>
            <ul className="needs-list">
              <li>A TV or streaming box with Android TV or Google TV</li>
              <li>The Android TV Remote Service installed and up to date on it</li>
              <li>Your phone and your TV on the same Wi-Fi network</li>
            </ul>
            <p className="section-lead">
              TVs with other systems aren&rsquo;t supported. <Link href="/support">See which TVs work</Link>
            </p>
          </div>
          <div className="needs-cta">
            <Availability />
          </div>
        </section>
      </div>

      <SiteFooter />
    </>
  );
}
