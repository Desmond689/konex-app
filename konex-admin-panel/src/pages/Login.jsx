import { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import Logo from "../components/Logo";
import { useAuth } from "../lib/AuthContext";

export default function Login() {
  const { signIn } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const submit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const { error } = await signIn(email.trim(), password);
    setLoading(false);
    if (error) {
      setError(error.message || "Sign in failed.");
      return;
    }
    navigate(location.state?.from || "/", { replace: true });
  };

  return (
    <div className="login-wrap">
      <div className="login-card">
        <div className="login-mark">
          <Logo size={30} />
        </div>
        <div className="login-brand">KONEX</div>
        <div className="login-brand-sub">ADMIN CONSOLE</div>

        <div className="login-heading">Sign in</div>
        <p className="login-body">
          Sign in with your Konex account. Access is limited to moderator, admin, and
          super_admin roles.
        </p>

        <form onSubmit={submit}>
          <div className="field">
            <label className="field-label">Email</label>
            <input
              className="input"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="field">
            <label className="field-label">Password</label>
            <input
              className="input"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          {error && <div className="error-banner">{error}</div>}
          <button className="btn btn-primary" style={{ width: "100%" }} disabled={loading}>
            {loading ? "Signing in…" : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}
