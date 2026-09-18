import { useCallback, useEffect, useState } from "react";
import Avatar from "../components/Avatar";
import ActionSheet from "../components/ActionSheet";
import ConfirmDialog from "../components/ConfirmDialog";
import { useToast } from "../components/Toast";
import { useAuth, can } from "../lib/AuthContext";
import {
  fetchSquadStats,
  listSquads,
  fetchSquadDetail,
  restrictSquad,
  restoreSquad,
  archiveSquad,
  transferSquadOwner,
  setSquadMemberRole,
  removeSquadMember,
  listPendingJoinRequests,
  reviewJoinRequest,
} from "../lib/hooks";

const FILTERS = [
  { value: "all", label: "All" },
  { value: "public", label: "Public" },
  { value: "private", label: "Private" },
  { value: "restricted", label: "Restricted" },
  { value: "archived", label: "Archived" },
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

export default function Squads() {
  const { role } = useAuth();
  const { showToast, ToastEl } = useToast();
  const [stats, setStats] = useState(null);
  const [squads, setSquads] = useState([]);
  const [requests, setRequests] = useState([]);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [detail, setDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [memberSheet, setMemberSheet] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [tab, setTab] = useState("database"); // database | requests

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [s, list, reqs] = await Promise.all([
        fetchSquadStats(),
        listSquads({ query: query.trim() || null, filter }),
        listPendingJoinRequests(),
      ]);
      setStats(s);
      setSquads(list);
      setRequests(reqs);
    } catch (e) {
      setError(e.message || "Failed to load squads");
    } finally {
      setLoading(false);
    }
  }, [query, filter]);

  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);

  const openDetail = async (id) => {
    setDetailLoading(true);
    try {
      const d = await fetchSquadDetail(id);
      setDetail(d);
    } catch (e) {
      showToast(e.message || "Failed to load squad", "error");
    } finally {
      setDetailLoading(false);
    }
  };

  const runConfirm = async (reason) => {
    const c = confirm;
    try {
      if (c.kind === "restrict") await restrictSquad(c.squadId, reason);
      else if (c.kind === "restore") await restoreSquad(c.squadId, reason);
      else if (c.kind === "archive") await archiveSquad(c.squadId, reason);
      else if (c.kind === "transfer") await transferSquadOwner(c.squadId, c.userId, reason);
      else if (c.kind === "remove") await removeSquadMember(c.squadId, c.userId, false, reason);
      else if (c.kind === "ban_member") await removeSquadMember(c.squadId, c.userId, true, reason);
      else if (c.kind === "role") await setSquadMemberRole(c.squadId, c.userId, c.role, reason);
      showToast("Done", "success");
      setConfirm(null);
      if (detail?.squad?.id) await openDetail(detail.squad.id);
      load();
    } catch (e) {
      showToast(e.message || "Action failed", "error");
      throw e;
    }
  };

  const statusLabel = (s) => {
    if (s.is_deleted) return "Archived";
    if (s.is_restricted) return "Restricted";
    return "Active";
  };

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Squads // Control</h1>
          <p className="page-subtitle">
            Inspect, moderate, and manage the squad ecosystem. Sensitive ops go through secure RPCs
            and are audited.
          </p>
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      {/* Overview stats */}
      <div className="stat-grid">
        <Stat label="Total squads" value={stats?.total} loading={loading} />
        <Stat label="Public" value={stats?.public} loading={loading} />
        <Stat label="Private" value={stats?.private} loading={loading} />
        <Stat label="Active" value={stats?.active} loading={loading} />
        <Stat label="Restricted" value={stats?.restricted} loading={loading} accent={stats?.restricted > 0} />
        <Stat label="Archived" value={stats?.archived} loading={loading} />
        <Stat label="Members" value={stats?.members} loading={loading} />
        <Stat
          label="Pending joins"
          value={stats?.pending_requests}
          loading={loading}
          accent={stats?.pending_requests > 0}
        />
        <Stat
          label="Open squad reports"
          value={stats?.open_squad_reports}
          loading={loading}
          accent={stats?.open_squad_reports > 0}
        />
        <Stat label="Created today" value={stats?.created_today} loading={loading} />
      </div>

      {/* Tabs */}
      <div className="filter-row" style={{ marginTop: 16, marginBottom: 12 }}>
        <button
          className={`filter-chip ${tab === "database" ? "active" : ""}`}
          onClick={() => setTab("database")}
        >
          Squad database
        </button>
        <button
          className={`filter-chip ${tab === "requests" ? "active" : ""}`}
          onClick={() => setTab("requests")}
        >
          Join requests
          {requests.length > 0 && <span className="badge-count">{requests.length}</span>}
        </button>
      </div>

      {tab === "database" && (
        <>
          <div className="search-row" style={{ marginBottom: 12, gap: 10, display: "flex", flexWrap: "wrap" }}>
            <input
              className="input"
              style={{ flex: 1, minWidth: 200 }}
              placeholder="Search name, ID, owner, game…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
            <div className="filter-row">
              {FILTERS.map((f) => (
                <button
                  key={f.value}
                  className={`filter-chip ${filter === f.value ? "active" : ""}`}
                  onClick={() => setFilter(f.value)}
                >
                  {f.label}
                </button>
              ))}
            </div>
          </div>

          <div className="panel">
            {loading ? (
              <div className="state-block">
                <div className="spinner" />
              </div>
            ) : squads.length === 0 ? (
              <div className="state-block">
                <div className="state-block-title">No squads</div>
                <div className="state-block-sub">Nothing matches this search/filter.</div>
              </div>
            ) : (
              squads.map((s) => (
                <div className="row" key={s.id}>
                  <div className="user-row-identity">
                    <Avatar url={s.logo_url} name={s.name} />
                    <div className="row-main">
                      <div className="row-title">
                        {s.name}
                        {s.is_public ? (
                          <span className="pill">public</span>
                        ) : (
                          <span className="pill">private</span>
                        )}
                        {s.is_restricted && <span className="pill pill-restricted">restricted</span>}
                        {s.is_deleted && <span className="pill pill-banned">archived</span>}
                      </div>
                      <div className="row-sub">
                        {s.primary_game || "—"} · Owner @{s.owner_username || "?"} ·{" "}
                        {s.member_count ?? 0} members · {statusLabel(s)}
                      </div>
                    </div>
                  </div>
                  <div className="row-actions">
                    <button className="btn btn-ghost btn-sm" onClick={() => openDetail(s.id)}>
                      Open
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </>
      )}

      {tab === "requests" && (
        <div className="panel">
          {requests.length === 0 ? (
            <div className="state-block">
              <div className="state-block-title">No pending requests</div>
            </div>
          ) : (
            requests.map((r) => (
              <div className="row" key={`${r.squad_id}-${r.user_id}`}>
                <div className="user-row-identity">
                  <Avatar url={r.avatar_url} name={r.gamer_name || r.username} />
                  <div className="row-main">
                    <div className="row-title">
                      @{r.username} → {r.squad_name}
                    </div>
                    <div className="row-sub">
                      {r.primary_game || "—"} · Requested {timeAgo(r.created_at)}
                    </div>
                  </div>
                </div>
                <div className="row-actions">
                  <button
                    className="btn btn-ghost btn-sm"
                    onClick={async () => {
                      try {
                        await reviewJoinRequest(r.squad_id, r.user_id, false);
                        showToast("Denied", "success");
                        load();
                      } catch (e) {
                        showToast(e.message, "error");
                      }
                    }}
                  >
                    Deny
                  </button>
                  <button
                    className="btn btn-primary btn-sm"
                    onClick={async () => {
                      try {
                        await reviewJoinRequest(r.squad_id, r.user_id, true);
                        showToast("Approved", "success");
                        load();
                      } catch (e) {
                        showToast(e.message, "error");
                      }
                    }}
                  >
                    Approve
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {/* Detail drawer */}
      {(detail || detailLoading) && (
        <div className="modal-backdrop" onClick={() => !detailLoading && setDetail(null)}>
          <div className="modal modal-wide" onClick={(e) => e.stopPropagation()}>
            {detailLoading || !detail ? (
              <div className="state-block">
                <div className="spinner" />
              </div>
            ) : (
              <SquadDetail
                detail={detail}
                role={role}
                onClose={() => setDetail(null)}
                onMemberAction={(m) => setMemberSheet({ member: m, squadId: detail.squad.id })}
                onConfirm={(c) => setConfirm(c)}
              />
            )}
          </div>
        </div>
      )}

      {memberSheet && (
        <ActionSheet
          title={`@${memberSheet.member.username}`}
          options={memberActions(memberSheet.member, role)}
          onSelect={(action) => {
            const { member, squadId } = memberSheet;
            setMemberSheet(null);
            if (action === "promote")
              setConfirm({ kind: "role", squadId, userId: member.user_id, role: "moderator" });
            else if (action === "demote")
              setConfirm({ kind: "role", squadId, userId: member.user_id, role: "member" });
            else if (action === "remove")
              setConfirm({ kind: "remove", squadId, userId: member.user_id, danger: true });
            else if (action === "ban")
              setConfirm({ kind: "ban_member", squadId, userId: member.user_id, danger: true });
            else if (action === "transfer")
              setConfirm({
                kind: "transfer",
                squadId,
                userId: member.user_id,
                danger: true,
                username: member.username,
              });
          }}
          onCancel={() => setMemberSheet(null)}
        />
      )}

      {confirm && (
        <ConfirmDialog
          title={confirmTitle(confirm)}
          description={confirmDesc(confirm)}
          confirmLabel={confirmLabel(confirm)}
          danger={!!confirm.danger}
          requireReason
          onCancel={() => setConfirm(null)}
          onConfirm={runConfirm}
        />
      )}

      {ToastEl}
    </>
  );
}

function memberActions(m, role) {
  const opts = [];
  if (m.role === "owner") return opts; // no direct actions on owner except transfer from another member
  if (m.role === "member") opts.push({ value: "promote", label: "Promote to moderator" });
  if (m.role === "moderator") opts.push({ value: "demote", label: "Demote to member" });
  opts.push({ value: "remove", label: "Remove from squad", danger: true });
  opts.push({ value: "ban", label: "Ban from squad", danger: true });
  if (can(role, "transfer_squad_owner") && m.status === "active") {
    opts.push({ value: "transfer", label: "Transfer ownership to this member", danger: true });
  }
  return opts;
}

function confirmTitle(c) {
  if (c.kind === "restrict") return "Restrict this squad?";
  if (c.kind === "restore") return "Restore this squad?";
  if (c.kind === "archive") return "Archive (force-close) this squad?";
  if (c.kind === "transfer") return `Transfer ownership to @${c.username}?`;
  if (c.kind === "remove") return "Remove member from squad?";
  if (c.kind === "ban_member") return "Ban member from squad?";
  if (c.kind === "role") return `Set role to ${c.role}?`;
  return "Confirm";
}

function confirmDesc(c) {
  if (c.kind === "archive")
    return "Members will be released so they can join other squads. This is logged in the audit trail.";
  if (c.kind === "transfer")
    return "This action is permanently recorded. The previous owner becomes a regular member.";
  return "A reason is required and will be written to the audit log.";
}

function confirmLabel(c) {
  if (c.kind === "transfer") return "Transfer ownership";
  if (c.kind === "archive") return "Archive squad";
  if (c.kind === "restrict") return "Restrict squad";
  return "Confirm";
}

function SquadDetail({ detail, role, onClose, onMemberAction, onConfirm }) {
  const s = detail.squad;
  const members = detail.members || [];
  const history = detail.moderation_history || [];
  const pending = detail.pending_requests || [];

  return (
    <>
      <div className="detail-header">
        <Avatar url={s.logo_url} name={s.name} size="lg" />
        <div>
          <h3 style={{ margin: 0 }}>{s.name}</h3>
          <div className="row-sub">
            {s.primary_game || "—"} · {s.is_public ? "Public" : "Private"} ·{" "}
            {s.is_deleted ? "Archived" : s.is_restricted ? "Restricted" : "Active"}
          </div>
        </div>
      </div>

      <div className="ctx-grid">
        <Ctx label="Squad ID" value={s.id?.slice?.(0, 8) + "…" || s.id} />
        <Ctx label="Owner" value={`@${s.owner_username || "?"}`} />
        <Ctx label="Members" value={s.member_count ?? members.length} />
        <Ctx label="Created" value={timeAgo(s.created_at)} />
        <Ctx label="Visibility" value={s.is_public ? "Public" : "Private"} />
        <Ctx label="Approval" value={s.require_approval ? "Required" : "Open"} />
        <Ctx label="Open reports" value={detail.open_reports ?? 0} />
        <Ctx
          label="Status"
          value={s.is_deleted ? "Archived" : s.is_restricted ? "Restricted" : "Active"}
          tone={s.is_deleted || s.is_restricted ? "danger" : "ok"}
        />
      </div>

      {s.description && (
        <>
          <div className="section-label">Description</div>
          <div className="content-preview" style={{ marginBottom: 8 }}>
            {s.description}
          </div>
        </>
      )}

      <div className="section-label">Members ({members.length})</div>
      <div className="history-list" style={{ maxHeight: 200 }}>
        {members.map((m) => (
          <div className="row" key={m.user_id} style={{ padding: "8px 0" }}>
            <div className="user-row-identity">
              <Avatar url={m.avatar_url} name={m.gamer_name || m.username} size="sm" />
              <div className="row-main">
                <div className="row-title">
                  @{m.username}
                  <span className={`pill pill-role-${m.role === "owner" ? "admin" : m.role === "moderator" ? "moderator" : "user"}`}>
                    {m.role}
                  </span>
                  {m.status !== "active" && <span className="pill">{m.status}</span>}
                </div>
                <div className="row-sub">Joined {timeAgo(m.joined_at)}</div>
              </div>
            </div>
            {m.role !== "owner" && can(role, "moderate_squads") && (
              <button className="btn btn-ghost btn-sm" onClick={() => onMemberAction(m)}>
                Manage
              </button>
            )}
          </div>
        ))}
      </div>

      {pending.length > 0 && (
        <>
          <div className="section-label">Pending join requests</div>
          {pending.map((r) => (
            <div className="row-sub" key={r.user_id}>
              @{r.username} · {timeAgo(r.created_at)}
            </div>
          ))}
        </>
      )}

      <div className="section-label">Moderation history</div>
      {history.length === 0 ? (
        <div className="row-sub">No staff actions on this squad yet.</div>
      ) : (
        <div className="history-list">
          {history.map((h, i) => (
            <div className="history-item" key={i}>
              <div className="history-action">
                <span className="pill">{h.action}</span>
                <span className="muted">by @{h.actor_username || "staff"}</span>
              </div>
              <div className="row-sub">
                {h.reason || "—"} · {timeAgo(h.created_at)}
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="section-label">Squad moderation</div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
        {!s.is_restricted && !s.is_deleted && (
          <button
            className="btn btn-ghost"
            onClick={() => onConfirm({ kind: "restrict", squadId: s.id, danger: true })}
          >
            Restrict squad
          </button>
        )}
        {(s.is_restricted || s.is_deleted) && (
          <button
            className="btn btn-ghost"
            onClick={() => onConfirm({ kind: "restore", squadId: s.id })}
          >
            Restore squad
          </button>
        )}
        {!s.is_deleted && (
          <button
            className="btn btn-danger"
            onClick={() => onConfirm({ kind: "archive", squadId: s.id, danger: true })}
          >
            Archive squad
          </button>
        )}
      </div>

      <div className="modal-actions" style={{ marginTop: 20 }}>
        <button className="btn btn-ghost" onClick={onClose}>
          Close
        </button>
      </div>
    </>
  );
}

function Stat({ label, value, loading, accent }) {
  return (
    <div className={`stat-card ${accent ? "accent-coral" : ""}`}>
      <div className="stat-card-value">{loading ? "—" : value ?? 0}</div>
      <div className="stat-card-label">{label}</div>
    </div>
  );
}

function Ctx({ label, value, tone }) {
  return (
    <div className={`ctx-item ${tone ? `tone-${tone}` : ""}`}>
      <div className="ctx-label">{label}</div>
      <div className="ctx-value">{value}</div>
    </div>
  );
}
