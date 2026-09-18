import { useEffect, useState } from "react";
import { useToast } from "../components/Toast";
import { useAuth, can } from "../lib/AuthContext";
import { listCannedReasons, upsertCannedReason, deleteCannedReason } from "../lib/hooks";

const ACTION_TYPES = ["warn", "restrict", "suspend", "ban", "remove_content"];

export default function Settings() {
  const { role } = useAuth();
  const { showToast, ToastEl } = useToast();
  const [reasons, setReasons] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [form, setForm] = useState({ actionType: "warn", label: "", body: "" });
  const [saving, setSaving] = useState(false);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      setReasons(await listCannedReasons());
    } catch (e) {
      setError(e.message || "Failed to load canned reasons");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const canManage = can(role, "make_moderator"); // admin/super_admin

  const submit = async (e) => {
    e.preventDefault();
    if (!form.label.trim() || !form.body.trim()) return;
    setSaving(true);
    try {
      await upsertCannedReason(form);
      setForm({ actionType: "warn", label: "", body: "" });
      showToast("Canned reason saved", "success");
      load();
    } catch (e) {
      showToast(e.message || "Save failed", "error");
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id) => {
    try {
      await deleteCannedReason(id);
      showToast("Removed", "success");
      load();
    } catch (e) {
      showToast(e.message || "Delete failed", "error");
    }
  };

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Settings</h1>
          <p className="page-subtitle">
            Canned moderation reasons — quick-fill text staff can reuse in confirmation dialogs.
          </p>
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      {canManage && (
        <form onSubmit={submit} className="panel" style={{ padding: 18, marginBottom: 20, maxWidth: 560 }}>
          <div className="field">
            <label className="field-label">Applies to</label>
            <select
              className="input"
              value={form.actionType}
              onChange={(e) => setForm((f) => ({ ...f, actionType: e.target.value }))}
            >
              {ACTION_TYPES.map((a) => (
                <option key={a} value={a}>
                  {a.replace("_", " ")}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label className="field-label">Short label (shown in the picker)</label>
            <input
              className="input"
              value={form.label}
              onChange={(e) => setForm((f) => ({ ...f, label: e.target.value }))}
              placeholder="e.g. Harassment — first offense"
            />
          </div>
          <div className="field">
            <label className="field-label">Reason text</label>
            <textarea
              className="input"
              rows={3}
              value={form.body}
              onChange={(e) => setForm((f) => ({ ...f, body: e.target.value }))}
              placeholder="The exact text that gets filled into the reason field."
            />
          </div>
          <button className="btn btn-primary" disabled={saving} type="submit">
            {saving ? "Saving…" : "Add canned reason"}
          </button>
        </form>
      )}

      <div className="section-label">All canned reasons</div>
      <div className="panel">
        {loading ? (
          <div className="state-block">
            <div className="spinner" />
          </div>
        ) : reasons.length === 0 ? (
          <div className="state-block">
            <div className="state-block-title">None yet</div>
            <div className="state-block-sub">
              {canManage ? "Add one above." : "Ask an admin to add some."}
            </div>
          </div>
        ) : (
          reasons.map((r) => (
            <div className="row" key={r.id}>
              <div className="row-main">
                <div className="row-title">
                  {r.label}
                  <span className="pill pill-role-admin">{r.action_type.replace("_", " ")}</span>
                </div>
                <div className="row-sub">{r.body}</div>
              </div>
              {canManage && (
                <div className="row-actions">
                  <button className="btn btn-ghost btn-sm" onClick={() => remove(r.id)}>
                    Delete
                  </button>
                </div>
              )}
            </div>
          ))
        )}
      </div>

      {ToastEl}
    </>
  );
}
