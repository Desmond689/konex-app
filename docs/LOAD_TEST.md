# Load testing notes (Batch 13)

## Goals
- Supabase connection pool under concurrent users
- Realtime channel fan-out (chat + notifications) during peak tournament check-in
- Feed pagination latency at 15 posts/page

## Suggested approach
1. **k6** or **Artillery** against REST via anon key + test users (never production data).
2. Scenario A: 500 virtual users open feed + scroll 5 pages.
3. Scenario B: 100 users join tournament entry endpoint (rate-limited).
4. Scenario C: 50 concurrent Realtime subscriptions on one squad chat.

## Metrics to capture
- p95 latency for feed and entry
- Error rate (especially 429 from rate limits)
- Supabase dashboard: connections, Realtime presence

## Pass criteria (example)
- Error rate < 1% under target concurrency
- p95 feed < 800ms from edge region near Cameroon users if possible
