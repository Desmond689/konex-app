<<<<<<< HEAD
import { useEffect, useState } from "react";
import { listCannedReasons } from "../lib/hooks";
=======
import { useState } from "react";
>>>>>>> origin/main

/**
 * Blocking confirmation for dangerous actions (ban, suspend, restrict,
 * remove content, role changes). Per the moderation review notes, these
 * should never be a single accidental click, and destructive actions
 * should always capture a reason for the audit trail.
<<<<<<< HEAD
 *
 * Pass `actionType` (e.g. "ban", "suspend", "restrict", "warn",
 * "remove_content") to offer a canned-reason quick-fill dropdown, sourced
 * from Settings → canned reasons.
=======
>>>>>>> origin/main
 */
export default function ConfirmDialog({
  title,
  description,
  confirmLabel = "Confirm",
  danger = false,
  requireReason = false,
<<<<<<< HEAD
  actionType = null,
=======
>>>>>>> origin/main
  onConfirm,
  onCancel,
}) {
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
<<<<<<< HEAD
  const [canned, setCanned] = useState([]);

  useEffect(() => {
    if (!actionType) return;
    let cancelled = false;
    listCannedReasons()
      .then((all) => {
        if (!cancelled) setCanned(all.filter((r) => r.action_type === actionType));
      })
      .catch(() => {}); // canned reasons are a convenience, never block the dialog on failure
    return () => {
      cancelled = true;
    };
  }, [actionType]);
=======
>>>>>>> origin/main

  const submit = async () => {
    if (requireReason && reason.trim().length < 3) {
      setError("A reason is required for this action.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await onConfirm(reason.trim() || null);
    } catch (e) {
      setError(e.message || "Something went wrong.");
      setBusy(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onCancel}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h3>{title}</h3>
        {description && <p>{description}</p>}
<<<<<<< HEAD
        {requireReason && canned.length > 0 && (
          <div className="field">
            <label className="field-label">Quick-fill from a canned reason</label>
            <select
              className="input"
              defaultValue=""
              onChange={(e) => {
                const r = canned.find((c) => c.id === e.target.value);
                if (r) setReason(r.body);
              }}
            >
              <option value="" disabled>
                Choose one…
              </option>
              {canned.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.label}
                </option>
              ))}
            </select>
          </div>
        )}
=======
>>>>>>> origin/main
        {requireReason && (
          <div className="field">
            <label className="field-label">Reason</label>
            <textarea
              className="input"
              rows={3}
              placeholder="Why is this action being taken? Staff and appeals reviewers will see this."
              value={reason}
              onChange={(e) => setReason(e.target.value)}
            />
          </div>
        )}
        {error && <div className="error-banner">{error}</div>}
        <div className="modal-actions">
          <button className="btn btn-ghost" onClick={onCancel} disabled={busy}>
            Cancel
          </button>
          <button
            className={danger ? "btn btn-danger" : "btn btn-primary"}
            onClick={submit}
            disabled={busy}
          >
            {busy ? "Working…" : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
