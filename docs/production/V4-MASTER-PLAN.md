---
related-code:
  - "[[PursuitService.luau]]"
  - "[[Movement.luau]]"
domain: core
type: readme
status: wip
tags: [storm-salvage, core, v4]
---

# Storm Salvage V4: master plan and phase tracker

This is the owner's **V4 Complete Game Production Directive** (2026-10-14), turned into a dependency-ordered plan.

**Approved:** autonomous work through all ten phases on `v4-gameplay`.

**Approval gates that never move:**
- public release
- real Robux activation or spending
- irreversible or destructive data changes (namespace switch, resets, migrations)
- architectural changes with major compatibility cost
- major design pivots

**Baselines:**
- RC7 (`rc-20261013-7` @ `e3d1ab9`) is live privately and is the rollback target.
- `main` stays `0ef9465`.
- A playable private release candidate is cut after each major milestone.

## Order and dependencies

Core experience → gameplay systems → world and content → reliability → polish → monetization → release. Security, multiplayer correctness, mobile performance and save compatibility are checked **in every phase**, not saved for the end.

| # | Phase | Depends on | Status |
| --- | --- | --- | --- |
| A | Movement and controls (run/sprint, conflicts, one evasive action, animations) | none | **In progress.** Run/sprint built. Shift Lock and state fixes in milestone 1. Evasive action next. Custom animations blocked: they need uploaded animation assets (see Blockers). |
| B | Signature pursuit system (pursuer, routes, locations, event catalog, multiplayer, records) | A | **In progress, milestone 1.** Route-bound pursuer, 5 locations, 3 event types with a scheduler, pursuer states and visuals, records. |
| C | High-value salvage and reward moments (rarity ladder, opportunities, feedback, fairness) | B (events carry the big rewards) | Next |
| D | World and traversal (audit Gale Hollow, district hooks, routes, then new districts) | B, C (routes serve events) | Planned |
| E | Weather, VFX, GFX and sound (storm identities, pursuit effects, audio hierarchy, quality tiers) | B, D | Planned |
| F | Large-scale economy (bands, safe integers, formatter, sinks, migration plan) | C | Design done (`V4-ECONOMY.md`). Build after C. Namespace decision is an **owner gate**. |
| G | Status and social (titles, inspect card, leaderboards, prestige cosmetics) | B (records), F (wealth) | Design done (`V4-STATUS.md`) |
| H | Equipment and monetization (tools, Robux catalog review, premium cosmetics) | F, G | Planned. **Activation is an owner gate.** |
| I | UI/UX, onboarding, full polish | All gameplay phases | Ongoing per feature, final pass planned |
| J | Multiplayer, performance, release (real servers, devices, security, observability) | Every milestone | Ongoing. Device and real-server runs need the owner's hands. |

## Milestones (each ends with a private RC candidate and a report)

1. **M1: Controls and the pursuit system.** A fixes, B1–B5, B7, and B6 as far as Studio allows. *Current.*
2. **M2: Rewards worth chasing.** C, plus the A3 evasive action.
3. **M3: Gale Hollow alive.** D1, D2, D5, plus E for pursuits and storms.
4. **M4: The long chase.** F bands 1–2, plus G slice (titles and inspect card).
5. **M5: Shop and polish.** H review, I pass, and E quality tiers.
6. **M6: Release readiness.** J on real servers and devices.

## Blockers needing the owner (tracked, not worked around)

- **Custom character animations:** Roblox animations must be uploaded as assets by the account. I can author them in Studio (KeyframeSequences), but uploading needs the owner (or an approved upload step). Until then the default Roblox animations stay as the fallback. No animation IDs will be invented.
- **Physical phones and real multi-player servers:** these need the owner's devices and people. Studio's two-client test wouldn't start on two attempts.
- **Live Robux** and **a V4 save namespace**: owner gates.

## Rules carried forward

- Server-authoritative, idempotent rewards.
- Session-locked saves, receipt safety, test-save isolation.
- No paid advantages in chases.
- No fabricated evidence.
- No public publishing.
- Inspect the exact CI-built `.rbxl` file before any publish.
