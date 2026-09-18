import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import Avatar from "../components/Avatar";
import ActionSheet from "../components/ActionSheet";
import ConfirmDialog from "../components/ConfirmDialog";
import { useToast } from "../components/Toast";
import { useAuth, can } from "../lib/AuthContext";
import { supabase } from "../supabaseClient";
import {
  fetchCommunityMembers,
  removeCommunityMember,
  setCommunityMemberRole,
} from "../lib/hooks";

function timeAgo(iso) {
  if (!iso) return "—";
  return new Date(iso).toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export default function GameMembers() {
  const { id } = useParams();
  const { role } = useAuth();
  const { showToast, ToastEl } = useToast();

  const [game, setGame] = useState(null);
  const [members, setMembers] = useState([]);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [sheetFor, setSheetFor] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const debounceRef = useRef(null);

  const load = useCallback(
    async (q) => {
      setLoading(true);
      setError(null);
      try {
        const [g, list] = await Promise.all([
          game ? Promise.resolve(game) : supabase.from("communities").select("id, name, avatar_url, member_count").eq("id", id).single(),
          fetchCommunityMembers(id, { query: q || null }),
        ]);
        if (!game) {
          if (g.error) throw g.error;
          setGame(g.data);
        }
        setMembers(list);
      } catch (e) {
        setError(e.message || "Failed to load members");
      } finally {
        setLoading(false);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [id]
  );

  useEffect(() => {
    load("");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  useEffect(() => {
    clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => load(query), 300);
    return () => clearTimeout(debounceRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  const actionsFor = (m) => {
    const opts = [];
    if (can(role, "manage_games")) {
      if (m.member_role !== "moderator")
        opts.push({ value: "role:moderator", label: "Make community moderator" });
      if (m.member_role !== "member") opts.push({ value: "role:member", label: "Set as regular member" });
      opts.push({ value: "remove", label: "Remove from community", danger: true });
    }
    return opts;
  };

  const pickAction = (action) => {
    const member = sheetFor;
    setSheetFor(null);
    if (action === "remove") {
      setConfirm({ member, action });
    } else if (action.startsWith("role:")) {
      apply(member, action.split(":")[1], null);
    }
  };

  const apply = async (member, roleOrAction, reason) => {
    try {
      if (roleOrAction === "remove") {
        await removeCommunityMember(id, member.user_id, reason);
      } else {
        await setCommunityMemberRole(id, member.user_id, roleOrAction, reason);
      }
      showToast(`Updated @${member.username}`, "success");
      load(query);
    } catch (e) {
      showToast(e.message || "Action failed", "error");
      throw e;
    }
  };

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">
            {game?.name ? `${game.name} — Members` : "Community members"}
          </h1>
          <p className="page-subtitle">
            {game?.member_count ?? "—"} total members. Search, review, and manage community-level roles.
          </p>
        </div>
        <Link to={`/games/${id}`} className="btn btn-ghost">
          ← Back to community
        </Link>
      </div>

      <div className="search-row" style={{ marginBottom: 20 }}>
        <input
          className="input"
          placeholder="Search members by username or gamer name…"
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
        ) : members.length === 0 ? (
          <div className="state-block">
            <div className="state-block-title">{query ? "No matches" : "No members yet"}</div>
            <div className="state-block-sub">
              {query ? `No member matches "${query}".` : "Nobody has joined this community yet."}
            </div>
          </div>
        ) : (
          members.map((m) => {
            const name = m.gamer_name || m.username;
            return (
              <div className="row" key={m.user_id}>
                <div className="user-row-identity">
                  <Avatar url={m.avatar_url} name={name} />
                  <div className="row-main">
                    <div className="row-title">
                      {name}
                      {m.is_verified && <span className="pill pill-verified">verified</span>}
                      {m.member_role && m.member_role !== "member" && (
                        <span className="pill pill-role-admin">{m.member_role}</span>
                      )}
                    </div>
                    <div className="row-sub">
                      @{m.username} · joined {timeAgo(m.joined_at)}
                      {m.is_banned && <span className="pill pill-banned" style={{ marginLeft: 6 }}>banned</span>}
                    </div>
                  </div>
                </div>
                {can(role, "manage_games") && (
                  <div className="row-actions">
                    <button className="btn btn-ghost btn-sm" onClick={() => setSheetFor(m)}>
                      Manage
                    </button>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>

      {sheetFor && (
        <ActionSheet
          title={`@${sheetFor.username}`}
          options={actionsFor(sheetFor)}
          onSelect={pickAction}
          onCancel={() => setSheetFor(null)}
        />
      )}

      {confirm && (
        <ConfirmDialog
          title={`Remove @${confirm.member.username} from ${game?.name || "this community"}?`}
          description="They can rejoin later unless you also restrict or ban them from the Users page."
          confirmLabel="Remove member"
          danger
          requireReason
          onCancel={() => setConfirm(null)}
          onConfirm={async (reason) => {
            await apply(confirm.member, "remove", reason);
            setConfirm(null);
          }}
        />
      )}

      {ToastEl}
    </>
  );
}
