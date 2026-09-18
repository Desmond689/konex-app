<<<<<<< HEAD
import { useEffect, useState } from "react";
import { NavLink, Outlet } from "react-router-dom";
import Logo from "./Logo";
import CommandPalette from "./CommandPalette";
import { useAuth, can } from "../lib/AuthContext";
import { useLiveOpenReports } from "../lib/hooks";
import { useToast } from "./Toast";
=======
import { useState } from "react";
import { NavLink, Outlet } from "react-router-dom";
import Logo from "./Logo";
import { useAuth, can } from "../lib/AuthContext";
import { useOpenReportCount } from "../lib/hooks";
>>>>>>> origin/main

const NAV = [
  { to: "/", label: "Dashboard", icon: DashboardIcon, end: true },
  { to: "/reports", label: "Report queue", icon: FlagIcon, countKey: "reports" },
<<<<<<< HEAD
  { to: "/appeals", label: "Appeals", icon: AppealIcon },
  { to: "/analytics", label: "Analytics", icon: AnalyticsIcon },
=======
>>>>>>> origin/main
  { to: "/users", label: "Users", icon: UsersIcon },
  { to: "/staff", label: "Staff", icon: StaffIcon, staffOnly: true },
  { to: "/squads", label: "Squads", icon: SquadsIcon },
  { to: "/games", label: "Games", icon: GamesIcon },
  { to: "/audit", label: "Audit log", icon: HistoryIcon },
<<<<<<< HEAD
  { to: "/settings", label: "Settings", icon: SettingsIcon },
];

function useTheme() {
  const [theme, setTheme] = useState(() => localStorage.getItem("konex-theme") || "dark");
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem("konex-theme", theme);
  }, [theme]);
  return [theme, setTheme];
}

export default function Layout() {
  const { session, role, signOut } = useAuth();
  const [mobileOpen, setMobileOpen] = useState(false);
  const { showToast, ToastEl } = useToast();
  const openReports = useLiveOpenReports((report) => {
    showToast(`New report filed on a ${report.target_type}`, "error");
  });
  const [theme, setTheme] = useTheme();
=======
];

