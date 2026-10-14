---
related-code:
  - "[[Leaderboard.luau]]"
  - "[[LeaderboardService.luau]]"
  - "[[Wallet.luau]]"
domain: progression
type: spec
status: wip
tags: [storm-salvage, leaderboards, big-numbers, v4]
---

# Leaderboards: exact ranking of 303-digit money

The owner's requirements:
- rank exactly;
- never store 303-digit balances as conventional numeric scores or floats;
- verify on the server;
- handle ties;
- keep purchases off earned-wealth boards;
- keep Studio, LIVETEST and production separate.

## Representation

OrderedDataStores sort int64 values. Money is an exact decimal string of up to 303 digits. Each entry is therefore stored as two records.

| Record | Where | Value |
| --- | --- | --- |
| **Index** | OrderedDataStore `<store>_LB_Lifetime` / `<store>_LB_Week_<YYYYWww>`, key `u_<userId>` | `digits × 10^12 + leading 12 digits` (zero-padded). A whole number below 2^53 (the largest is 303×10^12 + 999,999,999,999), so it is exact as a Luau number and as an int64. Never a float of the balance. |
| **Exact** | DataStore `<store>_LB_Exact`, key `L_<userId>` / `W_<week>_<userId>` | The exact BigMoney string. |

**Why the index can rank:** it is monotone in the amount.
- More digits always gives a higher index.
- With equal digit counts, the leading 12 digits compare the same way the numbers do.
- So `a > b` implies `index(a) ≥ index(b)`.

Equal indexes are possible only above 12 digits, and the exact record resolves them. Unit test: 2,000 random fortunes of up to 303 digits never rank a bigger one lower.

## Reading (server): an exact top N

The index alone is **not** an exact global order: different amounts can share an index (the same digit count and the same first 12 digits), and the store returns tied entries in an order that has nothing to do with their exact amounts. Sorting only the entries fetched would miss a bigger fortune that the store happened to put past the read window (owner review, 2026-10-14). `Leaderboard.topN` therefore reads:

1. **The index, descending, until N entries are known.** The N-th entry's index is the cutoff s\*. Every entry with an index above s\* has now been read, because they come first.
2. **Every entry whose index is exactly s\*,** with a separate filtered query (`GetSortedAsync(false, 25, s*, s*)`, paged), however many there are.
3. **Exact amounts for all of those** (cached, and verified against their index), ranked by exact comparison.

**Why this is exact:** the index is monotone, so a > b implies index(a) ≥ index(b). Any entry not read has an index below s\*, which makes it strictly smaller than every entry read. The candidate set therefore holds the true top N.

**Ties:**
- Equal exact amounts share a rank (1, 2, 2, 4).
- Everyone tied with the N-th place is kept, and the board shows "+k more tied".

**Limit, stated rather than hidden:** the cutoff tie group is read up to 500 entries (TIE_CAP), within a 30-page read budget per board per refresh. If more than 500 players share one 12-digit prefix at the cutoff, the board shows "Huge tie at the cutoff: order near the bottom may vary" and is not claimed exact. Higher ranks stay exact even then, because they are above the cutoff.

## Writing (server only)

- **Source:**
  - All-time: the profile's `Wallet.lifetime`. Earnings only: `Wallet.deposit` (coin packs) adds cash, not lifetime, so purchases cannot inflate either board. Unit test.
  - Weekly: lifetime minus `data.Weekly.Start`, where the record is reset at each ISO week (UTC) or when a restored profile's lifetime falls below the start. It never goes negative.
- **Order:** the exact record first, then the index. A write is recorded as done only when both succeed; otherwise it retries next cycle. A reader therefore never finds an index without its exact amount, except during an in-flight write, when verification falls back to the index.
- **Cadence:** at most one write per board per player every 120 s, only when the index changed, plus a final write on leave.

## Budgets

| Operation | Rate | Limit (per server, per minute) |
| --- | --- | --- |
| OrderedDataStore set | ≤ 2 per player per 2 min (≈ 1/min/player) | 60 + 10 × players |
| DataStore set (exact) | same | 60 + 10 × players |
| GetSortedAsync + pages | 2 boards × ≤ 4 pages per minute = ≤ 8 | 60 + 10 × players |
| DataStore get (exact) | only for changed top entries (cached); worst case about 22 per minute, steady state close to 0 | 60 + 10 × players |

Everything is wrapped in pcall. A failed read keeps the last good board and shows "Leaderboard paused, retrying".

## Weekly rollover

A new ISO week (Monday 00:00 UTC) means a new index store name and new exact keys (`W_<week>_…`), so last week's board stops being shown. Week keys are unit-tested against Python's isocalendar, including the 53-week and year-boundary cases.

## Environments

Store names derive from `Config.DataStoreName`:
- `…_STUDIO` in Studio;
- `…_LIVETEST` on the private test place;
- the real name only on a listed production place.

An unknown place has no DataStore at all, and the board says so.

## Evidence

**Adversarial tests:**
- **Unit test:** 150 fortunes share one index, ordered worst-case by the fake store (biggest last), with 25-entry pages. `topN` returns the true top 10, and the test also proves a first-page shortlist would have missed some of them. A tie scan capped below the group size is flagged not exact. Twelve players tied for first are all shown as first.
- **Studio, real Studio OrderedDataStore (`<store>_LB_QA`, never shown on a board):** 40 fortunes share one index, with ids chosen so the biggest sort last by key, plus a 26-digit leader. Result: 1 leader, then the 9 largest of the tied group (1040…1032) in exact order, in 3 reads.

**Unit tests (`leaderboard.spec.luau`):**
- index order across magnitudes and 2,000 random 303-digit pairs;
- round trips;
- exact tie resolution with shared ranks;
- a mismatched exact amount rejected;
- the paging stop rule;
- purchases never counted;
- ISO weeks;
- weekly reset rules.

**Studio (STUDIO store):** the board showed "1. FrankMevash · 62.7Qi" all-time and "9.37M" this week. The exact record held the 20-digit lifetime 62,728,394,507,389,605,542, and its index (20,627,283,945,073) verified.

**Not verified:**
- Live-server persistence across servers.
- Behaviour under DataStore throttling. The code handles it with retries and a paused board, but this hasn't been exercised against real limits.
