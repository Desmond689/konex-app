import { Link } from "react-router-dom";
import { useAdminStats } from "../lib/hooks";

export default function Dashboard() {
  const { stats, loading, error } = useAdminStats();

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Dashboard</h1>
          <p className="page-subtitle">An overview of what's happening across Konex right now.</p>
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="stat-grid">
        <StatCard label="Total users" value={stats?.totalUsers} loading={loading} />
        <StatCard
          label="Open reports"
          value={stats?.openReports}
          loading={loading}
          accent={stats?.openReports > 0 ? "coral" : undefined}
        />
        <StatCard label="Posts" value={stats?.totalPosts} loading={loading} />
        <StatCard label="Squads" value={stats?.totalSquads} loading={loading} />
      </div>

      <div className="stat-grid" style={{ marginTop: 12 }}>
        <StatCard label="Reports today" value={stats?.reportsToday} loading={loading} />
        <StatCard label="Resolved today" value={stats?.resolvedToday} loading={loading} />
        <StatCard label="New users today" value={stats?.newUsersToday} loading={loading} />
        <StatCard label="Posts today" value={stats?.postsToday} loading={loading} />
        <StatCard
          label="Banned users"
          value={stats?.bannedUsers}
          loading={loading}
          accent={stats?.bannedUsers > 0 ? "coral" : undefined}
        />
      </div>

      <div className="panel">
        <div className="panel-header">
          <h2>Quick actions</h2>
        </div>
        <QuickLink to="/games/new" title="Create game" subtitle="Game = Community in one step" />
        <QuickLink to="/games" title="Manage games" subtitle="Search, edit, and add logos to any game" />
        <QuickLink to="/reports" title="Report queue" subtitle="Review and action reports" />
        <QuickLink to="/users" title="User management" subtitle="Search, ban, roles, history" />
        <QuickLink to="/audit" title="Audit log" subtitle="Every staff action, in order" />
      </div>
    </>
  );
}

function StatCard({ label, value, loading, accent }) {
  return (
    <div className={`stat-card ${accent ? `accent-${accent}` : ""}`}>
      <div className="stat-card-value">{loading ? "—" : value ?? 0}</div>
      <div className="stat-card-label">{label}</div>
    </div>
  );
}

function QuickLink({ to, title, subtitle }) {
  return (
    <Link to={to} className="row" style={{ textDecoration: "none", color: "inherit" }}>
      <div className="row-main">
        <div className="row-title">{title}</div>
        <div className="row-sub">{subtitle}</div>
      </div>
      <span className="muted">→</span>
    </Link>
  );
}
