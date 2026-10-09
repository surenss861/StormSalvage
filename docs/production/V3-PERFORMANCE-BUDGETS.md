# Storm Salvage V3: performance budgets and acceptance gates

**Status:** proposed engineering contract, 2026-10-09. Every threshold here is a
**project-defined starting target**, not a Roblox platform limit and not proof of measured
performance. Recalibrate against a physical low-end baseline device once reproducible
measurements exist. Never loosen a threshold silently: log the exception and its measured impact.

**Baseline commit:** `0ef9465` (V2 UI and art), with the playable world kept for before/after
comparison. **Scope:** V3 art-direction studies, the Scrapyard + Town Square vertical slice,
then district-by-district rebuild and the UI art pass.

## A. Measurement definitions

- **Physical low-end device:** a real 3–4 GB Android phone (Galaxy A16 if available). Record SoC,
  RAM, OS version, Roblox app build, battery mode and graphics level. If unavailable, use an
  equivalent inexpensive device and declare the substitution.
- **Mid device:** a representative mid-range iPhone or Android; record model and graphics quality.
- **High device:** modern desktop or premium phone, tested in the standalone Roblox client, not Studio.
- **FPS:** frames presented by the **client**, not Studio's client heartbeat, script time, or the
  server `Heartbeat` interval. Compute 1-second FPS windows and frame-time quantiles per scenario.
