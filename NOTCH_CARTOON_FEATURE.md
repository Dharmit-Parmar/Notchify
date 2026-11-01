# Notch Cartoon Companion ("Notchy") — Feature Specification & Architecture

> **Ambient Desktop Creature & Digital Hardware Companion for macOS**  
> *Transforming the physical MacBook display notch into a living, responsive habitat.*

---

## 1. What We Are Trying to Achieve (Vision & Purpose)

Long hours spent programming, writing, studying, or browsing in front of a laptop can often feel solitary and mechanical. Most modern operating systems treat screens purely as cold, utilitarian grids of pixels.

The **Notch Cartoon Companion** ("Notchy") introduces a living, ambient presence to macOS. Built directly into Notchify, it transforms the dead black space of the physical MacBook display notch into a cozy **den** where a tiny cartoon creature lives, explores, and interacts with the user.

### Core Philosophy
1. **Human Presence, Not an Intrusion**: The creature exists to keep the user company without ever being intrusive.
2. **Ambient Observation**: It does not make random beeps, does not pop up modal dialogs, and never interrupts the user's flow.
3. **No Direct Gameplay Controls**: It cannot be steered with `WASD` or arrow keys. It is an autonomous, expressive character that reacts organically to its environment.
4. **Physical Hardware Co-existence**: Rather than floating arbitrarily over user content, its entire world is defined by the physical geometry of the MacBook screen—walking along the menu bar ledge, hanging from the notch's bottom lip, and retreating into the bezel.

---

## 2. Usage & Behavior Models (How & When it Operates)

### 2.1 Passive Contextual Observation
The creature monitors ambient system telemetry without storing or transmitting any private user data:

| System State | Creature Reaction | Visual Details |
| :--- | :--- | :--- |
| **Active Coding / Rapid Typing** | **Typing Mimicry** | Pulls out a tiny miniature laptop and frantically types along with the user's keyboard cadence. |
| **Media Playback (Spotify / YouTube)** | **Music Groove** | Puts on tiny over-ear headphones and gently bobs its head and torso to the audio rhythm. |
| **Mouse Hovering Near Notch** | **Curious Inspection** | Stops in its tracks, tilts its head with spring physics, and follows the cursor with its pupils. |
| **Long Inactivity / Nighttime** | **Deep Sleep** | Curls up near the notch lip or retreats into the den with soft floating `Zzz` particles. |
| **Focus Mode / Do Not Disturb** | **Den Rest (0% CPU)** | Retreats entirely inside the physical notch bezel; all rendering timers halt. |

### 2.2 User Direct Interactions
- **Gentle Tap / Click**: Clicking directly on the creature triggers a haptic feedback pulse, causing it to do a joyful backflip, blush, and smile before scurrying back to its den.
- **Hover Tickle**: Hovering the cursor near its head causes its pupils to dilate with curious specular shines and its ears/antennae to twitch.

---

## 3. Engineering Goals & Performance Budgets

To ensure the companion can run continuously on MacBook battery power throughout an entire workday, it is engineered against strict, non-negotiable performance invariants:

```
┌────────────────────────────────────────────────────────┐
│               HARD RESOURCE CONSTRAINTS                │
├──────────────────────────┬─────────────────────────────┤
│ Idle CPU (In Den/Sleep)  │ 0.00% (Absolute zero)       │
│ Active CPU (60 FPS Move) │ < 0.8% of a single core     │
│ Memory Footprint         │ < 4.5 MB resident memory    │
│ Graphic Pipeline         │ 100% Vector Canvas (No PNGs)│
│ Frame Rate               │ Native 60 FPS / 120 FPS     │
│ Screen Click Obstruction │ 0% (Full click-through)     │
└──────────────────────────┴─────────────────────────────┘
```

### Full-Screen Transparent Overlay Architecture
- **Full Display Reach**: Spans the entire screen width ($1470\text{ pt}$ on MacBook displays) and $160\text{ pt}$ height.
- **Window Level**: Operates at `.screenSaver` level to render above both standard windows and the macOS menu bar.
- **Zero Click Interception**: The full-screen canvas has `ignoresMouseEvents = true`, ensuring menu bar icons, system menus, and top-level app controls function completely uninterrupted.
- **Miniature Auxiliary Click Panel**: A tiny $48 \times 48\text{ pt}$ invisible panel dynamically tracks the creature's body center. Only clicks directly on the creature's body intercept events.

---

## 4. Animation Systems & Movement Mechanics

### Core Rule: 100% Limb-Driven Kinematics (No Sprite Sliding)
The creature never translates across the display as a static sticker. Every motion is physically solved through a single-clock skeleton rig:

```
                   [ Head & Eyes ]
                          │
                   ( Neck Anchor )
                          │
  [Left Arm] ── (Shoulder Anchors) ── [Right Arm]
  IK 2-Bone               │               IK 2-Bone
                     [ Torso ]
                          │
  [Left Leg] ───── ( Hip Anchors ) ──── [Right Leg]
  IK 2-Bone               │               IK 2-Bone
                     [ Tail Chain ]
```

