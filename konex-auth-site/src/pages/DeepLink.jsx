import { useEffect, useRef, useState } from 'react'
import { useLocation } from 'react-router-dom'
import Logo from '../components/Logo'
import ConstellationField from '../components/ConstellationField'
import { detectPlatform } from '../utils/platform'
import { getLinkType } from '../utils/linkTypes'

// Konex's custom URL scheme. The app must register this scheme (iOS: CFBundleURLSchemes
// in Info.plist, Android: an <intent-filter> with android:scheme="konex") so the OS
// knows to hand these links to the app instead of the browser.
const APP_SCHEME = 'konex'

const APP_STORE_URL = 'https://apps.apple.com/app/konex'
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.konex.app'

// How long we wait to see whether the OS switched away to the app before we
// assume it isn't installed and fall back to a store link / manual buttons.
const HANDOFF_TIMEOUT_MS = 1400

export default function DeepLink() {
  const location = useLocation()
  const [attempted, setAttempted] = useState(false)
  const [showFallback, setShowFallback] = useState(false)
  const leftPage = useRef(false)

  const platform = detectPlatform()
  const copy = getLinkType(location.pathname)
  const storeUrl = platform === 'ios' ? APP_STORE_URL : platform === 'android' ? PLAY_STORE_URL : null

  // e.g. /invite/abc123?ref=xyz  ->  konex://invite/abc123?ref=xyz
  const schemeUrl = `${APP_SCHEME}://${location.pathname.replace(/^\//, '')}${location.search}`

  useEffect(() => {
    function onVisibilityChange() {
      if (document.hidden) leftPage.current = true
    }
    document.addEventListener('visibilitychange', onVisibilityChange)

    // Attempt the handoff to the app right away.
    window.location.href = schemeUrl
    setAttempted(true)

    const timer = setTimeout(() => {
      if (leftPage.current) return // the app opened — nothing left to do

      if (storeUrl) {
        // Mobile and the app didn't open: most likely not installed.
        window.location.href = storeUrl
      } else {
        // Desktop or unknown platform: there's no app to hand off to, so just
        // show buttons instead of guessing.
        setShowFallback(true)
      }
    }, HANDOFF_TIMEOUT_MS)

    return () => {
      clearTimeout(timer)
      document.removeEventListener('visibilitychange', onVisibilityChange)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location.pathname, location.search])

  return (
    <div className="callback-screen">
      <ConstellationField />
      <div className="wrap">
        <nav className="nav">
          <a className="brand" href="/">
            <Logo />
            <span className="brand-word">KONEX</span>
          </a>
        </nav>
      </div>

      <div className="callback-center">
        <div className="card">
          <div className="status-mark">
            <SpinnerMark />
          </div>
          <span className="status-tag pending">{attempted ? 'Redirecting' : 'Preparing'}</span>
          <h1>{copy.title}</h1>
          <p className="desc">{copy.desc}</p>

          {!showFallback && (
            <p style={{ fontSize: 13, color: 'var(--text-faint)', margin: '0 0 4px' }}>
              Trying to open the Konex app…
            </p>
          )}

          {showFallback && (
            <div className="card-ctas">
              <a className="btn btn-primary" href={schemeUrl}>Open in Konex app</a>
              <a className="btn btn-ghost" href={APP_STORE_URL}>Get it on the App Store</a>
              <a className="btn btn-ghost" href={PLAY_STORE_URL}>Get it on Google Play</a>
            </div>
          )}

          <div className="deep-link">{schemeUrl}</div>
        </div>
      </div>
    </div>
  )
}

function SpinnerMark() {
  return (
    <svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true">
      <circle cx="24" cy="24" r="19" stroke="#26263c" strokeWidth="3" fill="none" />
      <circle cx="24" cy="24" r="19" stroke="#8c6bff" strokeWidth="3" fill="none" strokeLinecap="round" strokeDasharray="30 90">
        <animateTransform attributeName="transform" type="rotate" from="0 24 24" to="360 24 24" dur="0.9s" repeatCount="indefinite" />
      </circle>
    </svg>
  )
}
