import { useEffect, useState } from "react";
import { listStaffNotes, addStaffNote } from "../lib/hooks";

/** Internal-only notes thread. Never shown to the end user — for staff
 * handoffs and case context (e.g. "already warned once verbally"). */
export default function StaffNotes({ targetType, targetId }) {
  const [notes, setNotes] = useState([]);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(true);
  const [posting, setPosting] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      setNotes(await listStaffNotes(targetType, targetId));
    } catch {
      // internal notes are a nice-to-have; fail quietly rather than blocking the page
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targetType, targetId]);

  const submit = async () => {
    if (!draft.trim()) return;
    setPosting(true);
    try {
      await addStaffNote(targetType, targetId, draft.trim());
      setDraft("");
      load();
    } finally {
      setPosting(false);
    }
  };

  return (
    <div className="staff-notes">
      <div className="section-label">Internal staff notes (not visible to users)</div>
      {loading ? (
        <div className="row-sub">Loading notes…</div>
      ) : notes.length === 0 ? (
        <div className="row-sub" style={{ marginBottom: 8 }}>No notes yet.</div>
      ) : (
        <div className="history-list" style={{ marginBottom: 8 }}>
          {notes.map((n) => (
            <div className="history-item" key={n.id}>
              <div className="history-action">
                <span className="muted">@{n.profiles?.username || "staff"}</span>
              </div>
              <div className="row-sub">
                {n.body} · {new Date(n.created_at).toLocaleString()}
              </div>
            </div>
          ))}
        </div>
      )}
      <div style={{ display: "flex", gap: 8 }}>
        <input
          className="input"
          placeholder="Add a note for other staff…"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && submit()}
        />
        <button className="btn btn-ghost btn-sm" disabled={posting || !draft.trim()} onClick={submit}>
          Add
        </button>
      </div>
    </div>
  );
}
