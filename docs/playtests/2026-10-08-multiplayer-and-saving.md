# Studio test: multiplayer and DataStore saving (2026-10-08)

Run in Roblox Studio over the Studio MCP connection. Sessions were started with
`StudioTestService:ExecuteMultiplayerTestAsync` (one server, two clients; a third and fourth
were added mid-session with `AddPlayers`). Each client was driven separately.

To make two clients act at the same moment, a small temporary LocalScript
([`tools/qa/client-harness.luau`](../../tools/qa/client-harness.luau)) was put into each
client during the run. The server sets `QA_Action`, `QA_Target` and `QA_FireAt`, and every
client presses the prompt at that server timestamp. Nothing from the harness is saved into
the place.

Screenshots are in [`../qa-screenshots/v4/`](../qa-screenshots/v4/).

## Where the saves went

The place is published (placeId 99653875913460, universe 10769947641) and Studio API access
is on, so these sessions used the **real DataStore** `StormSalvage_v1` of that experience.
Studio test players have negative user IDs (−1 … −5), so only the keys `player_-1` …
`player_-5` were read and written. No real player's key was touched. The test locks were
cleared afterwards.

If this experience will become the public one, move testing to a separate test experience
as the brief suggests. Ask before deleting the test keys; they are harmless but they exist.

## Multiplayer

| Check | Result | Evidence |
| --- | --- | --- |
| Same loot, two players | **Pass** | Both clients started the grab within 12 ms of each other (repeated three times). Exactly one player received the item each time; the server saw only the winner's trigger. The handler checks and sets `taken` without yielding, so two triggers can't both be granted. |
| Protected dropped bag | **Pass** | P2 died carrying 2 items. P1 tried at 3.5 s: refused with "That's Player2's bag. Free to grab in 17s." P1 tried at 24.7 s: got it. P2 recovered their own bag inside the window. |
| Simultaneous selling | **Pass** | Both sold in the same moment: P1 10 → 15 (Pipe, 5), P2 0 → 22 (Battery, 22). Independent counts of items sold. |
| Storm synchronization | **Pass** | Flood: both clients showed "FLASH FLOOD", the same countdown, and the same terrain water height. Lightning: P1 and a late joiner got the same 10 strike warnings, at the same positions, in the same order. |
| Joining mid-storm | **Pass** | Player3 added during lightning: the banner showed "LIGHTNING STORM" with the right countdown immediately, and the lighting matched existing players. |
| Independent upgrades | **Pass** | P2 bought Backpack 1 (122 → 72 coins, capacity 3 → 5). P1 and P3 unchanged. Boots refused for P2 ("Need 3 more coins"). |
| Rapid upgrade spam | **Pass** | 25 `BuyUpgrade("Backpack")` in one frame and 4 malformed calls: one purchase (322 → 172, level 2), no negative coins, no errors. |
| Sheltered and exposed players | **Pass** | 25 s of lightning: P2 inside a building stayed at 100 HP; P3 in the open was struck and died. |

## Saving and session locks

| Check | Result | Evidence |
| --- | --- | --- |
| Autosave writes progress | **Pass** | Stored coins and upgrades matched each session while it held the lock. |
| Leaving saves and releases the lock | **Pass** | Player3 left: stored coins 100, lock released. |
| Progress survives a new session | **Pass** | Ended the server and started a new one. P1 loaded 115 coins; P2 loaded 72 coins, Backpack 1, capacity 5, the same stats. |
| Another server took the profile | **Pass** | Wrote a foreign lock on `player_-1`, gave P1 +50, P1 left. Save refused ("save skipped, another server owns the profile"), stored value kept at 115. |
| Join while profile is locked | **Pass** | Fresh foreign lock: six retries, then removed after 43 s without a session. The other server's lock and data were left alone. |
| Stale lock (older than 360 s) | **Pass** | Taken over; data loaded normally in 4.6 s. |
| Lock released while waiting | **Pass** | Player1 loaded 4.2 s after the foreign lock was cleared during their retries. |
| Rejoin as the same user within one session | Not testable | Studio gives every added player a new negative ID, so only cross-session reloads were tested. |
| DataStore request errors (outage, throttling) | **Not tested** | Studio has no way to make `UpdateAsync` fail on demand. Only the lost-lock failure was tested. |

## Purchase receipts

Real product IDs are still 0, so no real purchase can happen. A Studio-only debug command,
`receipt`, sends a simulated receipt through the real `ProcessReceipt` handler for a
test-only product (+1000 coins).

| Check | Result | Evidence |
| --- | --- | --- |
| Normal purchase | **Pass** | `PurchaseGranted`; 115 → 1115, saved before being confirmed, receipt recorded. |
| Same receipt delivered twice | **Pass** | `PurchaseGranted`, coins unchanged at 1115. |
| Receipt while another server owns the profile | **Pass (after fix)** | `NotProcessedYet`, nothing saved. Before the fix the 1000 coins stayed spendable in the session even though they were never saved. Now they are rolled back (session stayed at 2115, not 3115). |
| Re-delivery after the profile is free again | **Pass** | `PurchaseGranted` once; stored 2115, 2 receipts. (Simulated with a new purchase ID: the refused one was never stored, so the outcome is the same.) |
| Real Robux purchase in Studio or live | **Not tested** | Needs real product IDs. |

## Defects found and fixed

1. **A session kept running normally after losing its save lock.** Every later save was
   refused, so the player silently lost everything after that point, and purchases would be
   granted into a session that could never save. Now `DataService.save` reports a lost lock,
   and the session switches to not-saving: `CanSave = false`, so the server refuses
   receipts, and the player is told "Your save is open in another server. Rejoin to keep
   your progress." (Message verified on the client. The shop's existing "purchases paused"
   check reads the same flag but wasn't seen on screen: buy buttons are hidden while product
   IDs are 0.)
2. **A grant that failed to save stayed in the session.** Each product handler now returns
   an undo function. If the save fails, the grant and the receipt ID are taken back and
   the player is told the purchase will be delivered automatically.
3. **No feedback while a locked profile retries (up to 43 s).** A "Loading your save..."
   message is sent after 3 s. Not yet seen on screen: the Studio client froze when it was
   removed, so neither this message nor the removal message could be captured.

## Still open

- DataStore outage or throttling during save, and server shutdown in the middle of a save.
- A real two-person session on separate devices (these were simulated clients on one Mac).
- Real purchases once product IDs exist.
- Playtesters on phones.
