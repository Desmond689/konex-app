import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { globalSearch } from "../lib/hooks";

export default function CommandPalette() {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState({ users: [], games: [], squads: [] });
  const [loading, setLoading] = useState(false);
  const inputRef = useRef(null);
  const debounceRef = useRef(null);
  const navigate = useNavigate();

  useEffect(() => {
    const onKey = (e) => {
      const isMeta = e.metaKey || e.ctrlKey;
      if (isMeta && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen((o) => !o);
      }
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 30);
    else {
      setQuery("");
      setResults({ users: [], games: [], squads: [] });
    }
  }, [open]);

  useEffect(() => {
    clearTimeout(debounceRef.current);
    if (query.trim().length < 2) {
      setResults({ users: [], games: [], squads: [] });
      return;
    }
    debounceRef.current = setTimeout(async () => {
      setLoading(true);
      try {
        setResults(await globalSearch(query));
      } finally {
        setLoading(false);
      }
    }, 220);
    return () => clearTimeout(debounceRef.current);
  }, [query]);

  const go = (path) => {
    setOpen(false);
    navigate(path);
  };

  if (!open) return null;

  const hasResults = results.users.length || results.games.length || results.squads.length;

  return (
    <div className="modal-backdrop" onClick={() => setOpen(false)}>
      <div className="modal cmdk" onClick={(e) => e.stopPropagation()}>
        <input
          ref={inputRef}
          className="input"
          placeholder="Search users, games, squads… (Esc to close)"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <div className="cmdk-results">
          {loading && <div className="row-sub" style={{ padding: 10 }}>Searching…</div>}
          {!loading && query.trim().length >= 2 && !hasResults && (
            <div className="row-sub" style={{ padding: 10 }}>No matches.</div>
          )}
          {results.users.length > 0 && (
            <>
              <div className="cmdk-group-label">Users</div>
              {results.users.map((u) => (
                <button key={u.id} className="cmdk-item" onClick={() => go("/users")}>
                  @{u.username} {u.gamer_name ? `· ${u.gamer_name}` : ""}
                </button>
              ))}
            </>
          )}
          {results.games.length > 0 && (
            <>
              <div className="cmdk-group-label">Games</div>
              {results.games.map((g) => (
                <button key={g.id} className="cmdk-item" onClick={() => go(`/games/${g.id}`)}>
                  {g.name}
                </button>
              ))}
            </>
          )}
          {results.squads.length > 0 && (
            <>
              <div className="cmdk-group-label">Squads</div>
              {results.squads.map((s) => (
                <button key={s.id} className="cmdk-item" onClick={() => go("/squads")}>
                  {s.name}
                </button>
              ))}
            </>
          )}
          {query.trim().length < 2 && (
            <div className="cmdk-hint">
              <div className="cmdk-group-label">Jump to</div>
              <button className="cmdk-item" onClick={() => go("/")}>Dashboard</button>
              <button className="cmdk-item" onClick={() => go("/reports")}>Report queue</button>
              <button className="cmdk-item" onClick={() => go("/appeals")}>Appeals</button>
              <button className="cmdk-item" onClick={() => go("/analytics")}>Analytics</button>
              <button className="cmdk-item" onClick={() => go("/users")}>Users</button>
              <button className="cmdk-item" onClick={() => go("/squads")}>Squads</button>
              <button className="cmdk-item" onClick={() => go("/games")}>Games</button>
              <button className="cmdk-item" onClick={() => go("/audit")}>Audit log</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