- **p95/p99 frame time:** 95th/99th percentile of actual frame durations (p95 = 40 ms means 95% of
  frames take 40 ms or less; it doesn't mean the average is 25 fps).
- **Join-to-playable:** from tapping Play until the player can move and see/interact with a real
  salvage item, including asset loading and profile wait. Not `game.Loaded`.
- **Memory:** total client memory plus per-place graphics mesh/texture/script memory from the
  standalone client's Developer Console, after warm-up and at peak.
- **Visual budgets:** measured in the **visible rendered scene** or streamed-in local instances at
  the stated camera and graphics quality, not summed across all Blender exports.
- **Server frame CPU:** actual work time from MicroProfiler/Developer Console. A 16.7 ms
  `Heartbeat` interval is 60 Hz scheduling, not 16.7 ms of CPU work.

## B. Client performance gates (15-minute physical-device run)

| Device / profile | FPS in ≥90% of 1 s windows | p95 frame | p99 frame | 15-min thermal degradation |
|---|---:|---:|---:|---:|
| Entry Android, graphics 2–3 | ≥30 | ≤40 ms | ≤66.7 ms | ≤15% vs warmed-up matched segment |
| Mid-range phone, graphics 5–6 | ≥45 | ≤30 ms | ≤50 ms | ≤15% |
| Capable desktop / premium phone, graphics 7–8 | ≥58* (target 60) | ≤22 ms | ≤33.3 ms | ≤10% |

\*Test with a 60 fps cap. If a frame limiter, display refresh, platform cap or thermal policy
prevents a 60 fps measurement, label the 60 fps gate **inconclusive** and report the cap.

**Hard fails at every tier:** a reproducible client crash, memory exhaustion, repeated gameplay
freezes ≥250 ms (other than labelled loading/streaming events), unresponsive controls, or hazards
that can't be dodged because of rendering or input stalls.

## C. Low-end graphics and asset budgets (preliminary)

| Measured metric | Preferred | Review / block new detail above |
|---|---:|---:|
| Draw calls, worst active view (p95) | ≤600 | >900 |
| Visible scene triangles (p95) | ≤400,000 | >800,000 |
| Locally loaded `BasePart` + `MeshPart` count (p95) | ≤5,000 | >7,000 |
| Client `GraphicsTexture` memory | ≤100 MiB | >140 MiB |
| Client `GraphicsMeshParts` memory | ≤100 MiB | >140 MiB |
| Active particle emitters in near view | ≤20 | >35 |
| Approx. visible particles (rate × lifetime / burst accounting) | ≤200 | >350 |

Roblox exposes frame, draw and triangle information through its graphics/debug statistics, and
mesh/texture memory through the Developer Console. **The exact rendered particle count isn't a
stable gameplay counter**, so the particle budget is an estimate to confirm with effects on/off
frame-time profiling. CPU/GPU frame time is the final judge.

**Per-asset triangle guidelines:** repeated small prop 100–500; ordinary interactive item
500–2,000; modular facade 1,000–4,000; building module 2,000–6,000; hero landmark up to 10,000
with a justification and a device test. These are authoring preferences, not engine limits.
Prefer reuse and trim-sheet atlases over unique materials and IDs.

**Textures:** small decals/props 256–512 px; major reusable trim sheets and hero materials
≤1,024 px per side. Anything larger needs a documented benefit and a low-end texture-memory
check. Use built-in materials for distant or minor surfaces. Keep most small lights
non-shadow-casting on low quality; avoid dense transparency layers and broad weather particle fills.

**Scene count rule:** capture five worst-view cameras at the same FOV and quality (Scrapyard
crane/shops, Town Square fountain and clock tower, supermarket shelves, warehouse interior,
motel corridor), plus each active weather phase. No view may be hidden inside an average.

## D. Memory and load time

| Metric | Target | Stop and investigate |
|---|---:|---:|
| Low-end total client memory after warm-up | ≤850 MiB | >1,100 MiB or a low-memory warning |
| Low-end PlaceMemory (game content) | ≤350 MiB | >500 MiB |
| Memory growth, minute 5 to 20, same route | ≤50 MiB | >100 MiB |
| Low-end join-to-playable, home Wi-Fi (median of ≥5 cold joins) | ≤10 s | >18 s p95 |
| Mid/high join-to-playable (median of ≥5 cold joins) | ≤6 s | >12 s p95 |

The MiB values are provisional. If the V2 game already exceeds them on the chosen phone, record
the baseline and headroom and revise the target explicitly. A low-memory warning or OOM crash
always fails. Never compare Studio memory totals with standalone client totals.

If streaming is used, every gameplay-critical shelter roof, ladder, collision barrier, pickup and
safe route must still work as decoration streams in and out. No pop-in of critical interactive
elements within 30 studs during normal movement.

## E. Server budgets (initial target: 12 concurrent players)

| Metric | Target | Escalate when |
|---|---:|---:|
| Server heartbeat | ≥58 updates/s in ≥99% of 10 s windows | Repeatedly <55/s |
| Server frame CPU p95 / p99 | ≤10 ms / ≤14 ms | Sustained >16.67 ms frames |
| Storm script work p95 | ≤2 ms/frame | >4 ms/frame over repeated storms |
| Server memory | <2 GiB, and <50% of available | ≥3 GiB, near-limit, or a sustained leak |
| Memory retained after two join/leave waves | ≤100 MiB net after settling | >150 MiB unexplained |
| Moving debris pieces | ≤20 at once | >35 without a documented measurement |

12 players is a design proposal, not evidence the place is configured for it. Test solo, 4 and 8
clients in Studio, then verify 12 in a separately published test experience with independent
clients before setting production capacity. If it fails, lower the cap and document it.

## F. Replication, interactions and UI

| Measurement | Target | Failure |
|---|---:|---|
| Steady downstream traffic per client (after first asset load) | ≤25 KiB/s average | >60 KiB/s p95 unexplained |
| Game-authored reliable remote events to one client | ≤10/s sustained | Per-frame storm/network spam |
| Cosmetic + storm client script cost on low end (MicroProfiler, p95) | ≤2 ms combined | >4 ms |
| Visual response to a button tap or pickup prompt | ≤100 ms p95, local | Interactions look dead or block touch controls |
| Server-confirmed pickup/sale at ≤100 ms RTT | ≤300 ms p95 | >500 ms without a loading/error state |
| Constrained network: 150 ms RTT, ~30 ms jitter, 1% loss | Works | Duplicate money/items, stuck storm state, impossible prompts |

Don't apply traffic targets to avatar/asset download bursts, or blame real-world ping on game
logic. Track data ping minus network ping and investigate persistent replication queueing. Never
predict paid grants or money authoritatively on the client.

## G. Repeatable scenario matrix

Same commit, camera, player count, graphics level and recording method for every V2-vs-V3 comparison:

1. **Cold join:** 5 joins per device, Play to first movable avatar and visible collectible.
2. **Scrapyard idle and selling:** 2 min; open shop, upgrade, sell a full bag, watch the receipt.
3. **Town Square scavenging:** 2 min; collect rares and a Storm Core.
4. **Wind:** a full gust cycle with debris and foliage in a dense street (2 min).
5. **Flood:** rise to peak, swim, climb a ladder, return (2 min).
6. **Lightning:** dodge warnings in Town Square, see localized effects (2 min).
7. **Dense interiors:** supermarket, warehouse, motel (2 min).
8. **Soak:** 20-minute loop through every storm phase with two full join/leave waves.

Use the performance overlay for FPS and visual stats, the MicroProfiler for CPU/GPU bottlenecks,
and memory breakdowns at minutes 5, 15 and 20. Test touch and volume panels with a real finger.
Record quality level, resolution, brightness, device temperature/charging, Roblox build and
connectivity.

## H. Regression approvals

- Every V3 hero asset must show a screenshot/readability improvement **and** its measured
  worst-view cost. No visual gain, no extra cost.
- Exceeding a "preferred" value starts optimization before more detail goes into that area.
  Crossing a "stop" value blocks promoting the vertical slice until fixed, or until an
  exception is accepted with real device data.
- V3 can't pass on Studio heartbeats, compilation, Blender previews or simulated mobile layouts.
- Comparisons keep identical graphics settings and routes; never lower graphics quality to hide
  a regression.
- Cut shadowed lights, duplicated mesh/material IDs, unique high-res textures, transparency layers
  and high-frequency weather particles before removing recognizable hero architecture.
- Automated server and script checks may pass in Studio; client FPS, memory and thermal gates stay
  **UNVERIFIED** until physical-device QA.
- If content streams, test collision, shelter and loot both before and after it streams in.

## I. Evidence format for every art/environment merge

One record per device and scenario: `commit`, `experience_place_version`, `device`, `RAM`,
`quality_level`, `scenario`, `player_count`, `duration_seconds`, `fps_1s_p10`, `fps_1s_median`,
`frame_ms_p95`, `frame_ms_p99`, `draw_calls_p95`, `triangles_p95`, `client_memory_mib_peak`,
`place_memory_mib_peak`, `mesh_memory_mib_peak`, `texture_memory_mib_peak`,
`join_to_playable_s`, `server_heartbeat_per_sec_p10`, `server_cpu_ms_p95`, `notes`,
`verified_by`, `test_environment`.

A blank measurement is **NOT TESTED**, never zero. Never combine server and client timing into one
"FPS". Keep cold and warm runs separate.

## J. Official references

- https://create.roblox.com/docs/performance-optimization
- https://create.roblox.com/docs/performance-optimization/design
- https://create.roblox.com/docs/performance-optimization/identify
- https://create.roblox.com/docs/performance-optimization/test-on-hardware
- https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler
- https://create.roblox.com/docs/performance-optimization/improve
- https://create.roblox.com/docs/production/analytics/performance
