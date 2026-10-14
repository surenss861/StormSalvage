---
related-code:
  - "[[Coop.luau]]"
  - "[[WreckService.luau]]"
  - "[[TitanService.luau]]"
  - "[[LootService.luau]]"
domain: progression
type: spec
status: wip
tags: [storm-salvage, multiplayer, rewards, v4]
---

# Cooperative rewards (Armored Wreck, Storm Titan)

The owner's rule: reward meaningful participation, not presence. No AFK farming, duplicate rewards, last-second freeloading or duplication across disconnects. Jackpots stay exciting, but trying and missing is never wasted.

## Armored Wreck

| Rule | How |
| --- | --- |
| **Work, not presence** | Work is the cut progress a player actually added to a lock while in reach: the lock's gain each tick, split among its cutters by their cutter speed. Standing nearby or watching adds nothing. Stepping out to dodge pauses it. |
| **AFK can't farm** | Cutting needs the lock pressed and the player in reach. Security charges keep hitting cutters, and a hit stops the cut until it's pressed again, so an AFK cutter stops quickly. |
| **Strongbox (per lock)** | Goes to whoever cut most of that lock, as an owner-only share. Everyone with at least `MinShare` (10%) of that lock gets the lock on their record. |
| **Vault bars** | `Bands.barsFor(eligible contributors)`. Split by work among everyone with ≥10% of all the cutting (`Coop.shares`: one each first, then largest remainder). They are spawned as owner-only shares at each contributor's feet. Each contributor is told "Your share: N bars (X% of the cutting)". |
| **Crown Jewels** | At the announced odds (25%), drawn among eligible contributors weighted by work (`Coop.weightedPick`), owner-only. The server announces who won the draw. |
| **Freeloading** | Shares are owner-only for their whole life (`LootService.spawnFor`, `Share` attribute). Anyone else gets "That's X's share. Earn your own: help with the work." Nothing spills free-for-all, so arriving at the end gets nothing. |
| **Disconnects** | Work is keyed by user id, so leaving and rejoining the same server before the vault opens keeps it. A contributor who is gone when the vault opens, or when their lock is cut, or who wins the jewels draw while away, has that share **held for them** (below). It is never handed to someone else. |
| **Duplicates** | The vault opens once (`Opened`), and each share is spawned once. Picking a share up goes through the normal server-checked pickup (bag rules, one take). |

## Storm Titan

| Rule | How |
| --- | --- |
| **Your siphon, your core** | Each player has their own siphon meter. A full meter forms a Mythic Core at their feet, owner-only, so nobody can snatch it. |
| **Work, not presence** | Siphon accrues only while the player steers (`Humanoid.MoveDirection`, the player's own move input, within the last 2.5 s), because the Titan's pull drags idle players around. Inside the inner radius it drains instead. |
| **Trying is worth something** | When the Titan ends, a partial siphon of at least 25% pays coins (`Coop.consolation`): progress × 15M (a full meter would have been a core averaging 94M). It is paid once, as earned coins, to players still present. |
| **Disconnects** | Leaving drops the siphon (it is keyed by the player object). There is no payout for absent players and nothing to duplicate. Going down also loses the siphon. |

## Held shares (owner review, 2026-10-14)

A share the server decided is never lost to a disconnect.

**When a share is held** (`RewardClaims.hold`, written under the owner's own user id):
- its owner has left when the event decides it;
- its owner leaves with owner-only shares still on the ground (Wreck items, a Titan core).

**Limits:**
- An entry expires after 72 h.
- At most 20 entries per player; the oldest is dropped first.
- Each entry has a unique id: server, event, share and owner.

**Paying a held share** (on the owner's next join, at their own Salvage Press, as earned coins):
1. `DataService.grantClaim` writes the coins and the claim id into the profile in one UpdateAsync.
2. The live session gets the same change.
3. The session is saved.
4. The entry is removed.

**Safety:**
- **Replay:** claimed ids are remembered for 8 days, longer than any entry lives. A re-added or leftover entry pays nothing and is cleared.
- **Crash between steps:** the profile already records the claim, so nothing pays twice.
- **Inflation:** entries are only ever written by the server from measured work, and are bounded and expiring.

**Not covered:** a Titan siphon in progress when its player leaves. It is keyed by the live player, and only the finished core is a share. The consolation is for players present at the end.

## Evidence

**Unit tests (`coop.spec.luau`):**
- equal and unequal splits;
- freeloaders below the minimum get nothing;
- more contributors than rewards;
- 500 random splits that always sum exactly and are deterministic;
- the jackpot draw follows contribution (750/250 over 1,000 rolls) and never picks a lurker;
- consolation bounds.

**Studio (one real player plus an injected absent contributor):**
- I finished three locks myself (work 0.3). An absent "crew member" was given 0.3 work.
- The vault opened with 4 bars: 2 shares at my feet ("Your share of the vault: 2 bullion bars (50% of the cutting)"), and the absent member's 2 forfeited.
- All three strongboxes were mine, owner-only.

**Titan (Studio):**
- Standing still for 5 s added nothing (0.300 → 0.300).
- Holding W round the ring for 3 s added 0.039.
- A 62% siphon at the end paid exactly 9,373,252 coins, once.

**Held shares (Studio):**
- **Absent contributor:** user 1 was given 67% of the work and was not in the server. The vault opened with 4 bars: I got 1 at my feet, and 3 bars plus the Crown Jewels (which they won in the draw) were held for user 1.
- **Pay on rejoin:** a held 2-bar share, plus 3 strongboxes and 1 bar I left on the ground, were paid on rejoin at my ×3 Press. That was exactly +13,050,000, and nothing was left held.
- **Replay:** re-adding the paid id and rejoining paid nothing, and the entry was cleared.
- **Unit tests:** `pendingrewards.spec.luau` covers dedupe, expiry, the cap, removal, exact value and claim memory.

**Not verified:** two or more real players. A non-owner trying to take a share, simultaneous claims and a real disconnect mid-wreck all need a multi-client or live test. Studio's tools here run one player.
