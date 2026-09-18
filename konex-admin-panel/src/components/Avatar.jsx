/**
 * Profile picture with initial fallback when avatar_url is missing.
 */
export default function Avatar({ url, name, size = "md", className = "" }) {
  const sizeClass = size === "sm" ? "avatar-sm" : size === "lg" ? "avatar-lg" : "";
  const initial = (name || "?").trim().charAt(0).toUpperCase() || "?";

  if (url) {
    return (
      <img
        className={`avatar ${sizeClass} ${className}`.trim()}
        src={url}
        alt=""
        loading="lazy"
        referrerPolicy="no-referrer"
        onError={(e) => {
          // Fall back to initials if the image 404s
          e.currentTarget.style.display = "none";
          const fb = e.currentTarget.nextElementSibling;
          if (fb) fb.style.display = "flex";
        }}
      />
    );
  }

  return (
    <div className={`avatar avatar-fallback ${sizeClass} ${className}`.trim()} aria-hidden>
      {initial}
    </div>
  );
}
