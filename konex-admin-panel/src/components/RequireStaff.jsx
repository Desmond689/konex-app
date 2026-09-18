import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "../lib/AuthContext";

export default function RequireStaff({ children }) {
  const { session, loading, isStaff } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="center-page">
        <div className="spinner" />
      </div>
    );
  }

  if (!session) {
    return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  }

  if (!isStaff) {
    return (
      <div className="center-page">
        <div className="gate-message">
          <p style={{ fontFamily: "var(--font-display)", fontSize: 18, color: "var(--text)" }}>
            Staff only
          </p>
          <p>
            This account isn't a moderator, admin, or super_admin. Set{" "}
            <code className="mono">profiles.app_role</code> for this user in Supabase to get access.
          </p>
        </div>
      </div>
    );
  }

  return children;
}