export default function Layout() {
  const { session, role, signOut } = useAuth();
  const [mobileOpen, setMobileOpen] = useState(false);
  const openReports = useOpenReportCount();
>>>>>>> origin/main

  const visibleNav = NAV.filter((item) => {
    if (item.staffOnly) return can(role, "manage_staff");
    return true;
  });

  return (
    <div className="shell">
      <div className="mobile-topbar">
        <button onClick={() => setMobileOpen((o) => !o)} aria-label="Toggle menu">
          ☰
        </button>
        <Logo size={20} />
<<<<<<< HEAD
        <span style={{ fontFamily: "var(--font-display)", fontWeight: 700 }}>Konex Admin</span>
=======
        <span style={{ fontFamily: "var(--font-display)", fontWeight: 700 }}>Konex Staff</span>
>>>>>>> origin/main
      </div>

      <aside className={`sidebar ${mobileOpen ? "open" : ""}`}>
        <div className="sidebar-brand">
          <Logo />
          <div>
            <div className="sidebar-brand-text">KONEX</div>
<<<<<<< HEAD
            <div className="sidebar-brand-sub">ADMIN CONSOLE</div>
          </div>
        </div>

        <button
          className="btn btn-ghost btn-sm"
          style={{ margin: "0 16px 12px", textAlign: "left" }}
          onClick={() => window.dispatchEvent(new KeyboardEvent("keydown", { key: "k", metaKey: true }))}
        >
          🔍 Search… <span className="muted">⌘K</span>
        </button>

=======
            <div className="sidebar-brand-sub">STAFF CONSOLE</div>
          </div>
        </div>

>>>>>>> origin/main
        <nav className="nav-group">
          {visibleNav.map(({ to, label, icon: Icon, end, countKey }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) => `nav-link${isActive ? " active" : ""}`}
              onClick={() => setMobileOpen(false)}
            >
              <Icon />
              <span>{label}</span>
              {countKey === "reports" && openReports > 0 && (
                <span className="badge-count">{openReports}</span>
              )}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-footer">
<<<<<<< HEAD
          <button
            className="btn btn-ghost btn-sm"
            style={{ marginBottom: 8, width: "100%" }}
            onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
          >
            {theme === "dark" ? "☀ Light mode" : "☾ Dark mode"}
          </button>
=======
>>>>>>> origin/main
          <div className="sidebar-user">
            <span className="sidebar-user-email">{session?.user?.email}</span>
            <span className={`sidebar-user-role pill-role-${role}`}>{role}</span>
          </div>
          <button className="signout-btn" onClick={signOut}>
            Sign out
          </button>
        </div>
      </aside>

      <main className="main">
        <Outlet />
      </main>
<<<<<<< HEAD
      <CommandPalette />
      {ToastEl}
=======
>>>>>>> origin/main
    </div>
  );
}

function DashboardIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <rect x="3" y="3" width="7" height="9" rx="1.5" />
      <rect x="14" y="3" width="7" height="5" rx="1.5" />
      <rect x="14" y="12" width="7" height="9" rx="1.5" />
      <rect x="3" y="16" width="7" height="5" rx="1.5" />
    </svg>
  );
}
function FlagIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M4 21V4a1 1 0 0 1 1.4-.9c3 1.4 6.2 1.4 9.2 0a1 1 0 0 1 1.4.9v9a1 1 0 0 1-1.4.9c-3-1.4-6.2-1.4-9.2 0" />
    </svg>
  );
}
function UsersIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="9" cy="8" r="3.2" />
      <path d="M3 20c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5" />
      <circle cx="17.5" cy="8.8" r="2.4" />
      <path d="M21 20c0-2.6-1.7-4.5-4-5.1" />
    </svg>
  );
}
function StaffIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M12 3l2.2 4.5 5 .7-3.6 3.5.9 5-4.5-2.4L7.5 16.7l.9-5L4.8 8.2l5-.7L12 3z" />
    </svg>
  );
}
function SquadsIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="8" cy="9" r="3" />
      <circle cx="16" cy="9" r="3" />
      <path d="M3 20c0-2.8 2.2-5 5-5h0c1.1 0 2.1.4 2.9 1" />
      <path d="M13.1 16c.8-.6 1.8-1 2.9-1h0c2.8 0 5 2.2 5 5" />
    </svg>
  );
}
function GamesIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <rect x="2.5" y="7.5" width="19" height="10" rx="4" />
      <line x1="7" y1="12.5" x2="7" y2="12.51" />
      <line x1="6" y1="10.5" x2="6" y2="14.5" transform="rotate(90 6 12.5)" />
      <circle cx="16.5" cy="10.5" r="0.9" fill="currentColor" />
      <circle cx="18.5" cy="12.5" r="0.9" fill="currentColor" />
    </svg>
  );
}
function HistoryIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 7.5V12l3 2" />
    </svg>
  );
}
<<<<<<< HEAD
function AppealIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M12 3v4M5 8l3 3M19 8l-3 3" />
      <path d="M4 21h16M6 21V11h12v10" />
    </svg>
  );
}
function AnalyticsIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M4 20V10M11 20V4M18 20v-7" />
      <path d="M2 20h20" />
    </svg>
  );
}
function SettingsIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="12" cy="12" r="3.2" />
      <path d="M19.4 13a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6V19a2 2 0 1 1-4 0v-.2a1.7 1.7 0 0 0-1.1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.6-1H4a2 2 0 1 1 0-4h.2a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3H10a1.7 1.7 0 0 0 1-1.6V4a2 2 0 1 1 4 0v.2a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9V10a1.7 1.7 0 0 0 1.6 1H20a2 2 0 1 1 0 4h-.2a1.7 1.7 0 0 0-1.6 1z" />
    </svg>
  );
}
=======
>>>>>>> origin/main
