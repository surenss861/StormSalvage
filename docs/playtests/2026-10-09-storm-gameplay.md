# Studio test: storm gameplay refinement (2026-10-08/09)

Priority 2: make Wind, Flood and Lightning ask for different decisions. Tested in Roblox Studio
over the MCP connection, in solo Play and in a `StudioTestService` session with 2 clients,
plus 2 more who joined during storms. Screenshots are in
[`../qa-screenshots/v4/`](../qa-screenshots/v4/).

All measurements below come from the new `StormStats` records (see "Instrumentation") or
from client logs. "Idle" means a test character standing still for the whole storm; it shows
what happens to someone who ignores the storm, not how real players behave.

## What changed

### Windstorm: gusts and lulls

- Steady wind is now gentle (push 30, was a constant 110). Every 4–6 s there's a
  **2 s gust warning, then a 3.5 s gust** (push 150), with debris thrown about 4× faster
  and mostly aimed at exposed players.
- The server schedules gusts and sends `GustAt`/`GustEnd` in the storm state (server time),
  so every client shows the same warning and gust.
- **Debris now actually reaches its target.** It was launched flat from 70 studs away and fell
  short under Roblox gravity (a player idle in the open for a whole windstorm took only 14
  damage). Debris now flies a calculated arc that lands where it was aimed.
- Banner: "Lull: move now! Next gust in 5s" → "Gust in 1.7s - get behind a wall!" →
  "GUST! Hold cover 3s". Exposed players also get a personal alert line.
- Trees and bushes lean downwind, harder in gusts (client-side, off in Reduced Effects).
  Wind streaks and wind volume rise during gusts.

### Flash Flood: elevation and timing

- **The Houses district had no way up.** Interiors flood (floors are at 1, water rises to 12),
  and the four houses had no ladder; the nearest high ground was about 150 studs away. Each
  house now has a ladder on its back wall like the other buildings, plus invisible collision
  matching the pitched shell roof. Tested with real keyboard input: a player climbed in
  about 1.3 s and stood on the visible roof (screenshot `house-roof-standing.jpg`).
- Water now waits 4 s before the first rise, then rises every 6 s (4 → 8 → 12 at 4 s, 10 s,
  16 s). The rise schedule is sent to clients.
- Banner: "Water 4/12 - rising in 2s" → "Water at its peak - stay high".
- "▲ CLIMB" markers above every ladder and "▲ HIGH GROUND" over the ramp, shown during
  the flood warning and the flood.
- Personal alerts: "Below the flood line - get to a ▲ ladder or high ground", then "You're in
  the flood! Climb a ▲ ladder or head uphill".
- The tutorial hint ("Head down into town...") is hidden during storm warnings and storms.
  It was bad advice then and overlapped the storm warning toast.

### Lightning: dodgeable strikes

- Warning 2.0 s (was 1.6), strikes every 1.1–1.7 s (was 0.8–1.4).
- **No overlapping danger zones.** A new strike is never placed within 22 studs of a pending
  one, and a player is never targeted twice at once, so stepping out of one zone can't put
  you in another.
