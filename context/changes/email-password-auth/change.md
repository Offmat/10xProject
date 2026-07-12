---
change_id: email-password-auth
title: Sign up, log in, and log out
status: implemented
created: 2026-07-12
updated: 2026-07-13
archived_at: null
---

## Notes

Roadmap slice **S-01** (@context/foundation/roadmap.md): user can create an account, log in, and log out.

Prerequisites: F-01 (minimal-auth-scaffold — done).

Carry-forward from F-01 impl review: session cookie TTL + server-side active scope; `Session.sweep` (index on `sessions.created_at` already landed); staging `secure:` cookie if needed; ambiguous registration errors (no email enumeration).

Unknowns: Auth views use bare HTML from F-01 scaffold — restyle with daisyUI form/input/btn classes (F-03 done).
