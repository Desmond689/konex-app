import { Link } from 'react-router-dom'
import Logo from '../components/Logo'
import ConstellationField from '../components/ConstellationField'

const LAST_UPDATED = 'September 17, 2026'
const CONTACT_EMAIL = 'support@konex.app'

const collection = [
  ['Account info', 'Email, username, date of birth', 'Create and secure your account, enforce minimum age'],
  ['Profile info', 'Display name, bio, avatar/banner photo, games you play, player type', 'Build your public profile and personalize your feed'],
  ['Content you create', 'Posts, comments, stories, squad/community posts, messages', 'Deliver the core social features of the app'],
  ['Media you upload', 'Photos and videos attached to posts, stories, avatars, comments', 'Display your content to you and others per your privacy settings'],
  ['Communications', 'Direct messages, squad/community chat messages', 'Enable chat and voice call functionality'],
  ['Social graph', 'Follows, blocks, squad/community memberships', 'Power your feed, notifications, and safety controls'],
  ['Device & usage', 'Push notification token, app version, general diagnostics', 'Deliver notifications and keep the app stable'],
  ['Approximate region', 'Country/region you select', 'Show relevant regional content (e.g. LFG posts)'],
]

export default function Privacy() {
  return (
    <div className="callback-screen public-about">
      <ConstellationField />
      <div className="wrap">
        <nav className="nav">
          <Link className="brand" to="/"><Logo /><span className="brand-word">KONEX</span></Link>
          <div className="nav-links">
            <Link to="/">Home</Link>
            <Link to="/about">About</Link>
          </div>
        </nav>
      </div>

      <main className="wrap about-content legal-content">
        <section className="about-hero">
          <div className="eyebrow">LEGAL</div>
          <h1>Privacy <span className="accent">Policy.</span></h1>
          <p className="legal-updated">Last updated: {LAST_UPDATED}</p>
          <p>KONEX ("we", "our", "the app") is a social platform for gamers to connect, post, chat, join squads, and find communities around the games they play. This policy explains what information we collect, why, and how you can control it.</p>
        </section>

        <section className="about-section">
          <div className="section-label">01</div>
          <h2>Information we collect</h2>
          <div className="legal-table-wrap">
            <table className="legal-table">
              <thead>
                <tr><th>Category</th><th>Examples</th><th>Why we collect it</th></tr>
              </thead>
              <tbody>
                {collection.map(([category, examples, why]) => (
                  <tr key={category}>
                    <td>{category}</td>
                    <td>{examples}</td>
                    <td>{why}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p>We do <strong>not</strong> collect precise GPS location, and we do <strong>not</strong> collect payment or financial information — KONEX tournaments and features are free, with no in-app purchases requiring payment data.</p>
        </section>

        <section className="about-section">
          <div className="section-label">02</div>
          <h2>How we use your information</h2>
          <ul className="legal-list">
            <li>To operate core features: feed, posts, comments, likes, follows, squads, communities, direct and group messaging, voice calls, and stories.</li>
            <li>To send notifications (e.g. new followers, comments, messages, squad activity) — you can turn these off per-category in Settings.</li>
            <li>To enforce our community guidelines, including blocking, reporting, and moderation.</li>
            <li>To keep the app secure and prevent abuse (e.g. rate-limiting, spam prevention).</li>
          </ul>
        </section>

        <section className="about-section">
          <div className="section-label">03</div>
          <h2>Who we share information with</h2>
          <p>We do not sell your personal information. We share data only with:</p>
          <ul className="legal-list">
            <li><strong>Other users</strong>, according to your own privacy settings (e.g. public posts are visible to everyone; private profiles restrict visibility; blocked users cannot see your content).</li>
            <li><strong>Service providers</strong> who process data on our behalf strictly to run the app — currently Supabase (database, authentication, file storage, and real-time messaging infrastructure), Resend (delivery of account verification emails), and, where enabled, push notification delivery (Firebase Cloud Messaging).</li>
            <li><strong>Law enforcement</strong>, only if legally required.</li>
          </ul>
        </section>

        <section className="about-section">
          <div className="section-label">04</div>
          <h2>Your controls</h2>
          <ul className="legal-list">
            <li><strong>Edit or delete content</strong> you've posted at any time from within the app.</li>
            <li><strong>Control who can message you, follow you, or see your games/squad</strong> via Settings → Privacy.</li>
            <li><strong>Block or report</strong> any user directly from their profile or content.</li>
            <li><strong>Delete your account</strong> from Settings — this removes your public profile information and personal identifiers; some content may be retained in anonymized form to preserve the integrity of conversations/threads you participated in.</li>
            <li><strong>Manage notification permissions</strong> at the OS level (Android/iOS settings) or in-app.</li>
          </ul>
        </section>

        <section className="about-section">
          <div className="section-label">05</div>
          <h2>Data retention</h2>
          <p>We retain your information for as long as your account is active. Stories are automatically deleted 24 hours after posting (unless saved to a highlight). If you delete your account, we remove or anonymize your personal data within a reasonable period, except where retention is required for legal or safety purposes (e.g. active moderation reports).</p>
        </section>

        <section className="about-section">
          <div className="section-label">06</div>
          <h2>Children's privacy</h2>
          <p>KONEX is not directed at children under 13 (or the minimum age required in your country). We do not knowingly collect personal information from children below this age. If you believe a child has created an account, contact us using the details below and we will take appropriate action.</p>
        </section>

        <section className="about-section">
          <div className="section-label">07</div>
          <h2>Security</h2>
          <p>We use industry-standard practices to protect your data, including encrypted connections (HTTPS/TLS), access controls limiting who can read your data, and authentication safeguards. No system is 100% secure, but we work to keep your information protected.</p>
        </section>

        <section className="about-section">
          <div className="section-label">08</div>
          <h2>Changes to this policy</h2>
          <p>We may update this policy as KONEX evolves. We'll update the "Last updated" date above when changes are made, and significant changes will be communicated in-app.</p>
        </section>

        <section className="about-section">
          <div className="section-label">09</div>
          <h2>Contact us</h2>
          <p>Questions about this policy or your data? Contact us at:</p>
          <div className="legal-contact-box">
            <strong>Email:</strong> <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>
          </div>
        </section>
      </main>

      <div className="wrap"><footer className="footer"><span>© {new Date().getFullYear()} Konex</span><Link to="/">Back home</Link></footer></div>
    </div>
  )
}
