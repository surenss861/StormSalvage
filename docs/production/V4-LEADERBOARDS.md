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

## Reading (server)

1. **Page the index** in descending order, 25 entries per page, up to 4 pages. Keep reading while the 10th-best index seen is ≤ the last index on the page (`Leaderboard.needMore`). Below that point nothing can tie or beat the top 10.
2. **Fetch exact amounts** for the top 10 by index and for every entry sharing an index with them. The cache is keyed by (entry, index), so an unchanged entry costs no further reads.
3. **Verify** each exact amount: its index must equal `Leaderboard.score(exact)` (`Leaderboard.verify`). A stale or tampered pair is not trusted, and that entry ranks by its index amount (exact below a trillion).
4. **Rank** with exact BigMoney comparison (`Leaderboard.rank`). Equal amounts share a rank (competition ranking: 1, 2, 2, 4) and are listed by user id for a stable order.

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
