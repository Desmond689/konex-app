import { useCallback, useEffect, useState } from "react";
import { supabase } from "../supabaseClient";
import { useAuth } from "./AuthContext";

// ---------- dashboard stats ----------
export function useAdminStats() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      const isoDay = startOfDay.toISOString();

      const [
        users,
        reports,
        posts,
        squads,
        reportsToday,
        resolvedToday,
        newUsersToday,
        postsToday,
        bannedUsers,
      ] = await Promise.all([
        supabase.from("profiles").select("id", { count: "exact", head: true }),
        supabase.from("reports").select("id", { count: "exact", head: true }).eq("status", "open"),
        supabase.from("posts").select("id", { count: "exact", head: true }).eq("is_deleted", false),
        supabase.from("squads").select("id", { count: "exact", head: true }),
        supabase
          .from("reports")
          .select("id", { count: "exact", head: true })
          .gte("created_at", isoDay),
        supabase
          .from("reports")
          .select("id", { count: "exact", head: true })
          .in("status", ["actioned", "dismissed"])
          .gte("reviewed_at", isoDay),
        supabase
          .from("profiles")
          .select("id", { count: "exact", head: true })
          .gte("created_at", isoDay),
        supabase
          .from("posts")
          .select("id", { count: "exact", head: true })
          .gte("created_at", isoDay)
          .eq("is_deleted", false),
        supabase
          .from("profiles")
          .select("id", { count: "exact", head: true })
          .eq("is_banned", true),
      ]);

      const err =
        users.error ||
        reports.error ||
        posts.error ||
        squads.error ||
        reportsToday.error ||
        resolvedToday.error ||
        newUsersToday.error ||
        postsToday.error ||
        bannedUsers.error;
      if (err) throw err;

      setStats({
        totalUsers: users.count ?? 0,
        openReports: reports.count ?? 0,
        totalPosts: posts.count ?? 0,
        totalSquads: squads.count ?? 0,
        reportsToday: reportsToday.count ?? 0,
        resolvedToday: resolvedToday.count ?? 0,
        newUsersToday: newUsersToday.count ?? 0,
        postsToday: postsToday.count ?? 0,
        bannedUsers: bannedUsers.count ?? 0,
      });
    } catch (e) {
      setError(e.message || "Failed to load stats");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return { stats, loading, error, reload: load };
}

export function useOpenReportCount() {
  const { isStaff } = useAuth();
  const [count, setCount] = useState(0);

  useEffect(() => {
    if (!isStaff) return;
    let cancelled = false;
    supabase
      .from("reports")
      .select("id", { count: "exact", head: true })
      .eq("status", "open")
      .then(({ count }) => {
        if (!cancelled) setCount(count ?? 0);
      });
    return () => {
      cancelled = true;
    };
  }, [isStaff]);

  return count;
}

// ---------- reports ----------
export function useOpenReports(limit = 50) {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const { data, error } = await supabase
      .from("reports")
      .select(
        `id, reporter_id, target_type, target_id, reason, details, status, created_at,
         profiles!reports_reporter_id_fkey ( username )`
      )
      .eq("status", "open")
      .order("created_at", { ascending: false })
      .limit(limit);
    if (error) setError(error.message);
    else setReports(data || []);
    setLoading(false);
  }, [limit]);

  useEffect(() => {
    load();
  }, [load]);

  return { reports, loading, error, reload: load };
}

/**
 * All sensitive moderation goes through the admin_resolve_report RPC.
 * Permission checks, audit log, moderation_actions, and effects are
 * applied server-side in one transaction. Frontend can() is UX only.
 */
export async function resolveReport({
  reportId,
  action,
  reason,
  targetUserId,
  targetType,
  targetId,
}) {
  const { error } = await supabase.rpc("admin_resolve_report", {
    p_report_id: reportId || "00000000-0000-0000-0000-000000000000",
    p_action: action,
    p_reason: reason ?? null,
    p_target_type: targetType ?? null,
    p_target_id: targetId ?? null,
    p_target_user_id: targetUserId ?? null,
  });
  if (error) throw error;
}

export async function fetchReportPreview(reportId) {
  const { data, error } = await supabase.rpc("admin_report_preview", {
    p_report_id: reportId,
  });
  if (error) throw error;
  return data;
}

export async function setUserBan(userId, banned) {
  const { error } = await supabase.rpc("admin_set_ban", {
    p_user_id: userId,
    p_banned: banned,
  });
  if (error) throw error;
}

