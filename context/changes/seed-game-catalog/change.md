---
change_id: seed-game-catalog
title: Import game catalog from Wikidata (F-02)
created: 2026-06-07
updated: 2026-06-07
status: plan_reviewed
archived_at: null
---

## Notes

F-02 (roadmap): seed ~20 games for dev and S-03 via Rails console. Deliver a reusable operator import service with a **Wikidata adapter** (parameterized batch, `wikidata_id` idempotency, batching/rate courtesy) — not a one-off script — so P-03 can wrap the same service for wide-catalog imports later. Catalog provider switch (e.g. BGG) is post-MVP (P-07), out of this change's scope.
