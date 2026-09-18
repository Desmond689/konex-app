import { useState } from "react";
import { useAuditLog } from "../lib/hooks";

const PAGE_SIZE = 40;

export default function Audit() {
  const [page, setPage] = useState(1);
  const { logs, loading, error } = useAuditLog(page * PAGE_SIZE);
  const [actionFilter, setActionFilter] = useState("all");

  const actions = Array.from(new Set(logs.map((l) => l.action))).sort();
  const visible = actionFilter === "all" ? logs : logs.filter((l) => l.action === actionFilter);
  const pageLogs = visible.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Audit log</h1>
          <p className="page-subtitle">Every staff action, most recent first.</p>
        </div>
        <select className="input" style={{ width: 200 }} value={actionFilter} onChange={(e) => setActionFilter(e.target.value)}>
          <option value="all">All actions</option>
          {actions.map((a) => (
            <option key={a} value={a}>
              {a}
            </option>
          ))}
        </select>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="panel">
        {loading ? (
          <div className="state-block">
            <div className="spinner" />
          </div>
        ) : pageLogs.length === 0 ? (
          <div className="state-block">
            <div className="state-block-title">No entries</div>
            <div className="state-block-sub">Nothing matches this filter yet.</div>
          </div>
        ) : (
          pageLogs.map((l) => (
            <div className="row" key={l.id}>
              <div className="row-main">
                <div className="row-title">
                  <span className="pill pill-role-admin">{l.action}</span>
                  {l.target_type && <span className="muted">on {l.target_type}</span>}
                </div>
                <div className="row-sub mono">
                  actor {l.actor_id?.slice(0, 8) || "—"} · target {l.target_id?.slice(0, 8) || "—"} ·{" "}
                  {new Date(l.created_at).toLocaleString()}
                </div>
                {l.reason && <div className="row-sub">{l.reason}</div>}
              </div>
            </div>
          ))
        )}
      </div>

      <div className="pagination">
        <button className="btn btn-ghost btn-sm" disabled={page === 1} onClick={() => setPage((p) => p - 1)}>
          ← Previous
        </button>
        <span>Page {page}</span>
        <button
          className="btn btn-ghost btn-sm"
          disabled={visible.length < page * PAGE_SIZE}
          onClick={() => setPage((p) => p + 1)}
        >
          Next →
        </button>
      </div>
    </>
  );
}