// ---------- users ----------
export async function listUsers({ limit = 100, query = "" } = {}) {
  const q = query.trim().replace(/[%_,.]/g, " ").trim();
  let req = supabase
    .from("profiles")
    .select(
      "id, username, gamer_name, app_role, is_banned, is_restricted, is_verified, restricted_until, avatar_url, created_at"
    )
    .order("created_at", { ascending: false })
    .limit(limit);

  if (q) {
    req = req.or(`username.ilike.%${q}%,gamer_name.ilike.%${q}%`);
  }

  const { data, error } = await req;
  if (error) throw error;
  return data || [];
}

export async function searchUsers(query) {
  return listUsers({ query, limit: 30 });
}

export async function fetchUserModerationContext(userId) {
  const { data, error } = await supabase.rpc("admin_user_moderation_context", {
    p_user_id: userId,
  });
  if (error) throw error;
  return data;
}

export async function setUserRole(userId, roleValue) {
  const { error } = await supabase.rpc("admin_set_role", {
    p_user_id: userId,
    p_role: roleValue,
  });
  if (error) throw error;
  // Audit is still written client-side for role changes (RPC doesn't log yet);
  // prefer keeping the existing pattern so role changes appear in audit_logs.
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) {
    await supabase.from("audit_logs").insert({
      actor_id: user.id,
      action: "set_role",
      target_type: "profile",
      target_id: userId,
      reason: roleValue,
    });
  }
}

export async function setUserVerified(userId, verified) {
  const { error } = await supabase.rpc("admin_set_verified", {
    p_user_id: userId,
    p_verified: verified,
  });
  if (error) throw error;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) {
    await supabase.from("audit_logs").insert({
      actor_id: user.id,
      action: verified ? "verify" : "unverify",
      target_type: "profile",
      target_id: userId,
    });
  }
}

// ---------- staff (super_admin only) ----------
export async function listStaff() {
  const { data, error } = await supabase.rpc("admin_list_staff");
  if (error) throw error;
  return data || [];
}

// ---------- games / communities ----------
export async function listAllGames(query) {
  let q = supabase
    .from("communities")
    .select("id, name, slug, category, member_count, is_official, avatar_url")
    .order("member_count", { ascending: false })
    .limit(100);
  if (query) q = q.ilike("name", `%${query}%`);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}

export async function createGame({ name, description, rules, category, platforms = ["mobile"] }) {
  const slug =
    name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "") + `-${Date.now() % 10000}`;
  const { data, error } = await supabase.rpc("admin_create_game", {
    p_name: name.trim(),
    p_slug: slug,
    p_description: description || null,
    p_rules: rules || null,
    p_category: category || null,
    p_platforms: platforms,
  });
  if (error) throw error;
  return data;
}

export async function updateGame(communityId, patch) {
  const { error } = await supabase.rpc("admin_update_game", {
    p_community_id: communityId,
    p_name: patch.name ?? null,
    p_description: patch.description ?? null,
    p_rules: patch.rules ?? null,
    p_category: patch.category ?? null,
    p_platforms: patch.platforms ?? null,
    p_avatar_url: patch.avatarUrl ?? null,
    p_banner_url: patch.bannerUrl ?? null,
    p_primary_region: patch.primaryRegion ?? null,
    p_is_private: patch.isPrivate ?? null,
    p_require_approval: patch.requireApproval ?? null,
  });
  if (error) throw error;
}

export async function uploadLogo(file) {
  const ext = file.name.split(".").pop().toLowerCase();
  const allowed = new Set(["jpg", "jpeg", "png", "gif", "webp"]);
  if (!allowed.has(ext)) throw new Error("Unsupported image format. Use JPG, PNG, GIF, or WebP.");
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const fileName = `community_logo_${user.id}_${Date.now()}.${ext}`;
  const { error } = await supabase.storage.from("community-logos").upload(fileName, file, {
    cacheControl: "3600",
    upsert: false,
  });
  if (error) throw error;
  const { data } = supabase.storage.from("community-logos").getPublicUrl(fileName);
  return data.publicUrl;
}

// ---------- audit log ----------
export function useAuditLog(limit = 50) {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const { data, error } = await supabase
      .from("audit_logs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(limit);
    if (error) setError(error.message);
    else setLogs(data || []);
    setLoading(false);
  }, [limit]);

  useEffect(() => {
    load();
  }, [load]);

  return { logs, loading, error, reload: load };
}

// ---------- squads (Squad Control) ----------
export async function fetchSquadStats() {
  const { data, error } = await supabase.rpc("admin_squad_stats");
  if (error) throw error;
  return data;
}