- The full red danger zone shows from the first frame (it used to grow from nothing, so you
  couldn't tell how far to run); a yellow core fills it as the strike nears. A faint beam marks
  the spot from across town. Impact leaves a scorch mark and sparks.
- Personal alert: "MOVE! Lightning is about to strike here".

### Shared

- Storm warning hints rewritten to say what to do in each storm.
- **Reduced Effects** toggle (bottom of the Gear Shop for now): no lightning screen flash, no
  tree sway, half the wind streaks.
- Storm presentation moved out of `Main.client.luau` into `src/client/StormEffects.luau`.
- All new values are in `Config.StormTuning`. The 45 s storm and the cycle are unchanged.

### Also fixed

- **Solo Play kicked the player.** In solo Play, DataStore requests fail with HTTP 401, which
  DataService treated as a temporary error: six retries, then a kick. In Studio, any load
  failure now gives a temporary profile. Live servers still retry and then refuse.

## Tuning values

| Value | Before | Now |
| --- | --- | --- |
| Wind push | 110 constant | 30 steady, 150 in gusts |
| Gusts | none | 2 s warning, 3.5 s gust, 4–6 s lull |
| Debris interval | 0.3 s | 1.0 s lull / 0.22 s gust |
| Debris aim | flat throw, fell short | arc to a point within 6 studs of the player |
| Flood rise | 4 → 8 → 12 at 0, 6, 12 s | 4 → 8 → 12 at 4, 10, 16 s |
| Lightning warning | 1.6 s | 2.0 s |
| Lightning interval | 0.8–1.4 s | 1.1–1.7 s |
| Lightning spacing | none | pending zones ≥ 22 studs apart |

## Results

### Each storm needs a different response

| Storm | Test | Result |
| --- | --- | --- |
| Wind | Idle in the open (two runs) | 84 damage (survived), and 140 damage with 1 death |
| Wind | Indoors, whole storm | 0 damage, no push |
| Wind | Walking speed, lull | about 13 studs/s in every direction |
| Wind | Walking speed, gust | about 10.5 into the wind, 15 with it |
| Flood | Idle on the ground in the plaza | drowned at about 28 s |
| Flood | Indoors (Supermarket) | drowned at about 29 s |
| Flood | On a house roof | 0 damage, survival bonus paid |
| Flood | Storm Core while swimming at full water | grabbed from the surface (10 studs away, reach 16); player left at 27 HP |
| Lightning | Idle in the open | 280 damage, 2 deaths (8 strikes) |
| Lightning | Bot that walks out of any zone it's in, sidestepping if blocked | **0 damage** from 11 strikes aimed at it; escapes took 0.5–1.2 s of the 2.0 s warning |
| Lightning | Indoors | 0 damage |

A simpler bot that only walked straight away took 3 hits (105 damage); each was a time it
walked into the fountain or a bench. So dodging works at default speed, but a blocked path
costs a hit.

### Flood escape routes at default speed (16)

Walking time from a grid of points on every building floor (like the loot grid) and the
Town Square loot points, to the nearest ladder or the ramp. Uses PathfindingService path
lengths, plus about 1.5 s to climb.

| District | Points | Median | Worst |
| --- | --- | --- | --- |
| Houses | 36 | 5.0 s | 7.0 s |
| Town Square | 32 | 6.3 s | 8.3 s |
| Gas Station | 20 | 6.8 s | 7.6 s |
| Motel | 60 | 8.8 s | 10.4 s |
| Supermarket | 63 | 12.4 s | 15.9 s |
| Warehouse | 72 | 12.3 s | 14.8 s |

From the storm warning (12 s) to the first water a player stands in, there's 16 s outdoors
and 22 s indoors. Every route fits. A player who waits for the storm to start has 4 s
outdoors and 10 s indoors, plus about 20 s of health in the water.

### Multiplayer (2 clients plus 2 late joiners)

| Check | Result |
| --- | --- |
| Gust timing | **Pass**: both clients got identical `GustAt`/`GustEnd` for all 5 gusts. |
| Lightning | **Pass**: 3 clients got the same 32 warnings in the same order and positions. Concurrent zones were at least 46 studs apart (minimum allowed 22). Intervals 1.12–1.70 s. |
| Flood | **Pass**: Player4 joined at water level 8 and immediately showed "Water at its peak - stay high \| 13s", the same as Player2, with all 9 ladder markers on. |
| Survival bonus | **Pass**: +25 exactly once per storm, only to players who qualified (sheltered or on a roof); none for players who died or stayed on the hill. |
| Effects after death and respawn | **Pass**: dead players respawned on the hill; StormStats counted one death each. |
| Same loot, two players | **Pass**: one player got it. |
| Simultaneous selling | **Pass**: correct coins, and StormStats counted the sale. |
| Protected bag | **Pass**: refused early, picked up after 21 s. |

### Server performance (4 players, windstorm)

1,210 heartbeat samples over 20 s: median 16.7 ms, p99 17.6 ms, max 18.0 ms. At most 15
debris parts alive at once; 1,851 parts total. The earlier windstorm baseline was median
16.6 ms, p99 20.0 ms. Client frame rate was 60 fps in Studio on a Mac; no phone was tested.

## Instrumentation

`src/server/StormStats.luau` keeps one record per storm (covering the storm and the calm
after it). Per player it tracks damage taken after armor, deaths, seconds exposed, sheltered
and in town, whether they earned the survival bonus, salvage and Storm Cores picked up, coins
from selling, and whether they played the next storm too. Exposure is sampled once per
second; the server prints one summary line per storm. In Studio,
`ServerStorage.StormSalvageDebug:Invoke("stats")` returns the last 20 records.

## Not verified

- **Sound.** Wind volume rises in gusts and thunder is delayed by distance, but I couldn't
  listen. All three storms still use the same warning siren; a distinct sound per storm needs
  sounds chosen by ear.
- **Tree sway and wind streaks** weren't clearly visible in Studio captures. The code runs
  without errors, but someone should look in a real Play session.
- **AlwaysOnTop markers.** Studio captures didn't show "▲ CLIMB" markers drawn on top of
  walls or kept in a loose folder, so they're now parented to the ladder and drawn in the
  world. They may be hidden behind buildings from some angles.
- **Phones and real players.** Touch dodging, readability on small screens and how real players
  respond are untested.
- **Climbing with scripted movement is slow** (about 1.5 studs/s), but real keyboard input
  climbs at about 12 studs/s. Bots that climb won't reflect real timing.
