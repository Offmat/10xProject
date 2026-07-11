---
change_id: seed-game-catalog
title: Import game catalog from Wikidata (F-02)
created: 2026-06-07
updated: 2026-07-11
status: archived
archived_at: 2026-07-11T22:11:08Z
---

## Notes

F-02 (roadmap): seed ~20 games for dev and S-03 via Rails console. Deliver a reusable operator import service with a **Wikidata SPARQL adapter** (parameterized batch via `VALUES` clause, `wikidata_id` idempotency) — not a one-off script — so P-03 can wrap the same service for wide-catalog imports later. Catalog provider switch (e.g. BGG) is post-MVP (P-07), out of this change's scope.

**2026-06-08:** Switched from Action API (`wbgetentities`) to SPARQL Query Service. SPARQL `wdt:` prefix returns truthy (highest-rank, non-deprecated) values directly — eliminated manual rank sorting, snaktype checks, and unit conversion. Mapper reduced from 109 to 63 lines.