export async function listSquads({ query = null, filter = "all", limit = 50 } = {}) {
  const { data, error } = await supabase.rpc("admin_list_squads", {
    p_query: query || null,
    p_filter: filter,
    p_limit: limit,
  });
  if (error) throw error;
  return data || [];
}

export async function fetchSquadDetail(squadId) {
  const { data, error } = await supabase.rpc("admin_squad_detail", {
    p_squad_id: squadId,
  });
  if (error) throw error;
  return data;
}

export async function restrictSquad(squadId, reason) {
  const { error } = await supabase.rpc("admin_restrict_squad", {
    p_squad_id: squadId,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function restoreSquad(squadId, reason = null) {
  const { error } = await supabase.rpc("admin_restore_squad", {
    p_squad_id: squadId,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function archiveSquad(squadId, reason) {
  const { error } = await supabase.rpc("admin_archive_squad", {
    p_squad_id: squadId,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function transferSquadOwner(squadId, newOwnerId, reason) {
  const { error } = await supabase.rpc("admin_transfer_squad_owner", {
    p_squad_id: squadId,
    p_new_owner_id: newOwnerId,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function setSquadMemberRole(squadId, userId, role, reason = null) {
  const { error } = await supabase.rpc("admin_set_squad_member_role", {
    p_squad_id: squadId,
    p_user_id: userId,
    p_role: role,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function removeSquadMember(squadId, userId, ban = false, reason = null) {
  const { error } = await supabase.rpc("admin_remove_squad_member", {
    p_squad_id: squadId,
    p_user_id: userId,
    p_ban: ban,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function listPendingJoinRequests(limit = 50) {
  const { data, error } = await supabase.rpc("admin_list_pending_join_requests", {
    p_limit: limit,
  });
  if (error) throw error;
  return data || [];
}

export async function reviewJoinRequest(squadId, userId, approve, reason = null) {
  const { error } = await supabase.rpc("admin_review_join_request", {
    p_squad_id: squadId,
    p_user_id: userId,
    p_approve: approve,
    p_reason: reason,
  });
  if (error) throw error;
}

<<<<<<< HEAD
// ---------- community members ----------
export async function fetchCommunityMembers(communityId, { query = null, limit = 100, offset = 0 } = {}) {
  const { data, error } = await supabase.rpc("admin_list_community_members", {
    p_community_id: communityId,
    p_query: query || null,
    p_limit: limit,
    p_offset: offset,
  });
  if (error) throw error;
  return data || [];
}

export async function removeCommunityMember(communityId, userId, reason = null) {
  const { error } = await supabase.rpc("admin_remove_community_member", {
    p_community_id: communityId,
    p_user_id: userId,
    p_reason: reason,
  });
  if (error) throw error;
}

export async function setCommunityMemberRole(communityId, userId, roleValue, reason = null) {
  const { error } = await supabase.rpc("admin_set_community_member_role", {
    p_community_id: communityId,
    p_user_id: userId,
    p_role: roleValue,
    p_reason: reason,
  });
  if (error) throw error;
}

// ---------- appeals ----------
export async function listAppeals(status = "open", limit = 50) {
  const { data, error } = await supabase.rpc("admin_list_appeals", { p_status: status, p_limit: limit });
  if (error) throw error;
  return data || [];
}

export async function reviewAppeal(appealId, approve, reason = null) {
  const { error } = await supabase.rpc("admin_review_appeal", {
    p_appeal_id: appealId,
    p_approve: approve,
    p_reason: reason,
  });
  if (error) throw error;
}

// ---------- canned reasons ----------
export async function listCannedReasons() {
  const { data, error } = await supabase
    .from("canned_reasons")
    .select("*")
    .order("action_type", { ascending: true });
  if (error) throw error;
  return data || [];
}

export async function upsertCannedReason({ id = null, actionType, label, body }) {
  const { data, error } = await supabase.rpc("admin_upsert_canned_reason", {
    p_id: id,
    p_action_type: actionType,
    p_label: label,
    p_body: body,
  });
  if (error) throw error;
  return data;
}

export async function deleteCannedReason(id) {
  const { error } = await supabase.rpc("admin_delete_canned_reason", { p_id: id });
  if (error) throw error;
}

// ---------- staff notes (internal, never user-visible) ----------
export async function listStaffNotes(targetType, targetId) {
  const { data, error } = await supabase
    .from("staff_notes")
    .select("id, body, created_at, author_id, profiles!staff_notes_author_id_fkey(username)")
    .eq("target_type", targetType)
    .eq("target_id", targetId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function addStaffNote(targetType, targetId, body) {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { error } = await supabase.from("staff_notes").insert({
    target_type: targetType,
    target_id: targetId,
    author_id: user?.id,
    body,
  });
  if (error) throw error;
}

// ---------- realtime: live-updating open report count + new-report toast ----------
export function useLiveOpenReports(onNewReport) {
  const { isStaff } = useAuth();
  const [count, setCount] = useState(0);

  useEffect(() => {
    if (!isStaff) return;
    let cancelled = false;

    const refresh = () =>
      supabase
        .from("reports")
        .select("id", { count: "exact", head: true })
        .eq("status", "open")
        .then(({ count: c }) => {
          if (!cancelled) setCount(c ?? 0);
        });

    refresh();

    const channel = supabase
      .channel("admin-open-reports")
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "reports" }, (payload) => {
        refresh();
        if (onNewReport) onNewReport(payload.new);
      })
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "reports" }, refresh)
      .subscribe();

    return () => {
      cancelled = true;
      supabase.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isStaff]);

  return count;
}

// ---------- analytics ----------
function bucketByDay(rows, days) {
  const buckets = {};
  const now = new Date();
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    buckets[d.toISOString().slice(0, 10)] = 0;
  }
  rows.forEach((r) => {
    const key = (r.created_at || "").slice(0, 10);
    if (key in buckets) buckets[key] += 1;
  });
  return Object.entries(buckets).map(([date, count]) => ({ date, count }));
}

export async function fetchAnalytics(days = 30) {
  const since = new Date();
  since.setDate(since.getDate() - (days - 1));
  since.setHours(0, 0, 0, 0);
  const sinceIso = since.toISOString();

  const [signups, reports, posts, resolved] = await Promise.all([
    supabase.from("profiles").select("created_at").gte("created_at", sinceIso),
    supabase.from("reports").select("created_at").gte("created_at", sinceIso),
    supabase.from("posts").select("created_at").eq("is_deleted", false).gte("created_at", sinceIso),
    supabase
      .from("reports")
      .select("reviewed_at")
      .in("status", ["actioned", "dismissed"])
      .gte("reviewed_at", sinceIso),
  ]);
  const err = signups.error || reports.error || posts.error || resolved.error;
  if (err) throw err;

  return {
    signups: bucketByDay(signups.data || [], days),
    reports: bucketByDay(reports.data || [], days),
    posts: bucketByDay(posts.data || [], days),
    resolved: bucketByDay((resolved.data || []).map((r) => ({ created_at: r.reviewed_at })), days),
  };
}

export async function fetchModeratorLeaderboard(days = 30) {
  const since = new Date();
  since.setDate(since.getDate() - days);
  const { data, error } = await supabase
    .from("audit_logs")
    .select("actor_id, profiles!audit_logs_actor_id_fkey(username)")
    .gte("created_at", since.toISOString());
  if (error) throw error;
  const counts = {};
  (data || []).forEach((row) => {
    const key = row.actor_id;
    if (!counts[key]) counts[key] = { username: row.profiles?.username || key?.slice(0, 8), count: 0 };
    counts[key].count += 1;
  });
  return Object.values(counts).sort((a, b) => b.count - a.count);
}

// ---------- global search (command palette) ----------
export async function globalSearch(query) {
  const q = query.trim();
  if (q.length < 2) return { users: [], games: [], squads: [] };
  const [users, games, squads] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, username, gamer_name")
      .or(`username.ilike.%${q}%,gamer_name.ilike.%${q}%`)
      .limit(5),
    supabase.from("communities").select("id, name").ilike("name", `%${q}%`).limit(5),
    supabase.rpc("admin_list_squads", { p_query: q, p_filter: "all", p_limit: 5 }),
  ]);
  return {
    users: users.data || [],
    games: games.data || [],
    squads: squads.data || [],
  };
}

=======
>>>>>>> origin/main
export async function updateSquadSettings(squadId, patch, reason = null) {
  const { error } = await supabase.rpc("admin_update_squad_settings", {
    p_squad_id: squadId,
    p_name: patch.name ?? null,
    p_description: patch.description ?? null,
    p_rules: patch.rules ?? null,
    p_is_public: patch.isPublic ?? null,
    p_require_approval: patch.requireApproval ?? null,
    p_invite_policy: patch.invitePolicy ?? null,
    p_reason: reason,
  });
  if (error) throw error;
}
