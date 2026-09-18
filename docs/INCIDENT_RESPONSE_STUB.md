# Incident response (stub — expand before due diligence)

1. **Key leak**: rotate Supabase anon/service keys immediately; force sign-out all sessions; notify users if PII exposed.
2. **Who is paged**: [TBD — founder / backend lead].
3. **User notification**: email + in-app banner within 72h where required by law.
4. **Preserve logs**: do not wipe audit tables during investigation.
5. **Post-mortem**: document timeline, root cause, fix, prevention within 7 days.