### 4.1 Two-Bone Analytical Inverse Kinematics (IK)
Arms and legs are solved using the analytical Law of Cosines:
$$\cos \beta = \frac{L_1^2 + d^2 - L_2^2}{2 L_1 d}$$
Both limbs attach strictly to computed normal anchors on the `TorsoBones` hull:
$$\vec{n} = (-\sin \theta_{\text{spine}},\, \cos \theta_{\text{spine}})$$
Guarantees **$0.0000\text{ pt}$ detachment error** across all frames and rotations.

### 4.2 Inverted Pendulum Bipedal Walk
- **Zero Foot Slip Contract**: The planted stance foot remains mathematically locked in world space ($\Delta X < 0.5\text{ pt}$) while the root and torso vault over it.
- **Secondary Spine Bounce**: Torso rises and falls smoothly with a sinusoidal arc ($2.2\text{ pt}$ displacement) matching natural mammalian locomotion.

### 4.3 Hand-Over-Hand Monkey-Bar Traversal
When crossing the gap underneath the hardware display notch:
- Both hands grip the bottom lip of the display notch ($Y = \text{notchHeight}$).
- The active gripping hand is locked to the ledge ($\Delta X = 0.0000\text{ pt}$).
- The body swings forward suspended as a damped gravitational pendulum:
  $$\ddot{\theta} = -\frac{g}{L} \sin \theta - \gamma \dot{\theta}$$
- The free hand reaches forward, locks onto the edge, and the stance transfers smoothly.

### 4.4 Corner Peek Choreography
1. **Concealment**: Creature remains hidden inside the notch.
2. **Grip Discovery**: Two tiny paws curl over the corner edge.
3. **Single-Eye Peek**: One eye pops out, scanning left and right with spring-damped tracking.
4. **Duck & Reappear**: Head briefly ducks down, then pops up fully with both eyes wide open and a happy smile.

### 4.5 Signature Slip & Dangle Comedy
Occasionally, the creature loses its balance near the notch edge:
- Feet slip out from beneath it.
- It catches the notch lip by its fingertips at the last second.
- Body sways with wide-eyed comic panic and kicking legs.
- It pulls itself up with a two-arm chin-up, rolls onto the ledge, and dusts itself off.

### 4.6 Physical Notch Cut-Out Protection
MacBook screens feature a physical hole where the camera hardware sits. The kinematic engine guarantees that the creature never enters the physical notch cutout ($X \in [645.5, 824.5], Y \in [0, 32.0]$). It walks on the ledge outside the notch ($X < 645.5$ or $X > 824.5$) or hangs strictly below it ($Y > 32.0$).

---

## 5. Visual Themes & Collectible Character Skins

The companion features 5 distinct procedural vector skins:

| Skin Name | Theme / Persona | Visual Highlights |
| :--- | :--- | :--- |
| **Mochi** *(Default)* | Warm Marshmallow Bunny | Soft warm-white cream body, pink blushing cheeks, subtle contact shadow. |
| **Kuro** | Obsidian Japanese Cat | Midnight-black silhouette, pointed cat ears, curved physics-driven tail. |
| **Boba** | Matcha Dinosaur | Pastel green palette with orange rounded dorsal back spines. |
| **Pixel** | Retro 8-Bit Arcade | Crisp pixelated borders, nostalgic arcade geometry, top antenna beacon. |
| **Cyber** | Neon Glitch Android | Dark-tech chassis, glowing cyan LED visor with animated facial emotes. |

---

## 6. Implementation Architecture in Codebase

The feature is modularized in `Sources/Modules/Companion/`:
- `KinematicSkeleton.swift`: Analytical 2-bone IK solver, `TorsoBones` hull normal calculations, `LimbBones`, and `SkeletonPose` single-clock data structures.
- `KinematicEngine.swift`: State machine and route evaluation (`leftWalk` $\rightarrow$ `approachNotch` $\rightarrow$ `lowerToHang` $\rightarrow$ `monkeyBarTraversal` $\rightarrow$ `climbOntoRightLedge` $\rightarrow$ `rightWalk` $\rightarrow$ `farCornerPeek` $\rightarrow$ `reverseWalk`).
- `CompanionWindow.swift`: Full-width transparent overlay window (`CompanionPanel`) and miniature click-interception panel (`CompanionClickPanel`).
- `CreatureRigView.swift`: Single-pass vector `Canvas` renderer with toggleable real-time skeleton bone/joint debug overlay.
- `CompanionCoordinator.swift`: System event bindings (keyboard typing cadence, media audio detection, focus sessions, DND).
- `Tests/KinematicAcceptanceTests.swift`: Automated verification suite asserting zero foot slip, zero grip slip, anchor attachment, and physical notch non-intersection.
