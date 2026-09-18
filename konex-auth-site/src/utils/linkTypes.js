// Maps the first path segment of an incoming link (e.g. /invite/abc -> "invite")
// to the copy shown while we try to hand off to the app. Add a new entry here
// any time you introduce a new kind of shareable in-app link.
export const LINK_TYPES = {
  invite: {
    title: "You're invited",
    desc: 'Open Konex to accept the invite and add each other as friends.',
  },
  profile: {
    title: 'Opening a profile',
    desc: "We're taking you straight to their Konex profile.",
  },
  post: {
    title: 'Opening a post',
    desc: 'Hang tight — pulling this up inside Konex.',
  },
  party: {
    title: "You've been invited to a party",
    desc: 'Open Konex to jump into the lobby with your friends.',
  },
  game: {
    title: 'Opening a game page',
    desc: "We're taking you to this game inside Konex.",
  },
  default: {
    title: 'Opening in Konex',
    desc: "Redirecting you to the app. If nothing happens, use the buttons below.",
  },
}

export function getLinkType(pathname) {
  const segment = pathname.split('/').filter(Boolean)[0]
  return LINK_TYPES[segment] || LINK_TYPES.default
}
