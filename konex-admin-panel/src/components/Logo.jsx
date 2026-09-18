export default function Logo({ size = 26 }) {
  return (
    <img
      src="/logo.png"
      alt="Konex"
      width={size}
      height={size}
      style={{
        borderRadius: Math.max(6, Math.round(size * 0.22)),
        objectFit: "cover",
        display: "block",
      }}
    />
  );
}
