import { useEffect, useRef, useState } from "react";
<<<<<<< HEAD
import { Link, useNavigate } from "react-router-dom";
import { listAllGames } from "../lib/hooks";

export default function Games() {
  const navigate = useNavigate();
=======
import { Link } from "react-router-dom";
import { listAllGames } from "../lib/hooks";

export default function Games() {
>>>>>>> origin/main
  const [query, setQuery] = useState("");
  const [games, setGames] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const debounceRef = useRef(null);

  const load = async (q) => {
    setLoading(true);
    setError(null);
    try {
      setGames(await listAllGames(q || undefined));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load("");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => load(query), 300);
    return () => clearTimeout(debounceRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Games</h1>
          <p className="page-subtitle">Every game/community, highest members first. Tap one to edit.</p>
        </div>
        <Link to="/games/new" className="btn btn-primary">
          + Create game
        </Link>
      </div>

      <div className="search-row" style={{ marginBottom: 20 }}>
        <input
          className="input"
          placeholder="Search games…"
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
        ) : games.length === 0 ? (
          <div className="state-block">
            <div className="state-block-title">{query ? "No matches" : "No games yet"}</div>
            <div className="state-block-sub">
              {query ? `No game matches "${query}".` : "Create the first one."}
            </div>
          </div>
        ) : (
          games.map((g) => (
<<<<<<< HEAD
            <div className="row" key={g.id}>
=======
            <Link
              to={`/games/${g.id}`}
              className="row"
              key={g.id}
              style={{ textDecoration: "none", color: "inherit" }}
            >
>>>>>>> origin/main
              <div
                style={{
                  width: 38,
                  height: 38,
                  borderRadius: 9,
                  background: "var(--surface-raised)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  fontWeight: 700,
                  flexShrink: 0,
                  overflow: "hidden",
                }}
              >
                {g.avatar_url ? (
                  <img src={g.avatar_url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                ) : (
                  g.name?.[0]?.toUpperCase() || "?"
                )}
              </div>
              <div className="row-main">
                <div className="row-title">
                  {g.name}
                  {g.is_official && <span className="pill pill-verified">official</span>}
                </div>
                <div className="row-sub">
                  {g.member_count ?? 0} members{g.category ? ` · ${g.category}` : ""}
                </div>
              </div>
<<<<<<< HEAD
              <div className="row-actions">
                <Link to={`/games/${g.id}/members`} className="btn btn-ghost btn-sm">
                  Members
                </Link>
                <button className="btn btn-ghost btn-sm" onClick={() => navigate(`/games/${g.id}`)}>
                  Edit →
                </button>
              </div>
            </div>
=======
              <span className="muted">Edit →</span>
            </Link>
>>>>>>> origin/main
          ))
        )}
      </div>
    </>
  );
}
