import { useEffect, useState } from "react";
import { fetchAnalytics, fetchModeratorLeaderboard } from "../lib/hooks";

const RANGES = [7, 30, 90];

function Sparkbars({ series, color }) {
  const max = Math.max(1, ...series.map((s) => s.count));
  return (
    <div className="sparkbars">
      {series.map((s) => (
        <div
          key={s.date}
          className="sparkbar"
          title={`${s.date}: ${s.count}`}
          style={{
            height: `${Math.max(4, (s.count / max) * 100)}%`,
            background: color,
          }}
        />
      ))}
    </div>
  );
}

function StatCard({ label, series, color, total }) {
  return (
    <div className="panel" style={{ padding: 18, flex: 1, minWidth: 220 }}>
      <div className="row-sub" style={{ marginBottom: 4 }}>{label}</div>
      <div style={{ fontFamily: "var(--font-display)", fontSize: 28, fontWeight: 700, marginBottom: 12 }}>
        {total}
      </div>
      <Sparkbars series={series} color={color} />
    </div>
  );
}

export default function Analytics() {
  const [days, setDays] = useState(30);
  const [data, setData] = useState(null);
  const [leaderboard, setLeaderboard] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    Promise.all([fetchAnalytics(days), fetchModeratorLeaderboard(days)])
      .then(([a, lb]) => {
        if (cancelled) return;
        setData(a);
        setLeaderboard(lb);
      })
      .catch((e) => !cancelled && setError(e.message || "Failed to load analytics"))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [days]);

  const sum = (series) => series?.reduce((a, s) => a + s.count, 0) ?? 0;

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Analytics</h1>
          <p className="page-subtitle">Trends over time, not just today&apos;s snapshot.</p>
        </div>
        <div className="tab-row">
          {RANGES.map((r) => (
            <button
              key={r}
              className={`btn btn-sm ${days === r ? "btn-primary" : "btn-ghost"}`}
              onClick={() => setDays(r)}
            >
              {r}d
            </button>
          ))}
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      {loading || !data ? (
        <div className="state-block">
          <div className="spinner" />
        </div>
      ) : (
        <>
          <div style={{ display: "flex", gap: 14, flexWrap: "wrap", marginBottom: 20 }}>
            <StatCard label="New signups" series={data.signups} color="var(--violet)" total={sum(data.signups)} />
            <StatCard label="Reports filed" series={data.reports} color="var(--coral)" total={sum(data.reports)} />
            <StatCard label="Reports resolved" series={data.resolved} color="var(--success)" total={sum(data.resolved)} />
            <StatCard label="Posts created" series={data.posts} color="var(--warning)" total={sum(data.posts)} />
          </div>

          <div className="section-label">Moderator activity ({days}d)</div>
          <div className="panel">
            {leaderboard.length === 0 ? (
              <div className="state-block">
                <div className="state-block-title">No staff actions yet</div>
                <div className="state-block-sub">Nothing logged in this window.</div>
              </div>
            ) : (
              leaderboard.map((m, i) => (
                <div className="row" key={m.username + i}>
                  <div className="row-main">
                    <div className="row-title">
                      #{i + 1} @{m.username}
                    </div>
                    <div className="row-sub">{m.count} logged action{m.count === 1 ? "" : "s"}</div>
                  </div>
                </div>
              ))
            )}
          </div>
        </>
      )}
    </>
  );
}
