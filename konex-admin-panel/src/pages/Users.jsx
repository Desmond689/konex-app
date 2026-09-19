import { useEffect, useRef, useState } from "react";
import ActionSheet from "../components/ActionSheet";
import Avatar from "../components/Avatar";
import ConfirmDialog from "../components/ConfirmDialog";
import StaffNotes from "../components/StaffNotes";
import { useToast } from "../components/Toast";
import { useAuth, can } from "../lib/AuthContext";
import {
  listUsers,
  searchUsers,
  setUserRole,
  setUserVerified,
  setUserBan,
  fetchUserModerationContext,
} from "../lib/hooks";

function timeAgo(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export default function Users() {
  const { role } = useAuth();
  const [query, setQuery] = useState("");
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [sheetFor, setSheetFor] = useState(null);
  const [confirmAction, setConfirmAction] = useState(null);
  const [detailUser, setDetailUser] = useState(null);
  const [detailCtx, setDetailCtx] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const debounceRef = useRef(null);
  const { showToast, ToastEl } = useToast();

  const runSearch = async (q) => {
    setLoading(true);
    setError(null);
    try {
      const nextUsers = q.trim().length >= 2 ? await searchUsers(q) : await listUsers();
      setUsers(nextUsers);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => runSearch(query), 300);
    return () => clearTimeout(debounceRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  useEffect(() => {
    runSearch("");
  }, []);

  const openDetail = async (u) => {
    setDetailUser(u);
    setDetailCtx(null);
    setDetailLoading(true);
    try {
      const ctx = await fetchUserModerationContext(u.id);
      setDetailCtx(ctx);
    } catch (e) {
      showToast(e.message || "Failed to load user context", "error");
    } finally {
      setDetailLoading(false);
    }
  };

  const actionsFor = (u) => {
    const opts = [];
    if (can(role, "make_moderator")) opts.push({ value: "role:moderator", label: "Make moderator" });
    if (can(role, "make_admin")) opts.push({ value: "role:admin", label: "Make admin" });
    if (can(role, "make_moderator")) opts.push({ value: "role:user", label: "Set as regular user" });
    if (can(role, "verify_users"))
      opts.push({
        value: u.is_verified ? "unverify" : "verify",
        label: u.is_verified ? "Remove verified badge" : "Verify user",
      });
    if (can(role, "ban_users")) {
      opts.push({ value: "ban", label: "Ban", danger: true });
      opts.push({ value: "restore", label: "Restore (unban / unrestrict)" });
    }
    return opts;
  };

  const pickAction = (action) => {
    const user = sheetFor;
    setSheetFor(null);
    if (action === "ban") {
      setConfirmAction({ user, action });
    } else {
      apply(user, action, null);
    }
  };

  const apply = async (user, action, reason) => {
    try {
      if (action.startsWith("role:")) {
        const newRole = action.split(":")[1];
        await setUserRole(user.id, newRole);
      } else if (action === "verify" || action === "unverify") {
        await setUserVerified(user.id, action === "verify");
      } else if (action === "ban" || action === "restore") {
        await setUserBan(user.id, action === "ban");
      }
      showToast(`Updated @${user.username}`, "success");
      const nextUsers = query.trim().length >= 2
        ? await searchUsers(query)
        : await listUsers();
      setUsers(nextUsers);
      if (detailUser?.id === user.id) {
        openDetail({ ...user });
      }
    } catch (e) {
      showToast(e.message || "Action failed", "error");
      throw e;
    }
  };

  const profile = detailCtx?.profile || detailUser;
  const history = detailCtx?.history || [];

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Users</h1>
          <p className="page-subtitle">
            Search by username or gamer name. Open Manage for full moderation context before acting.
          </p>
        </div>
      </div>

      <div className="search-row" style={{ marginBottom: 20 }}>
        <input
          className="input"
          placeholder="Search users…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="panel">
        {loading ? (
          <div className="state-block">
            <div className="spinner" />
          </div>
        ) : users.length === 0 ? (
          <div className="state-block">
            <div className="state-block-title">
              {query.trim().length >= 2 ? "No matches" : "No users yet"}
            </div>
            <div className="state-block-sub">
              {query.trim().length >= 2 ? `No user matches "${query}".` : "No users are available in the system yet."}
            </div>
          </div>
        ) : (
          users.map((u) => {
            const name = u.gamer_name || u.username;
            return (
              <div className="row" key={u.id}>
                <div className="user-row-identity">
                  <Avatar url={u.avatar_url} name={name} />
                  <div className="row-main">
                    <div className="row-title">
                      {name}
                      {u.is_verified && <span className="pill pill-verified">verified</span>}
                    </div>
                    <div className="row-sub">
                      @{u.username} ·{" "}
                      <span className={`pill pill-role-${u.app_role}`}>{u.app_role || "user"}</span>{" "}
                      {u.is_banned && <span className="pill pill-banned">banned</span>}{" "}
                      {u.is_restricted && <span className="pill pill-restricted">restricted</span>}
                    </div>
                  </div>
                </div>
                <div className="row-actions">
                  <button className="btn btn-ghost btn-sm" onClick={() => openDetail(u)}>
                    Manage
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* User moderation drawer */}
      {detailUser && (
        <div className="modal-backdrop" onClick={() => setDetailUser(null)}>
          <div className="modal modal-wide" onClick={(e) => e.stopPropagation()}>
            <div className="detail-header">
              <Avatar
                url={profile?.avatar_url || detailUser.avatar_url}
                name={profile?.gamer_name || profile?.username || detailUser.username}
                size="lg"
              />
              <div>
                <h3 style={{ margin: 0 }}>
                  @{profile?.username || detailUser.username}
                  {(profile?.is_verified || detailUser.is_verified) && (
                    <span className="pill pill-verified" style={{ marginLeft: 8 }}>
                      verified
                    </span>
                  )}
                </h3>
                <div className="row-sub">
                  {profile?.gamer_name || detailUser.gamer_name || "—"}
                </div>
              </div>
            </div>

            {detailLoading ? (
              <div className="state-block">
                <div className="spinner" />
              </div>
            ) : (
              <>
                <div className="ctx-grid">
                  <CtxItem
                    label="Status"
                    value={
                      profile?.is_banned
                        ? "Banned"
                        : profile?.is_restricted
                          ? `Restricted${profile?.restricted_until ? ` until ${timeAgo(profile.restricted_until)}` : ""}`
                          : "Active"
                    }
                    tone={profile?.is_banned ? "danger" : profile?.is_restricted ? "warn" : "ok"}
                  />
                  <CtxItem label="Role" value={profile?.app_role || "user"} />
                  <CtxItem
                    label="Verification"
                    value={profile?.is_verified ? "Verified" : "Not verified"}
                  />
                  <CtxItem label="Reports received" value={detailCtx?.reports_received ?? 0} />
                  <CtxItem label="Warnings" value={detailCtx?.warnings ?? 0} />
                  <CtxItem label="Restrictions" value={detailCtx?.restrictions ?? 0} />
                  <CtxItem label="Suspensions" value={detailCtx?.suspensions ?? 0} />
                  <CtxItem label="Bans" value={detailCtx?.bans ?? 0} />
                </div>

                <div className="section-label">Moderation history</div>
                {history.length === 0 ? (
                  <div className="row-sub" style={{ marginBottom: 16 }}>
                    No prior moderation actions on this user.
                  </div>
                ) : (
                  <div className="history-list">
                    {history.map((h, i) => (
                      <div className="history-item" key={h.id || i}>
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

                <StaffNotes targetType="profile" targetId={detailUser.id} />

                <div className="modal-actions" style={{ marginTop: 16 }}>
                  <button className="btn btn-ghost" onClick={() => setDetailUser(null)}>
                    Close
                  </button>
                  <button
                    className="btn btn-primary"
                    onClick={() => {
                      setSheetFor(profile || detailUser);
                    }}
                  >
                    Take action
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {sheetFor && (
        <ActionSheet
          title={`@${sheetFor.username}`}
          options={actionsFor(sheetFor)}
          onSelect={pickAction}
          onCancel={() => setSheetFor(null)}
        />
      )}

      {confirmAction && (
        <ConfirmDialog
          title={`Ban @${confirmAction.user.username}?`}
          description="This immediately blocks the user from the app. Make sure this is intentional."
          confirmLabel="Ban user"
          danger
          requireReason
          actionType="ban"
          onCancel={() => setConfirmAction(null)}
          onConfirm={async (reason) => {
            await apply(confirmAction.user, confirmAction.action, reason);
            setConfirmAction(null);
          }}
        />
      )}

      {ToastEl}
    </>
  );
}

function CtxItem({ label, value, tone }) {
  return (
    <div className={`ctx-item ${tone ? `tone-${tone}` : ""}`}>
      <div className="ctx-label">{label}</div>
      <div className="ctx-value">{value}</div>
    </div>
  );
}
