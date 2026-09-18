import { useCallback, useEffect, useState } from "react";
import ConfirmDialog from "../components/ConfirmDialog";
import { useToast } from "../components/Toast";
import { listAppeals, reviewAppeal } from "../lib/hooks";

const TABS = [
  { value: "open", label: "Open" },
  { value: "approved", label: "Approved" },
  { value: "denied", label: "Denied" },
  { value: "all", label: "All" },
];

function timeAgo(iso) {
  if (!iso) return "—";
  return new Date(iso).toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export default function Appeals() {
  const { showToast, ToastEl } = useToast();
  const [status, setStatus] = useState("open");
  const [appeals, setAppeals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [confirm, setConfirm] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setAppeals(await listAppeals(status));
    } catch (e) {
      setError(e.message || "Failed to load appeals");
    } finally {
      setLoading(false);
    }
  }, [status]);

  useEffect(() => {
    load();
  }, [load]);

  const decide = async (approve, reason) => {
    try {
      await reviewAppeal(confirm.id, approve, reason);
      showToast(approve ? "Appeal approved — restrictions lifted" : "Appeal denied", "success");
      setConfirm(null);
      load();
    } catch (e) {
      showToast(e.message || "Failed to review appeal", "error");
      throw e;
    }
  };

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Appeals</h1>
          <p className="page-subtitle">Users contesting a ban, suspension, or restriction.</p>
        </div>
      </div>

      <div className="tab-row" style={{ marginBottom: 16 }}>
        {TABS.map((t) => (
          <button
            key={t.value}
            className={`btn btn-sm ${status === t.value ? "btn-primary" : "btn-ghost"}`}
            onClick={() => setStatus(t.value)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="panel">
        {loading ? (
          <div className="state-block">
            <div className="spinner" />
          </div>
        ) : appeals.length === 0 ? (
          <div className="state-block">
            <div className="state-block-title">No {status !== "all" ? status : ""} appeals</div>
            <div className="state-block-sub">Nothing to review right now.</div>
          </div>
        ) : (
          appeals.map((a) => (
            <div className="row" key={a.id} style={{ alignItems: "flex-start" }}>
              <div className="row-main">
                <div className="row-title">
                  @{a.username}
                  <span className={`pill pill-role-${a.status === "approved" ? "user" : a.status === "denied" ? "banned" : "admin"}`}>
                    {a.status}
                  </span>
                </div>
                <div className="row-sub" style={{ marginBottom: 6 }}>
                  {a.gamer_name || "—"} · filed {timeAgo(a.created_at)}
                </div>
                <div className="row-sub" style={{ whiteSpace: "pre-wrap" }}>{a.message}</div>
                {a.review_reason && (
                  <div className="row-sub" style={{ marginTop: 6 }}>
                    Staff response: {a.review_reason}
                  </div>
                )}
              </div>
              {a.status === "open" && (
                <div className="row-actions" style={{ flexDirection: "column", gap: 6 }}>
                  <button className="btn btn-primary btn-sm" onClick={() => setConfirm({ ...a, approve: true })}>
                    Approve
                  </button>
                  <button className="btn btn-danger btn-sm" onClick={() => setConfirm({ ...a, approve: false })}>
                    Deny
                  </button>
                </div>
              )}
            </div>
          ))
        )}
      </div>

      {confirm && (
        <ConfirmDialog
          title={confirm.approve ? `Approve @${confirm.username}'s appeal?` : `Deny @${confirm.username}'s appeal?`}
          description={
            confirm.approve
              ? "This immediately lifts their ban/restriction. This is logged to the audit trail."
              : "The user keeps their current restriction. Explain why so it's clear if they appeal again."
          }
          confirmLabel={confirm.approve ? "Approve appeal" : "Deny appeal"}
          danger={!confirm.approve}
          requireReason
          onCancel={() => setConfirm(null)}
          onConfirm={(reason) => decide(confirm.approve, reason)}
        />
      )}

      {ToastEl}
    </>
  );
}
