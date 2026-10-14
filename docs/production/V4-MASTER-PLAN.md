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
| A | Movement and controls (run/sprint, conflicts, one evasive action, animations) | none | **M1 done:** run/sprint plus the Shift Lock, state and focus fixes. **M2 done (Studio):** the dodge, server-checked (cooldown, ground, movement plausibility), fair under measured latency. Three animations authored and validated on the R15 rig; **waiting on the owner's upload** (`docs/art/v4/ANIMATIONS.md`). Controller and phone unverified. |
| B | Signature pursuit system (pursuer, routes, locations, event catalog, multiplayer, records) | A | **M1 done in Studio:** route-bound twister, 5 self-checking sites, Pursuit/Extraction/Rush with a scheduler, pursuer states and visuals, own strike VFX, records. **Open:** real multi-client play (B6). |
| C | High-value salvage and reward moments (rarity ladder, opportunities, feedback, fairness) | B (events carry the big rewards) | **M2 done (Studio):** Golden Storm Core (own model, 600, 15%), Salvage Log screen with lifetime counts, extraction receipt. Evidence in `V4-GAMEPLAY.md` M2 part 2. |
| D | World and traversal (audit Gale Hollow, district hooks, routes, then new districts) | B, C (routes serve events) | Planned |
| E | Weather, VFX, GFX and sound (storm identities, pursuit effects, audio hierarchy, quality tiers) | B, D | Planned |
| F | Large-scale economy (bands, safe integers, formatter, sinks, migration plan) | C | **First slice built (Studio), M3:** safe integers capped at 1 Qa, compact formatter, three modelled curves (built: first 1M at about 2.2 h vs 10.9 h), band 2 (Pro licence, industrial salvage, Salvage Press, band-sized bonuses). Bands 3–5 designed only. Namespace decision is an **owner gate**. Report: `V4-M3.md`. |
| G | Status and social (titles, inspect card, leaderboards, prestige cosmetics) | B (records), F (wealth) | **First slice built (Studio), M3:** 9 server-granted titles (skill, discovery, career, wealth), title on the nameplate, inspectable player card. Leaderboards and prestige cosmetics later. |
| H | Equipment and monetization (tools, Robux catalog review, premium cosmetics) | F, G | Planned. **Activation is an owner gate.** |
| I | UI/UX, onboarding, full polish | All gameplay phases | Ongoing per feature, final pass planned |
| J | Multiplayer, performance, release (real servers, devices, security, observability) | Every milestone | Ongoing. Device and real-server runs need the owner's hands. |

## Milestones (each ends with a private RC candidate and a report)

1. **M1: Controls and the pursuit system.** A fixes, B1–B5, B7. **Done (Studio), 2026-10-14**; B6 needs real clients.
2. **M2: Rewards worth chasing.** C, plus the A3 evasive action. **Done in Studio, 2026-10-14**; candidate RC9 (`rc-20261014-9`), not deployed. Owner items: animation uploads, device and controller checks.
3. **M3: Large-scale economy and status** (re-ordered by the M2 and RC9 reviews). F and G first slices. **Built in Studio, 2026-10-14**; candidate RC10, not deployed (`V4-M3.md`).
4. **M4: Gale Hollow alive.** D1, D2, D5, plus E for pursuits and storms; more bands (3+) with their own content and sinks.
5. **M5: Shop and polish.** H review (the Robux catalogue against the new bands: an owner gate), I pass, and E quality tiers.
6. **M6: Release readiness.** J on real servers and devices.

## Blockers needing the owner (tracked, not worked around)

- **Custom character animations:** authored and validated (Dodge, CoreCarry, Celebrate), **waiting on the owner's upload**: about 10 minutes, steps in `docs/art/v4/ANIMATIONS.md`. Until then the fallbacks play. No animation IDs will be invented.
- **Physical phones and real multi-player servers:** these need the owner's devices and people. Studio's two-client test wouldn't start on two attempts.
- **Live Robux** and **a V4 save namespace**: owner gates.

## Rules carried forward

- Server-authoritative, idempotent rewards.
- Session-locked saves, receipt safety, test-save isolation.
- No paid advantages in chases.
- No fabricated evidence.
- No public publishing.
- Inspect the exact CI-built `.rbxl` file before any publish.
