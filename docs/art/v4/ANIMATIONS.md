---
related-code:
  - "[[CharacterAnims.luau]]"
  - "[[Dodge.luau]]"
domain: world
type: guide
status: wip
tags: [storm-salvage, art, v4]
---

# V4 character animations: what they are, and how to upload them

Three animations for the R15 rig, authored as KeyframeSequences in the repo. Roblox only plays
animations that are uploaded as **Animation assets owned by the experience's owner**, so these need
one upload step by you. Until then the game uses its fallbacks, and nothing is broken.

**No IDs are invented.** `Config.Animations` stays `0` until you upload and paste the real IDs.

| Name | Length | Loop | Priority | What it does | Fallback without it |
| --- | --- | --- | --- | --- | --- |
| `Dodge` | 0.34 s | no | Action | Low lunge, hips drop, arms sweep back | Dust puff and whoosh |
| `CoreCarry` | 0.9 s | yes | Action | Arms only: both arms hug the core to the chest with a slow heave (legs keep the run cycle) | Gold or cyan carrier glow |
| `Celebrate` | 1.2 s | no | Action | Two fist pumps overhead in a V, with a hop | Extraction receipt card and sparkle burst |

- **Source:** `tools/asset_pipeline/build_animations.py` writes `assets/roblox/animations/*.model.json`.
- **In the place:** they build into `ServerStorage › Assets › animations`.
- **Studio previews:** while play-testing in Studio, the game previews them through `KeyframeSequenceProvider`, so you can see them before uploading. That only works in Studio.

## Upload steps (about 10 minutes, once)

1. **Open a Studio window with the animations in it.** Use the M2 release-candidate file (`StormSalvage-rc-20261014-9-<commit>.rbxl`) in Studio (File › Open from File). Don't publish it. Uploading animations doesn't touch the place.
2. **Make a test rig.** Avatar tab › **Rig Builder** › **R15** › **Block Rig**. A model called `Rig` appears in Workspace.
3. **Give the rig the animations.**
   1. In Explorer, select `Rig`, click **+** and add an **ObjectValue**. Rename it **`AnimSaves`**.
   2. Copy the three KeyframeSequences from `ServerStorage › Assets › animations` (`Dodge`, `CoreCarry`, `Celebrate`).
   3. Paste them **into** `Rig › AnimSaves`.
4. **Open the Animation Editor.** Avatar tab › **Animation Editor**, then click the `Rig`.
5. **For each animation (Dodge, then CoreCarry, then Celebrate):**
   1. In the Animation Editor, click **⋯** › **Load** and pick the animation by name.
   2. Check that it plays: press Space, or the play button.
   3. Check its settings in **⋯**:
      - **Priority:** Action
      - **Looping:** on only for CoreCarry
   4. Click **⋯** › **Publish to Roblox**.
   5. Name it `StormSalvage Dodge`, `StormSalvage CoreCarry` or `StormSalvage Celebrate`.
   6. **Creator:** choose the account that owns Storm Salvage (yours). An animation owned by anyone else won't play in the game.
   7. Submit. Copy the **ID** Roblox shows. It's a long number; the page link looks like `https://www.roblox.com/library/<ID>/...`.
6. **Send me the three IDs** (or paste them yourself into `src/shared/Config.luau`):
   ```lua
   Config.Animations = {
   	Dodge = <Dodge ID>,
   	CoreCarry = <CoreCarry ID>,
   	Celebrate = <Celebrate ID>,
   }
   ```
7. **Delete the test `Rig`** from Workspace, and close the window without saving or publishing.

After that, I check in Studio that each ID loads and plays through the uploaded path: Studio previews switch off for any name with a real ID. Then I cut a release candidate with the IDs in it.

## Notes

- **Re-uploading after a change** gives a new ID; paste the new one. Old IDs keep working but play the old version.
- **The rig is R15** with Roblox's newer joint system (AnimationConstraints). KeyframeSequences address body parts by name, so the same animations drive it.
- **If an upload is moderated or fails,** the game keeps working with the fallbacks. Tell me which one and I'll check the pose.
