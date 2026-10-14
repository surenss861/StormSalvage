# @file V4 character animations (R15 KeyframeSequences) for the dodge, core carry and extraction
# @domain world
# @status wip
"""V4 character animations, written as Rojo model files.

    python3 tools/asset_pipeline/build_animations.py

Writes assets/roblox/animations/{Dodge,CoreCarry,Celebrate}.model.json: R15 KeyframeSequences
(the experience uses R15; poses are named by body part, so they also drive the newer
AnimationConstraint joints). They live in ServerStorage.Assets.animations. A KeyframeSequence
can't play in a live server until the owner uploads it as an Animation asset; until then the game
uses its fallbacks (see src/client/CharacterAnims.luau and docs/art/v4/ANIMATIONS.md). In Studio
they preview through KeyframeSequenceProvider.

Angles are degrees about the joint's own X (pitch), Y (yaw), Z (roll). In R15, a positive X
rotation on a shoulder swings the arm forward and up; on a hip it swings the leg forward.
"""

import json
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "roblox", "animations")

TREE = {
    "HumanoidRootPart": {
        "LowerTorso": {
            "UpperTorso": {
                "Head": {},
                "LeftUpperArm": {"LeftLowerArm": {"LeftHand": {}}},
                "RightUpperArm": {"RightLowerArm": {"RightHand": {}}},
            },
            "LeftUpperLeg": {"LeftLowerLeg": {"LeftFoot": {}}},
            "RightUpperLeg": {"RightLowerLeg": {"RightFoot": {}}},
        }
    }
}


def rot(rx, ry, rz):
    # Roblox CFrame.Angles order: X, then Y, then Z (R = Rx * Ry * Rz).
    x, y, z = math.radians(rx), math.radians(ry), math.radians(rz)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rxm = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    rym = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rzm = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

    return mul(mul(rxm, rym), rzm)


def pose_tree(name, children, poses, only):
    """A Pose for `name` and the parts below it. `poses` maps part -> (rx, ry, rz[, (px, py, pz)]).
    Parts not in `only` (and with nothing below them in `only`) are left out entirely, so another
    animation (e.g. the run cycle) keeps control of them."""
    kids = []
    for child, sub in children.items():
        p = pose_tree(child, sub, poses, only)
        if p:
            kids.append(p)
    if name not in only and not kids:
        return None
    spec = poses.get(name, (0, 0, 0))
    pos = spec[3] if len(spec) > 3 else (0, 0, 0)
    return {
        "name": name,
        "className": "Pose",
        "properties": {
            "CFrame": {
                "CFrame": {
                    "position": [round(v, 4) for v in pos],
                    "orientation": [[round(v, 5) for v in row] for row in rot(*spec[:3])],
                }
            },
            "Weight": 1 if name in only else 0,
            "EasingStyle": "Cubic",
            "EasingDirection": "InOut",
        },
        "children": kids,
    }


def sequence(keyframes, only, loop, priority):
    frames = []
    for t, poses in keyframes:
        root = pose_tree("HumanoidRootPart", TREE["HumanoidRootPart"], poses, only)
        frames.append(
            {"name": "Keyframe", "className": "Keyframe", "properties": {"Time": t}, "children": [root]}
        )
    return {
        "className": "KeyframeSequence",
        "properties": {"Loop": loop, "Priority": priority},
        "children": frames,
    }


WHOLE_BODY = {
    "LowerTorso", "UpperTorso", "Head",
    "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
ARMS = {"UpperTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"}

# Dodge: 0.34 s. A low lunge: hips drop and pitch forward, arms sweep back, legs drive.
LUNGE = {
    "LowerTorso": (-22, 0, 0, (0, -0.55, 0)),
    "UpperTorso": (-12, 0, 0),
    "Head": (18, 0, 0),
    "LeftUpperArm": (-55, 0, 12),
    "LeftLowerArm": (25, 0, 0),
    "RightUpperArm": (-55, 0, -12),
    "RightLowerArm": (25, 0, 0),
    "LeftUpperLeg": (55, 0, 0),
    "LeftLowerLeg": (-70, 0, 0),
    "LeftFoot": (15, 0, 0),
    "RightUpperLeg": (-10, 0, 0),
    "RightLowerLeg": (-35, 0, 0),
    "RightFoot": (10, 0, 0),
}
DODGE = sequence(
    [(0.0, {}), (0.07, LUNGE), (0.24, LUNGE), (0.34, {})],
    WHOLE_BODY,
    loop=False,
    priority="Action",
)

# Core carry: looped, arms only (the run cycle keeps the legs). Both arms forward and bent,
# hugging the core to the chest, with a slow heave as if it's heavy.
HUG_A = {
    "UpperTorso": (4, 0, 0),
    "LeftUpperArm": (62, 0, 14),
    "LeftLowerArm": (35, 0, 0),
    "LeftHand": (0, 0, -10),
    "RightUpperArm": (62, 0, -14),
    "RightLowerArm": (35, 0, 0),
    "RightHand": (0, 0, 10),
}
HUG_B = dict(HUG_A, UpperTorso=(8, 0, 0), LeftUpperArm=(56, 0, 14), RightUpperArm=(56, 0, -14))
CORE_CARRY = sequence(
    [(0.0, HUG_A), (0.45, HUG_B), (0.9, HUG_A)],
    ARMS,
    loop=True,
    priority="Action",
)

# Extraction celebration: 1.2 s. Two fist pumps overhead in a V, with a hop, then back to rest.
# Overhead the arm's frame is flipped (measured in Studio): a positive elbow angle folds the hands
# back onto the head and a positive roll on the left arm crosses the arms, so the V uses a negative
# left roll and the pump bends the elbows forward (negative).
UP = {
    "LowerTorso": (0, 0, 0, (0, 0.5, 0)),
    "UpperTorso": (8, 0, 0),
    "Head": (12, 0, 0),
    "LeftUpperArm": (170, 0, -22),
    "LeftLowerArm": (0, 0, 0),
    "RightUpperArm": (170, 0, 22),
    "RightLowerArm": (0, 0, 0),
    "LeftUpperLeg": (10, 0, 0),
    "LeftLowerLeg": (-20, 0, 0),
    "RightUpperLeg": (10, 0, 0),
    "RightLowerLeg": (-20, 0, 0),
}
HALF = dict(
    UP,
    LowerTorso=(0, 0, 0, (0, -0.2, 0)),
    LeftUpperArm=(140, 0, -26),
    LeftLowerArm=(-25, 0, 0),
    RightUpperArm=(140, 0, 26),
    RightLowerArm=(-25, 0, 0),
    LeftUpperLeg=(25, 0, 0),
    LeftLowerLeg=(-40, 0, 0),
    RightUpperLeg=(25, 0, 0),
    RightLowerLeg=(-40, 0, 0),
)
CELEBRATE = sequence(
    [(0.0, {}), (0.18, UP), (0.42, HALF), (0.62, UP), (0.95, HALF), (1.2, {})],
    WHOLE_BODY,
    loop=False,
    priority="Action",
)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, seq in (("Dodge", DODGE), ("CoreCarry", CORE_CARRY), ("Celebrate", CELEBRATE)):
        path = os.path.join(OUT, name + ".model.json")
        with open(path, "w") as f:
            json.dump(seq, f, indent=1)
            f.write("\n")
        print("wrote", os.path.normpath(path))
