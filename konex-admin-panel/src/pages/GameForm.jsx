import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useToast } from "../components/Toast";
import { supabase } from "../supabaseClient";
import { createGame, updateGame, uploadLogo } from "../lib/hooks";

const CATEGORIES = ["fps", "battle_royale", "sports", "moba", "sandbox", "other"];

export default function GameForm() {
  const { id } = useParams();
  const isEdit = id && id !== "new";
  const navigate = useNavigate();
  const { showToast, ToastEl } = useToast();

  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [rules, setRules] = useState("");
  const [category, setCategory] = useState("other");
  const [isPrivate, setIsPrivate] = useState(false);
  const [requireApproval, setRequireApproval] = useState(false);
  const [avatarUrl, setAvatarUrl] = useState(null);
  const [logoFile, setLogoFile] = useState(null);
  const [logoPreview, setLogoPreview] = useState(null);

  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!isEdit) return;
    (async () => {
      const { data, error } = await supabase.from("communities").select("*").eq("id", id).single();
      if (error) {
        setError(error.message);
      } else if (data) {
        setName(data.name || "");
        setDescription(data.description || "");
        setRules(data.rules || "");
        setCategory(data.category || "other");
        setIsPrivate(!!data.is_private);
        setRequireApproval(!!data.require_approval);
        setAvatarUrl(data.avatar_url || null);
      }
      setLoading(false);
    })();
  }, [id, isEdit]);

  const onPickLogo = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setLogoFile(file);
    setLogoPreview(URL.createObjectURL(file));
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!name.trim()) {
      setError("Name is required.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      let newAvatarUrl = avatarUrl;
      if (logoFile) {
        newAvatarUrl = await uploadLogo(logoFile);
      }

      if (isEdit) {
        await updateGame(id, {
          name,
          description,
          rules,
          category,
          isPrivate,
          requireApproval,
          avatarUrl: newAvatarUrl,
        });
        showToast("Game updated", "success");
      } else {
        const newId = await createGame({ name, description, rules, category });
        if (newAvatarUrl) {
          await updateGame(newId, { avatarUrl: newAvatarUrl });
        }
        showToast("Game created", "success");
      }
      navigate("/games");
    } catch (e) {
      setError(e.message || "Save failed.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="state-block">
        <div className="spinner" />
      </div>
    );
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">{isEdit ? `Edit ${name}` : "Create game"}</h1>
          <p className="page-subtitle">
            {isEdit ? "Update this game/community." : "Game = Community, created in one step."}
          </p>
        </div>
        {isEdit && (
          <Link to={`/games/${id}/members`} className="btn btn-ghost">
            View members
          </Link>
        )}
      </div>

      {error && <div className="error-banner">{error}</div>}

      <form onSubmit={submit} className="panel" style={{ padding: 22, maxWidth: 560 }}>
        <div className="field">
          <label className="field-label">Logo</label>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div
              style={{
                width: 56,
                height: 56,
                borderRadius: 12,
                background: "var(--surface-raised)",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                overflow: "hidden",
                flexShrink: 0,
              }}
            >
              {logoPreview || avatarUrl ? (
                <img
                  src={logoPreview || avatarUrl}
                  alt=""
                  style={{ width: "100%", height: "100%", objectFit: "cover" }}
                />
              ) : (
                <span className="muted">{name?.[0]?.toUpperCase() || "?"}</span>
              )}
            </div>
            <input type="file" accept="image/png,image/jpeg,image/gif,image/webp" onChange={onPickLogo} />
          </div>
        </div>

        <div className="field">
          <label className="field-label">Name</label>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} required />
        </div>

        <div className="field">
          <label className="field-label">Description</label>
          <textarea
            className="input"
            rows={3}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>

        <div className="field">
          <label className="field-label">Rules</label>
          <textarea className="input" rows={3} value={rules} onChange={(e) => setRules(e.target.value)} />
        </div>

        <div className="field">
          <label className="field-label">Category</label>
          <select className="input" value={category} onChange={(e) => setCategory(e.target.value)}>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </div>

        {isEdit && (
          <>
            <div className="field" style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <input
                type="checkbox"
                id="isPrivate"
                checked={isPrivate}
                onChange={(e) => setIsPrivate(e.target.checked)}
              />
              <label htmlFor="isPrivate" className="field-label mb-0">
                Private community
              </label>
            </div>
            <div className="field" style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <input
                type="checkbox"
                id="requireApproval"
                checked={requireApproval}
                onChange={(e) => setRequireApproval(e.target.checked)}
              />
              <label htmlFor="requireApproval" className="field-label mb-0">
                Require approval to join
              </label>
            </div>
          </>
        )}

        <div style={{ display: "flex", gap: 10, marginTop: 8 }}>
          <button className="btn btn-primary" disabled={saving}>
            {saving ? "Saving…" : isEdit ? "Save changes" : "Create game"}
          </button>
          <button type="button" className="btn btn-ghost" onClick={() => navigate("/games")}>
            Cancel
          </button>
        </div>
      </form>

      {ToastEl}
    </>
  );
}
