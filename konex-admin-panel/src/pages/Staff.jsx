import { useCallback, useEffect, useState } from "react";
import ActionSheet from "../components/ActionSheet";
import Avatar from "../components/Avatar";
import ConfirmDialog from "../components/ConfirmDialog";
import { useToast } from "../components/Toast";
import { useAuth, can } from "../lib/AuthContext";
import { listStaff, setUserRole } from "../lib/hooks";

/**
 * Staff management — visible only to super_admin.
 * Hierarchy:
 *   Staff
 *   ├── Moderators
 *   ├── Admins
 *   └── Super Admins  (read-only; cannot be changed from the app)
 */
export default function Staff() {
  const { role } = useAuth();
  const [staff, setStaff] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [sheetFor, setSheetFor] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const { showToast, ToastEl } = useToast();

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setStaff(await listStaff());
    } catch (e) {
      setError(e.message || "Failed to load staff");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  if (!can(role, "manage_staff")) {
    return (
      <div className="state-block">
        <div className="state-block-title">Restricted</div>
        <div className="state-block-sub">Only super admins can manage staff.</div>
      </div>
    );
  }

  const groups = {
    super_admin: staff.filter((s) => s.app_role === "super_admin"),
    admin: staff.filter((s) => s.app_role === "admin"),
    moderator: staff.filter((s) => s.app_role === "moderator"),
  };

  const actionsFor = (u) => {
    if (u.app_role === "super_admin") return []; // never change from UI
    const opts = [];
    if (u.app_role !== "moderator") opts.push({ value: "role:moderator", label: "Set as moderator" });
    if (u.app_role !== "admin") opts.push({ value: "role:admin", label: "Set as admin" });
    opts.push({ value: "role:user", label: "Demote to regular user", danger: true });
    return opts;
  };

  const pickAction = (action) => {
    const user = sheetFor;
    setSheetFor(null);
    const newRole = action.split(":")[1];
    setConfirm({ user, newRole });
  };

  const apply = async (user, newRole) => {
    try {
      await setUserRole(user.id, newRole);
      showToast(`@${user.username} → ${newRole}`, "success");
      load();
    } catch (e) {
      showToast(e.message || "Failed", "error");
      throw e;
    }
  };

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Staff</h1>
          <p className="page-subtitle">
            Moderators, admins, and super admins. Only super admins can change staff roles.
            Super admin itself can only be set via a direct database edit.
          </p>
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      {loading ? (
        <div className="state-block">
          <div className="spinner" />
        </div>
      ) : (
        <>
          <StaffGroup
            title="Super Admins"
            subtitle="Full control. Cannot be changed from the app."
            members={groups.super_admin}
            onManage={null}
          />
          <StaffGroup
            title="Admins"
            subtitle="Can promote moderators and verify users."
            members={groups.admin}
            onManage={(u) => setSheetFor(u)}
          />
          <StaffGroup
            title="Moderators"
            subtitle="Can resolve reports, ban via report flow, manage games."
            members={groups.moderator}
            onManage={(u) => setSheetFor(u)}
          />
        </>
      )}

      {sheetFor && (
        <ActionSheet
          title={`Manage @${sheetFor.username}`}
          options={actionsFor(sheetFor)}
          onSelect={pickAction}
          onCancel={() => setSheetFor(null)}
        />
      )}

      {confirm && (
        <ConfirmDialog
          title={`Change @${confirm.user.username} to ${confirm.newRole}?`}
          description={
            confirm.newRole === "user"
              ? "This removes their staff access immediately."
              : `They will become ${confirm.newRole}.`
          }
          confirmLabel="Confirm role change"
          danger={confirm.newRole === "user"}
          requireReason={false}
          onCancel={() => setConfirm(null)}
          onConfirm={async () => {
            await apply(confirm.user, confirm.newRole);
            setConfirm(null);
          }}
        />
      )}

      {ToastEl}
    </>
  );
}

function StaffGroup({ title, subtitle, members, onManage }) {
  return (
    <div className="panel" style={{ marginBottom: 16 }}>
      <div className="panel-header">
        <h2>
          {title}{" "}
          <span className="muted" style={{ fontWeight: 400, fontSize: 13 }}>
            ({members.length})
          </span>
        </h2>
        {subtitle && <div className="row-sub">{subtitle}</div>}
      </div>
      {members.length === 0 ? (
        <div className="row-sub" style={{ padding: "8px 0" }}>
          None
        </div>
      ) : (
        members.map((u) => (
          <div className="row" key={u.id}>
            <div className="user-row-identity">
              <Avatar url={u.avatar_url} name={u.gamer_name || u.username} />
              <div className="row-main">
                <div className="row-title">
                  {u.gamer_name || u.username}
                  {u.is_verified && <span className="pill pill-verified">verified</span>}
                </div>
                <div className="row-sub">
                  @{u.username} ·{" "}
                  <span className={`pill pill-role-${u.app_role}`}>{u.app_role}</span>
                </div>
              </div>
            </div>
            {onManage && (
              <div className="row-actions">
                <button className="btn btn-ghost btn-sm" onClick={() => onManage(u)}>
                  Manage
                </button>
              </div>
            )}
          </div>
        ))
      )}
    </div>
  );
}
