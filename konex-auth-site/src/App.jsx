import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Landing from './pages/Landing'
import About from './pages/About'
import Privacy from './pages/Privacy'
import AuthCallback from './pages/AuthCallback'
import DeepLink from './pages/DeepLink'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route path="/about" element={<About />} />
        <Route path="/privacy" element={<Privacy />} />
        {/* Point your Supabase project's "Site URL" / redirect URL at this route,
            e.g. https://konex-app-rho.vercel.app/auth/callback */}
        <Route path="/auth/callback" element={<AuthCallback />} />
        {/* Catch-all: any other link (invite/profile/post/party/... shared from
            the app) lands here and gets handed off to the app, or the store
            if it isn't installed. See src/utils/linkTypes.js to add new kinds. */}
        <Route path="*" element={<DeepLink />} />
      </Routes>
    </BrowserRouter>
  )
}
