// A quiet field of drifting connection-lines behind the page — players as nodes,
// friendships as edges. Deterministic (seeded) so it doesn't jump on re-render.
const NODES = [
  [6, 12], [18, 6], [30, 18], [46, 8], [62, 16], [80, 10], [94, 22],
  [10, 34], [26, 40], [42, 32], [58, 42], [74, 36], [90, 46],
  [4, 58], [20, 64], [36, 56], [52, 66], [68, 60], [86, 68],
  [14, 84], [32, 90], [48, 82], [64, 92], [82, 86], [96, 78],
]

const EDGES = [
  [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6],
  [0, 7], [1, 8], [2, 9], [3, 10], [4, 11], [5, 12],
  [7, 8], [8, 9], [9, 10], [10, 11], [11, 12],
  [7, 13], [8, 14], [9, 15], [10, 16], [11, 17], [12, 18],
  [13, 14], [14, 15], [15, 16], [16, 17], [17, 18],
  [13, 19], [14, 20], [15, 21], [16, 22], [17, 23], [18, 24],
  [19, 20], [20, 21], [21, 22], [22, 23], [23, 24],
]

export default function ConstellationField() {
  return (
    <svg
      className="field"
      viewBox="0 0 100 100"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
    >
      <g stroke="#5b48a8" strokeWidth="0.12" opacity="0.6">
        {EDGES.map(([a, b], i) => {
          const [x1, y1] = NODES[a]
          const [x2, y2] = NODES[b]
          return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} />
        })}
      </g>
      <g>
        {NODES.map(([x, y], i) => (
          <circle
            key={i}
            className={i % 5 === 0 ? 'pulse' : ''}
            cx={x}
            cy={y}
            r={i % 5 === 0 ? 0.55 : 0.32}
            fill={i % 7 === 0 ? '#ff6a4d' : '#8c6bff'}
            style={{ animationDelay: `${(i * 0.37) % 5}s` }}
          />
        ))}
      </g>
    </svg>
  )
}
