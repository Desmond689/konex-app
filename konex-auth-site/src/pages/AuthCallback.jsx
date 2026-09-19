import { useEffect, useRef, useState } from 'react'
import Logo from '../components/Logo'
import ConstellationField from '../components/ConstellationField'
import { supabase } from '../supabaseClient'

// Where the mobile app can be deep-linked back into once the web confirmation
// has finished (adjust to match your app's actual URL scheme / associated domain).
const APP_DEEP_LINK = 'konex://auth/callback'
const APP_STORE_URL = 'https://apps.apple.com/app/konex'
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.konex.app'

export default function AuthCallback() {
  // 'ready' | 'verifying' | 'success' | 'error'
  //
  // IMPORTANT: verification is NOT triggered automatically on page load.
  // Corporate mail gateways (Outlook Safe Links, etc.) and some webmail
  // providers auto-visit links inside emails to scan them for phishing,
  // *before* a human ever opens the message. Supabase's confirmation token
  // is single-use, so if this page fired verifyOtp() the instant it loaded,
  // a scanner bot could burn the token before the real user clicks it —
  // and every single user would see "link expired" even though nothing on
  // their end went wrong. Requiring a real click first is the standard fix.
  const [status, setStatus] = useState('ready')
  const [message, setMessage] = useState('')
  const settled = useRef(false)

  const url = new URL(window.location.href)
  const search = url.searchParams
  // Supabase sometimes returns implicit-flow params after a `#` instead of `?`
  const hashParams = new URLSearchParams(url.hash.replace(/^#/, ''))

  const errorDescription =
    search.get('error_description') || hashParams.get('error_description') || search.get('error')
  const tokenHash = search.get('token_hash')
  const type = search.get('type')
  const code = search.get('code')
  const implicitAccessToken = hashParams.get('access_token')

  useEffect(() => {
    if (errorDescription) {
      finish('error', decodeURIComponent(errorDescription.replace(/\+/g, ' ')))
    } else if (!tokenHash && !code && !implicitAccessToken) {
      finish('error', 'This confirmation link is missing or incomplete.')
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function confirmEmail() {
    if (settled.current) return
    setStatus('verifying')
    let timeout = setTimeout(() => {
      finish('error', 'That took too long. Please try again or request a new link.')
    }, 8000)

    try {
      if (tokenHash && type) {
        // Newer Supabase email-link flow: /auth/callback?token_hash=...&type=signup
        const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type })
        if (error) throw error
        finish('success')
      } else if (code) {
        // PKCE flow: /auth/callback?code=...
        const { error } = await supabase.auth.exchangeCodeForSession(code)
        if (error) throw error
        finish('success')
      } else if (implicitAccessToken) {
        // Implicit flow: supabase-js's detectSessionInUrl already parsed this on load.
        const { data, error } = await supabase.auth.getSession()
        if (error) throw error
        if (data.session) {
          finish('success')
        } else {
          finish('error', 'That link is invalid or has expired.')
        }
      } else {
        finish('error', 'This confirmation link is missing or incomplete.')
      }
    } catch (err) {
      finish('error', err?.message || 'That link is invalid or has expired.')
    } finally {
      clearTimeout(timeout)
    }
  }

  function finish(nextStatus, err) {
    if (settled.current) return
    settled.current = true
    setStatus(nextStatus)
    setMessage(nextStatus === 'error' ? err : '')
  }

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
          {status === 'ready' && <ReadyCard onConfirm={confirmEmail} />}
          {status === 'verifying' && <PendingCard />}
          {status === 'success' && <SuccessCard />}
          {status === 'error' && <ErrorCard message={message} />}
        </div>
      </div>
    </div>
  )
}

function ReadyCard({ onConfirm }) {
  return (
    <>
      <div className="status-mark">
        <SpinnerMark idle />
      </div>
      <span className="status-tag pending">One step left</span>
      <h1>Confirm your email</h1>
      <p className="desc">Tap the button below to finish verifying your Konex account.</p>
      <div className="card-ctas">
        <button className="btn btn-primary" onClick={onConfirm}>Confirm my email</button>
      </div>
    </>
  )
}

function PendingCard() {
  return (
    <>
      <div className="status-mark">
        <SpinnerMark />
      </div>
      <span className="status-tag pending">Verifying</span>
      <h1>Confirming your email…</h1>
      <p className="desc">Give it a second — this usually takes less than a moment.</p>
    </>
  )
}

function SuccessCard() {
  return (
    <>
      <div className="status-mark">
        <CheckMark />
      </div>
      <span className="status-tag ok">Verified</span>
      <h1>Email verified successfully</h1>
      <p className="desc">
        Your Konex account is confirmed. Open the app to finish signing in — if you
        already have it installed, we'll try to jump you straight there.
      </p>
      <div className="card-ctas">
        <a className="btn btn-primary" href={APP_DEEP_LINK}>Open Konex</a>
        <a className="btn btn-ghost" href={APP_STORE_URL}>Get it on the App Store</a>
        <a className="btn btn-ghost" href={PLAY_STORE_URL}>Get it on Google Play</a>
      </div>
      <div className="deep-link">{APP_DEEP_LINK}</div>
    </>
  )
}

function ErrorCard({ message }) {
  return (
    <>
      <div className="status-mark">
        <ErrorMark />
      </div>
      <span className="status-tag err">Link issue</span>
      <h1>Couldn't verify that link</h1>
      <p className="desc">{message || 'That confirmation link is invalid or has expired.'}</p>
      <div className="card-ctas">
        <a className="btn btn-primary" href={APP_STORE_URL}>Open Konex to resend</a>
        <a className="btn btn-ghost" href="mailto:support@konex-app-rho.vercel.app">Contact support</a>
      </div>
    </>
  )
}

function SpinnerMark({ idle = false }) {
  return (
    <svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true">
      <circle cx="24" cy="24" r="19" stroke="#26263c" strokeWidth="3" fill="none" />
      <circle cx="24" cy="24" r="19" stroke="#8c6bff" strokeWidth="3" fill="none" strokeLinecap="round" strokeDasharray={idle ? '90 30' : '30 90'}>
        {!idle && (
          <animateTransform attributeName="transform" type="rotate" from="0 24 24" to="360 24 24" dur="0.9s" repeatCount="indefinite" />
        )}
      </circle>
    </svg>
  )
}

function CheckMark() {
  return (
    <svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true">
      <circle cx="24" cy="24" r="19" fill="rgba(77,255,180,0.1)" stroke="#4dffb4" strokeWidth="2" />
      <path d="M15 24.5 L21 30.5 L33 17.5" fill="none" stroke="#4dffb4" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

function ErrorMark() {
  return (
    <svg width="48" height="48" viewBox="0 0 48 48" aria-hidden="true">
      <circle cx="24" cy="24" r="19" fill="rgba(255,106,106,0.1)" stroke="#ff6a6a" strokeWidth="2" />
      <path d="M17 17 L31 31 M31 17 L17 31" stroke="#ff6a6a" strokeWidth="3" strokeLinecap="round" />
    </svg>
  )
}
