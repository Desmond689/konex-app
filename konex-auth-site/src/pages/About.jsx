import { Link } from 'react-router-dom'
import Logo from '../components/Logo'
import ConstellationField from '../components/ConstellationField'

const APP_STORE_URL = 'https://apps.apple.com/app/konex'
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.konex.app'
const ANDROID_BUILD_URL = 'https://github.com/Desmond689/konex-app/actions/runs/33708949560/artifacts/9876457239'

const features = [
  ['01', 'Discover gamers', 'Find people who play the games you love and connect with players from different communities.'],
  ['02', 'Find your squad', 'Connect with teammates and build a squad that feels like yours.'],
  ['03', 'Join communities', 'Discover communities built around games, interests, and the things players care about.'],
  ['04', 'Share your moments', 'Post your gaming experiences, achievements, thoughts, and memorable moments.'],
  ['05', 'Share stories', 'Keep your profile personal with moments that disappear after a short time.'],
  ['06', 'Stay connected', 'Have conversations and build real connections within the community.'],
]

export default function About() {
  return (
    <div className="callback-screen public-about">
      <ConstellationField />
      <div className="wrap">
        <nav className="nav">
          <Link className="brand" to="/"><Logo /><span className="brand-word">KONEX</span></Link>
          <div className="nav-links">
            <Link to="/">Home</Link>
            <a href="#what-you-can-do">What you can do</a>
            <a href={ANDROID_BUILD_URL} className="btn btn-primary" download>Download app</a>
          </div>
        </nav>
      </div>

      <main className="wrap about-content">
        <section className="about-hero">
          <div className="eyebrow">ABOUT KONEX</div>
          <h1>Where gamers <span className="accent">connect.</span></h1>
          <p>Konex is a social platform built for gamers - a place to connect with other players, discover communities, share your gaming moments, find teammates, and build your identity beyond the game.</p>
        </section>

        <section className="about-section">
          <div className="section-label">WHY WE BUILT KONEX</div>
          <h2>Gaming has always been about more than just playing.</h2>
          <p>It is about the people you meet, the teams you build, the communities you join, and the moments you remember. Konex was built to bring those experiences together and make gaming social.</p>
        </section>

        <section className="about-section" id="what-you-can-do">
          <div className="section-label">WHAT YOU CAN DO</div>
          <h2>Your gaming world, together.</h2>
          <div className="about-features">
            {features.map(([number, title, text]) => (
              <article key={title}><span>{number}</span><h3>{title}</h3><p>{text}</p></article>
            ))}
          </div>
        </section>

        <section className="about-vision">
          <div className="eyebrow">OUR VISION</div>
          <h2>Gaming is better when people experience it <span className="accent">together.</span></h2>
          <p>We are building a global social platform where gamers can connect, communicate, create, discover, and belong.</p>
        </section>

        <section className="about-founder about-section">
          <div className="section-label">BUILT BY A GAMER, BUILT FOR GAMERS</div>
          <h2>Tenkou Desmond</h2>
          <p className="founder-role">Founder and Developer of Konex</p>
          <p>Konex was created with the goal of building a modern social experience designed around the gaming community. The journey is just beginning.</p>
        </section>

        <section className="about-download">
          <h2>Join the gaming community.</h2>
          <p>Your squad is waiting.</p>
          <div className="hero-ctas">
            <a href={APP_STORE_URL} className="btn btn-primary">Download for iOS</a>
            <a href={ANDROID_BUILD_URL} className="btn btn-ghost" download>Download for Android</a>
          </div>
        </section>
      </main>

      <div className="wrap"><footer className="footer"><span>© {new Date().getFullYear()} Konex</span><Link to="/">Back home</Link></footer></div>
    </div>
  )
}
