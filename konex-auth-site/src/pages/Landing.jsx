import Logo from '../components/Logo'
import ConstellationField from '../components/ConstellationField'
import { Link } from 'react-router-dom'

const APP_STORE_URL = 'https://apps.apple.com/app/konex'
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.konex.app'
const ANDROID_BUILD_URL = 'https://github.com/Desmond689/konex-app/actions/runs/33708949560/artifacts/9876457239'

export default function Landing() {
  return (
    <div className="callback-screen">
      <ConstellationField />
      <div className="wrap">
        <nav className="nav">
          <a className="brand" href="/">
            <Logo />
            <span className="brand-word">KONEX</span>
          </a>
          <div className="nav-links">
            <a href="#get-started">Get started</a>
            <Link to="/about">About Konex</Link>
            <a href={ANDROID_BUILD_URL} className="btn btn-ghost" download>Download app</a>
          </div>
        </nav>

        <section className="hero">
          <div>
            <div className="eyebrow">Now in open beta</div>
            <h1>
              Your squad is <span className="accent">already here.</span>
            </h1>
            <p>
              Konex is the social layer for gamers — find your crew, track what
              everyone's playing, and jump into a call the second someone's online.
              No more scattered group chats.
            </p>
            <div className="hero-ctas">
              <a href={APP_STORE_URL} className="btn btn-primary">Download for iOS</a>
              <a href={ANDROID_BUILD_URL} className="btn btn-ghost" download>Download for Android</a>
            </div>
          </div>
          <div className="hero-visual">
            <HeroMark />
          </div>
        </section>
      </div>

      <div className="wrap">
        <section className="home-intro">
          <div>
            <div className="eyebrow">MORE THAN A GAME</div>
            <h2>One place for your whole gaming life.</h2>
          </div>
          <p>Discover communities, share your best moments, and stay close to the people you play with. Konex brings your gaming world together.</p>
        </section>
      </div>

      <div className="wrap">
        <section className="android-install" id="android-install">
          <div className="eyebrow">ANDROID INSTALLATION</div>
          <h2>Install Konex from your downloaded file</h2>
          <p>The Android build downloads as a ZIP archive. Follow these steps to install it safely:</p>
          <ol>
            <li>Tap <strong>Download for Android</strong> above and wait for the download to finish.</li>
            <li>Open your phone's <strong>Files</strong> app, open Downloads, and extract the ZIP file.</li>
            <li>Tap the extracted <strong>.apk</strong> file, then allow your browser or Files app to install unknown apps if Android asks.</li>
            <li>Tap <strong>Install</strong>, wait for it to finish, then open Konex and sign in.</li>
          </ol>
          <p className="install-note">Only install APK files downloaded from the official Konex GitHub link above. If Android shows a warning, confirm that the file came from this official page.</p>
        </section>
      </div>

      <div className="wrap">
        <section className="sequence" id="get-started">
          <div className="sequence-head">
            <h2>Get connected</h2>
            <span>3 STEPS</span>
          </div>
          <div className="steps">
            <div className="step">
              <div className="step-index">01</div>
              <h3>Download the app</h3>
              <p>Grab Konex from the App Store or Google Play and create your account with an email and username.</p>
            </div>
            <div className="step">
              <div className="step-index">02</div>
              <h3>Verify your email</h3>
              <p>We'll send a confirmation link — tap it, and you'll land right back here with your account unlocked.</p>
            </div>
            <div className="step">
              <div className="step-index">03</div>
              <h3>Squad up</h3>
              <p>Open Konex, add your games, and start linking up with friends who are online right now.</p>
            </div>
          </div>
        </section>
      </div>

      <div className="wrap">
        <footer className="footer">
          <span>© {new Date().getFullYear()} Konex</span>
          <Link to="/privacy">Privacy Policy</Link>
          <a href="mailto:support@konex-app-rho.vercel.app">support@konex-app-rho.vercel.app</a>
        </footer>
      </div>
    </div>
  )
}

function HeroMark() {
  return (
    <svg viewBox="0 0 200 200" width="100%" style={{ maxWidth: 320 }} aria-hidden="true">
      <g stroke="#8c6bff" strokeWidth="1.4" opacity="0.5">
        <line x1="70" y1="40" x2="70" y2="160" />
        <line x1="70" y1="100" x2="150" y2="40" />
        <line x1="70" y1="100" x2="150" y2="160" />
      </g>
      <circle cx="70" cy="40" r="8" fill="#8c6bff" />
      <circle cx="70" cy="100" r="10" fill="#ff6a4d" />
      <circle cx="70" cy="160" r="8" fill="#8c6bff" />
      <circle cx="150" cy="40" r="8" fill="#8c6bff" opacity="0.85" />
      <circle cx="150" cy="160" r="8" fill="#8c6bff" opacity="0.85" />
      <circle cx="70" cy="100" r="20" fill="none" stroke="#ff6a4d" strokeWidth="1" opacity="0.4">
        <animate attributeName="r" values="14;30;14" dur="4s" repeatCount="indefinite" />
        <animate attributeName="opacity" values="0.5;0;0.5" dur="4s" repeatCount="indefinite" />
      </circle>
    </svg>
  )
}
