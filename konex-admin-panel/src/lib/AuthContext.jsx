import { createContext, useContext, useEffect, useState, useCallback } from "react";
import { supabase } from "../supabaseClient";

const AuthContext = createContext(null);

const STAFF_ROLES = new Set(["moderator", "admin", "super_admin"]);

// Central place for "who can do what" on the client. The database RPCs
// enforce the real boundary (a user could always call the API directly),
// but hiding actions someone can't perform keeps the UI honest.
export function can(role, action) {
  switch (action) {
    case "view_dashboard":
    case "view_reports":
    case "resolve_reports":
    case "ban_users":
    case "manage_games":
    case "view_users":
    case "view_squads":
    case "moderate_squads":
      return STAFF_ROLES.has(role);
    case "squad_system_controls":
    case "transfer_squad_owner":
    case "update_squad_settings":
      return role === "super_admin";
    case "verify_users":
    case "make_moderator":
      return role === "admin" || role === "super_admin";
    case "make_admin":
      return role === "super_admin";
    case "manage_staff":
      return role === "super_admin";
    case "change_super_admin":
      return false; // nobody does this from the UI, ever
    default:
      return false;
  }
}

export function AuthProvider({ children }) {
  const [session, setSession] = useState(undefined); // undefined = loading
  const [role, setRole] = useState(null);
  const [roleLoading, setRoleLoading] = useState(true);

  const loadRole = useCallback(async (userId) => {
    if (!userId) {
      setRole(null);
      setRoleLoading(false);
      return;
    }
    setRoleLoading(true);
    const { data, error } = await supabase
      .from("profiles")
      .select("app_role")
      .eq("id", userId)
      .maybeSingle();
    setRole(error ? null : data?.app_role ?? "user");
    setRoleLoading(false);
  }, []);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      loadRole(data.session?.user?.id);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s);
      loadRole(s?.user?.id);
    });
    return () => sub.subscription.unsubscribe();
  }, [loadRole]);

  const signIn = async (email, password) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    return { error };
  };

  const signOut = () => supabase.auth.signOut();

  const isStaff = STAFF_ROLES.has(role);

  return (
    <AuthContext.Provider
      value={{
        session,
        loading: session === undefined || (!!session && roleLoading),
        role,
        isStaff,
        signIn,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
