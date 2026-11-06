# Comprehensive Forensic & Kinematic Analysis: Notch Creature System

**Document Version:** 7.0 (Definitive Forensic Investigation, Prior Attempt Challenge & Correction, Mathematical Coordinate Proofs & Architectural Blueprints)  
**Target Subsystem:** macOS Ambient Notch Companion / Creature Rig (`Bubu`, `Mochi`, `Kuro`, `Boba`, `Pixel`, `Cyber` Archetypes)  
**Investigated Modules & Components:**
- Rendering Pipeline: [`Sources/Modules/Companion/CreatureRigView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift)
- Kinematics & Physics Engine: [`Sources/Modules/Companion/KinematicEngine.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift)
- Skeleton & IK Architecture: [`Sources/Modules/Companion/KinematicSkeleton.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicSkeleton.swift)
- State Machine Coordinator: [`Sources/Modules/Companion/CompanionCoordinator.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionCoordinator.swift)
- Window & Hit-Test Target: [`Sources/Modules/Companion/CompanionWindow.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionWindow.swift)
- Skin & Archetype Models: [`Sources/Modules/Companion/CompanionTypes.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionTypes.swift)
- Settings & Persistence: [`Sources/Settings/SettingsView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Settings/SettingsView.swift), [`Sources/Core/NotchModule.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Core/NotchModule.swift)
- Verification Suite: [`Tests/CompanionProductionPoseChecks.swift`](file:///Users/dharmitparmar/Doc/Notch/Tests/CompanionProductionPoseChecks.swift), [`Tests/VerificationTests.swift`](file:///Users/dharmitparmar/Doc/Notch/Tests/VerificationTests.swift)

---

## 1. Executive Summary & Forensic Context

### 1.1 Context of the Investigation
The user modified the Notch companion subsystem in their active working tree to implement a chubby cartoon mascot (Bubu archetype) featuring walking, peeking, hanging, and pull-up behaviors. However, the resulting implementation suffers from severe visual, kinematic, and functional defects:
1. **Peeking Malfunction:** The creature cannot peek properly; it feels like a flat half-circle or severed dome sitting on the notch/menu bar rather than an organic character peeking from behind hardware.
2. **Absence of 3D Depth:** The character reads as a flat 2D planar vector sticker cutout despite the addition of rudimentary radial gradients.
3. **Hanging & Pull-Up Failure:** The character appears to hang upside down (like an inverted fruit or dead bat dangling by its heels), lifts only halfway during pull-ups, never clears the ledge with its chin, and vanishes abruptly mid-frame.
4. **Frozen & Rigid Limbs:** Limb movements appear frozen or non-existent, and animations feel robotic, mechanical, and un-cute.
5. **The Notch Dip Traversal:** Continuous walking across the display dips $26\text{ pt}$ downward under the notch into empty desktop space while already floating $24\text{ pt}$ below the menu bar ($50\text{ pt}$ below the physical notch).
6. **Defective Creature Settings & Props:** User-facing toggles in `SettingsView.swift` (`companionAllowSlips`, `companionSleepDuringDND`, `companionMimicTyping`, `companionGrooveMusic`) are broken, dead, or have had their visual rendering props (`drawMiniLaptop`, `drawMiniHeadphones`) deleted from the working tree.

### 1.2 Summary of Investigation Findings
This investigation conducted an independent, skeptical review of both the codebase and the prior investigation report. A total of **27 distinct defects** were verified: 18 defects previously identified have been verified or mathematically corrected, and **9 additional critical defects** previously overlooked were discovered.

---

## 2. Challenge & Correction of Prior Investigation Findings

An objective audit of the prior investigation revealed several inaccuracies, incomplete analyses, and critical missed defects:

### 2.1 Correction 1: DEF-14 (Autonomous Slip Behavior)
- **Prior Claim:** The prior report claimed: *"Autonomous slips never occur during gameplay; feature only accessible via Settings test button."*
- **Evidence Cited:** Deletion of slip trigger block in `CompanionCoordinator.swift:279` (`companionRouteDidAdvance()`).
- **What Code Actually Shows:** In [`CompanionCoordinator.swift:209-236`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionCoordinator.swift#L209-L236):
  ```swift
  let choices: [CompanionBehaviorState] = [
      .peekingLeft, .peekingRight, .walking, .crawling, .thinking, .sleeping, .dangling
  ]
  guard let chosenState = choices.randomElement() else { return }
  switch chosenState {
  case .dangling, .slipping, .pullingUp:
      executeSlipSequence()
  ...
  ```
  Autonomous slips **DO occur during gameplay**. Whenever `executeRandomAction()` randomly selects `.dangling` (with probability $\frac{1}{7} \approx 14.3\%$), it calls `executeSlipSequence()`.
- **Corrected Finding:** The defect is significantly worse than claimed. `executeSlipSequence()` is invoked from `executeRandomAction()` **without checking `SettingsStore.shared.companionAllowSlips`**. As a consequence:
  1. When the user turns `companionAllowSlips` **OFF** in Settings, autonomous slips **continue to occur** randomly from the den.
  2. Slips **never occur organically while walking** across the notch because the walking slip trigger was deleted. The toggle is completely ignored.

### 2.2 Correction 2: DEF-08 (Hanging Hand Spacing Geometry)
- **Prior Claim:** The prior report cited hand spacing as $14.0\text{ pt}$ (`handL = 650.0`, `handR = 664.0`).
- **What Code Actually Shows:** While the initial variable declarations in [`KinematicEngine.swift:72`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L72) set `handLWorldX = 650.0` and `handRWorldX = 664.0` ($\Delta x = 14.0\text{ pt}$), during active hanging [`KinematicEngine.swift:211-212`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L211-L212) executes:
  ```swift
  handLWorldX = midX - 8.0
  handRWorldX = midX + 8.0
  ```
  The active runtime spacing is $\Delta x = 16.0\text{ pt}$.
- **Corrected Finding:** Both $14.0\text{ pt}$ and $16.0\text{ pt}$ are less than half the width of the head ($\text{headW} = 34.0\text{ pt}$). The athletic grip proportion remains inverted, but the runtime spacing is $16.0\text{ pt}$.

### 2.3 Correction 3: DEF-05 (Hardcoded Fur Gradients Breaking Collectible Skins)
- **Prior Claim:** The prior report noted that the gradient from $0.0$ to $0.35$ had $\Delta < 1\%$ contrast on white fur.
- **What Code Actually Shows:** In `renderLipPeek` (line 467), `renderChubbyWaddleWalk` (line 362), and `renderNotchHangAndPullUp` (line 615):
  ```swift
  let headGrad = Gradient(stops: [
      .init(color: .white, location: 0.0),
      .init(color: bodyColor, location: 0.35),
      .init(color: Color(red: 0.90, green: 0.86, blue: 0.84), location: 0.70),
      .init(color: Color(red: 0.84, green: 0.80, blue: 0.78), location: 1.0)
  ])
  ```
  Stops at $0.70$ and $1.0$ use **hardcoded creamy beige RGB values** (`0.90, 0.86, 0.84` and `0.84, 0.80, 0.78`).
- **Corrected Finding:** When the user selects `.kuro` (midnight obsidian cat, #1F1F24), `.boba` (matcha dinosaur, #73D18C), or `.cyber` (chrome chassis, #2E3847), the shading interpolates into light beige/pink at the perimeter. Kuro has a dark gray face with a muddy beige halo, completely breaking the collectible skin palette.

### 2.4 Critical Gaps Overlooked by Prior Investigation
The prior investigation completely missed 6 major visual and functional bugs:
1. **Deleted Extra Props (`drawMiniLaptop` & `drawMiniHeadphones`):** The working tree diff deleted lines 88–93 of `CreatureRigView.swift`. The interactive toggles "Mimic Typing Cadence" and "Groove to Music & Audio" in Settings promise a miniature laptop and tiny headphones, but the render calls were deleted from the codebase.
2. **External / Non-Notch Display Peeking in Mid-Air:** When `hasPhysicalNotch == false`, `notchLeft` and `notchRight` equal $\frac{\text{screenWidth}}{2.0}$. `renderLipPeek` renders the character emerging from the dead center of the screen in the middle of a continuous menu bar with zero hardware bezel.
3. **The "Backflip" Owl Neck Spin Defect:** In `SettingsView.swift:1081`, clicking "Backflip" triggers `onCreatureClicked()` $\to$ `.celebrating`. In [`KinematicEngine.swift:1102`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L1102), `pose.headAngle = p * 360.0`, while torso angle is unchanged. The head spins $360^\circ$ around its neck axis like an owl while the body does a vertical hop.
4. **Crawling Quadruped Missing Rear Legs:** `renderChubbyMascot` lines 721–724 and 742–745 draw only feet (`drawChubbyFoot`) and omit `drawChubbyLimb` for legs. During crawling, the creature moves on front arms dragging two detached floating foot dots with zero rear leg bones.
5. **Derivative Discontinuity ($C^1$ Velocity Jerk) in Waddle Bounce:** In [`CreatureRigView.swift:249`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L249), `bounce = -abs(sin(u * 2.0 * .pi)) * 2.0`. The absolute value produces an instantaneous velocity reversal ($\Delta v = 8\pi\text{ pt/s}$) at $u = 0.5$, causing an unnatural mechanical spasm mid-stride.
6. **Far-Corner Cliff Peek Overwritten by Walk Renderer:** `evaluateFarCornerTurn` computes head tilt and eye tracking over the screen edge, but `renderChubbyWaddleWalk` hardcodes `pupilOffset = (0.35, 0.0)` and head tilt `tilt * 0.5`, suppressing the cliff-peeking behavior.

---

## 3. Problem 1: Peeking Malfunction — Why It Appears as a Cut-Off "Half-Circle on the Notch"

### 3.1 Hardware Geometry vs. Static Menu Bar Initialization
On modern Apple Silicon MacBooks (Liquid Retina XDR displays):
- Screen top edge: $y = 0.0\text{ pt}$.
- Physical Camera Notch: Centered hardware cutout spanning $x \in [\text{notchLeft}, \text{notchRight}]$ and $y \in [0.0, 32.0\text{ pt}]$ ($\text{notchHeight} = 32.0\text{ pt}$).
- Active Menu Bar Pixels: Pixels exist to the left ($x < \text{notchLeft}$) and right ($x > \text{notchRight}$) from $y = 0.0\text{ pt}$ down to $y = \text{ledgeY}$ ($32.0\text{ pt}$).

```
y = 0pt  ┌───────────────────────┬─────────────────────────┬───────────────────────┐
         │ Active Menu Bar Pixels│  BLACK HARDWARE NOTCH   │ Active Menu Bar Pixels│
         │ (x < notchLeft)       │ (notchLeft...notchRight)│ (x > notchRight)      │
y = 32pt ├───────────────────────┴─────────────────────────┴───────────────────────┤ (ledgeY)
         │                         Desktop Window Space                            │
```

In [`CreatureRigView.swift:408-427`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L408-L427):
```swift
if side < 0 {
    // Left peek: starts near the notch left corner, emerges smoothly into left menu bar
    let startX = engine.notchLeft - 18.0
    let targetX = engine.notchLeft - 32.0
    headX = startX + (targetX - startX) * rise
    headY = gripY - 10.0 - (4.0 * rise)
}
```

#### Coordinate Proof of Static Placement
For a 14" MacBook Pro with `notchLeft = 645.5 pt` and `gripY = 32.0 pt`:
- At $t = 0.0\text{ s}$ (`rise = 0.0`):
  $$\text{headX} = 645.5 - 18.0 = 627.5\text{ pt}$$
  $$\text{headY} = 32.0 - 10.0 = 22.0\text{ pt}$$
- With $\text{headW} = 36.0\text{ pt}$ and $\text{headH} = 30.0\text{ pt}$:
  $$x_{\min} = 627.5 - 18.0 = 609.5\text{ pt}, \quad x_{\max} = 627.5 + 18.0 = 645.5\text{ pt} = \text{notchLeft}$$
  $$y_{\min} = 22.0 - 15.0 = 7.0\text{ pt}, \quad y_{\max} = 22.0 + 15.0 = 37.0\text{ pt}$$
1. At frame 0 ($t = 0.0\text{ s}$), the head is **already completely drawn inside the active menu bar** ($x \in [609.5, 645.5]$, $y \in [7.0, 37.0]$). Its right edge touches $\text{notchLeft}$ directly against the vertical black wall of the camera notch.
2. Over the entire emergence phase ($t \in [0, 1.2\text{ s}]$), $\text{headY}$ shifts upward by only $4.0\text{ pt}$ ($22.0 \to 18.0\text{ pt}$), and $\text{headX}$ translates leftward by $14.0\text{ pt}$ ($627.5 \to 613.5\text{ pt}$).
3. The creature never emerges from behind the notch; it is statically initialized directly inside the menu bar.

### 3.2 The Neck Stroke Severance Bug (The Literal "Half-Circle")
In [`CreatureRigView.swift:434-472`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L434-L472):
1. `torsoPath` is rendered first at $y \in [25.0, 47.0\text{ pt}]$.
2. `headShape` is computed via `dumplingHeadPath(width: 36.0, height: 30.0)`.
3. In `dumplingHeadPath` (`CreatureRigView.swift:756-798`), the path is a **closed subpath** (`path.closeSubpath()`) with a flat bottom boundary spanning $y = +0.48h = +14.4\text{ pt}$ relative to `headCenter`.
4. At $\text{headY} = 18.0\text{ pt}$, this bottom contour runs along $y = 18.0 + 14.4 = 32.4\text{ pt}$ (directly along the bottom border of the menu bar).
5. In line 472, the head is stroked:
   ```swift
   context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
   ```
6. Because `headShape` is stroked *after* `torsoPath` with a $2.2\text{ pt}$ dark charcoal stroke, **it paints an opaque black horizontal boundary line directly across the neck at $y = 32.4\text{ pt}$**.
7. This dark stroke visually amputates the head from the torso, turning the head into an isolated, flat, closed semi-circle/dome sitting on the menu bar line.

### 3.3 Crushed Arm Geometry & Missing Paws
In lines 490–524:
- Paws are placed on the ledge at $y = \text{gripY} - 2.5 = 29.5\text{ pt}$.
- Forearms start at $\text{headY} + 11.0 = 29.0\text{ pt}$ and end at $\text{gripY} - 1.0 = 31.0\text{ pt}$.
- The arm curves span a vertical height of **only $2.0\text{ pt}$**, producing a squashed horizontal line with zero elbow articulation.
- When `rise < 0.15` ($t < 0.18\text{ s}$), lines 490–524 are skipped entirely (`if rise > 0.15`), meaning the head dome pops onto the screen with **zero arms and zero paws**.
- `renderLipPeek` completely discards `evaluatePeek` from [`KinematicEngine.swift:831-964`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L831-L964), bypassing the paws-first reveal, single-eye curious peek, and dip transitions.

### 3.4 Non-Notch Display Peeking Anomaly
In [`KinematicEngine.swift:109-112`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L109-L112):
```swift
let notchW: CGFloat = hasPhysicalNotch ? 179.0 : 0.0
notchLeft = (screenWidth - notchW) / 2.0
notchRight = (screenWidth + notchW) / 2.0
```
When `hasPhysicalNotch == false` (e.g. external display or clamshell mode), `notchLeft = screenWidth / 2.0`. In `renderLipPeek`, `startX = notchLeft - 18.0`. The creature emerges in the exact horizontal center of the menu bar, floating in mid-air with no notch or physical frame to hide behind.

---

## 4. Problem 2: Absence of 3D — Flat Planar Vector Cutout vs. Volumetric Depth

### 4.1 Structural Reasons for 2D Planar Appearance
1. **Imperceptible Center Gradient Contrast ($\Delta < 1\%$):**
   In `renderLipPeek` (lines 464–471), `renderChubbyWaddleWalk` (lines 359–364), and `renderNotchHangAndPullUp` (lines 612–618):
   For `.bubu`, `bodyColor` is `Color(r: 0.99, g: 0.99, b: 0.98)`. Over the first $35\%$ of the head radius ($12.6\text{ pt}$), the color goes from $100\%$ white to $99\%$ white. This difference ($\Delta < 0.01$) is invisible to the human visual cortex. The core of the head reads as 100% flat solid white.
2. **Hardcoded Beige Stops Discoloring Skins:**
   Stops at locations $0.70$ and $1.0$ hardcode `(0.90, 0.86, 0.84)` and `(0.84, 0.80, 0.78)`. These creamy beige tones ruin non-white skins (Kuro, Boba, Cyber).
3. **100% Flat Solid Fills in `renderChubbyMascot`:**
   In [`CreatureRigView.swift:1067, 1100`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L1067), during `.thinking`, `.curious`, `.typingMimic`, `.musicGroove`, `.celebrating`, and `.crawling`, head and torso are filled with flat solid `skin.primaryColor` with zero lighting.
4. **100% Flat Extremities:** Paws (`lines 515, 667, 1031`), feet (`lines 273, 559, 1011`), arms (`lines 502, 655, 994`), and ears (`lines 352, 457, 605`) are 100% flat solid unshaded colors.
5. **Uniform 2.2pt Charcoal Stroke:** Outlines every part with a thick $2.2\text{ pt}$ dark border ($>14\%$ of shape radius), creating a 2D Flash sticker aesthetic.
6. **No Contact Ambient Occlusion:** Zero drop shadows beneath head on neck, ears on crown, or paws on ledge.

### 4.2 Faux-3D Procedural Solution at 0 MB RAM & 60 FPS
True 3D scene graphs (`SceneKit`/`RealityKit`) require $35.0\text{–}60.0\text{ MB}$ of memory, violating the strict $< 4.5\text{ MB}$ footprint requirement. High-end "vinyl toy" depth is achieved purely within SwiftUI `Canvas` at **$0\text{ MB}$ memory overhead**:
- Key light source placed at $(-30^\circ, -45^\circ)$: $\text{lightCenter} = (c_x - 0.28R, c_y - 0.32R)$.
- Specular core highlight at $0.0$ (`.white.opacity(0.95)`).
- Diffuse surface tone at $0.25$ (`skin.primaryColor`).
- Core shadow terminator at $0.65$ (`skin.primaryColor.opacity(0.82)`).
- Ambient bounce rim at $0.92$ (`skin.darkAccentColor.opacity(0.35)`).
- Contour edge tone at $1.00$ (`skin.outlineColor.opacity(0.80)`).
- Cylindrical linear gradients on limb hulls perpendicular to the bone vector.
- Contact drop shadow ellipses under paws and chin (`opacity: 0.25`).

---

## 5. Problem 3: Hanging & Pull-Up Failure — Why It Appears Hanging Upside Down with Broken Pull-Ups

### 5.1 The "Hanging Upside Down" Artifact
In [`KinematicEngine.swift:746-760`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L746-L760):
```swift
let armLength: Double = 60.0
let swayY = CGFloat(armLength * cos(pendulumAngle))
let rootY = gripY + swayY // 35.0 + 60.0 = 95.0 pt
```
- The body is only $22\text{ pt}$ tall, but arms are simulated as **$60.0\text{ pt}$ elongated noodles**. The character hangs $95.0\text{ pt}$ below the top of the display.
- Hands are pinned with spacing of **$16.0\text{ pt}$** (`handL = midX - 8.0`, `handR = midX + 8.0`), while the head is **$34.0\text{ pt}$ wide**.
- Hands spaced $16\text{ pt}$ apart holding a $34\text{ pt}$ wide head suspended $60\text{ pt}$ below creates an extreme inverted V-shape. The silhouette tapers to a narrow apex at the hands and expands to a heavy bulb at the bottom, mimicking an inverted fruit or bat dangling upside-down by its heels.
- Clamping `abs(pendulumAngle) > 0.32` with `pendulumVelocity *= -0.45` causes a harsh mechanical spasm at $\pm 18^\circ$, bouncing off an invisible wall.

### 5.2 The Chin Clearing Failure & Clamping Trap
In [`KinematicEngine.swift:798-809`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L798-L809):
$$\text{rootY} = \text{pullUpStartY} + (\text{ledgeY} + 32.0 - \text{pullUpStartY}) \cdot \text{easedLift}$$
At maximum lift apex (`lift = 1.0`):
$$\text{rootY} = 32.0 + 32.0 = 64.0\text{ pt}$$
$$\text{headCenter.y} = 64.0 - 17.0 = 47.0\text{ pt}, \quad \text{chin.y} = 57.0\text{ pt}, \quad \text{headTop.y} = 33.0\text{ pt}$$
- The ledge is at $y = 32.0\text{ pt}$. At maximum pull-up effort, the chin is at $y = 57.0\text{ pt}$—**$25.0\text{ pt}$ below the bar**!
- Even the very top of the head is $1.0\text{ pt}$ below the bar. The creature never pulls its chin or eyes over the ledge.
- **Root Cause:** In [`Tests/CompanionProductionPoseChecks.swift:41, 112`](file:///Users/dharmitparmar/Doc/Notch/Tests/CompanionProductionPoseChecks.swift#L41), the test asserts `headCenter.y - 11 >= engine.ledgeY`. To satisfy this, [`KinematicEngine.swift:115-118`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L115-L118) clamps `headCenter.y >= ledgeY + 12.0` ($44.0\text{ pt}$). This test assertion was meant for walking, but was applied to pull-ups, mathematically preventing the chin from ever clearing the ledge.
- **Disappearing Window Mid-Animation:** In [`CompanionCoordinator.swift:347`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionCoordinator.swift#L347), after $2.5\text{ s}$, `retreatToDen()` calls `panel?.orderOut(nil)`. The character instantly vanishes from the screen mid-frame instead of finishing the pull-up.

---

## 6. Problem 4: Limb Motion & Articulation — Why Limbs Appear Frozen / Not Moving

### 6.1 Bypass of 2-Bone Analytical IK Across Primary Behaviors
1. **Walking (`renderChubbyWaddleWalk`, lines 262–299):**
   - Feet are two static ellipses glued to `bodyTransform` oscillating vertically by $\pm 2.5\text{ pt}$. Zero forward/backward world translation and zero knee joints.
   - Arms are two rigid pill capsules (`6.5 x 11.0 pt`) sliding up and down linearly by $\pm 3.0\text{ pt}$ like mechanical pistons. Zero elbow flexion, zero shoulder rotation.
2. **Peeking (`renderLipPeek`, lines 384–525):** Legs omitted entirely; arms are a flat single-curve sliver; paws slide as detached pills.
3. **Hanging & Pull-Up (`renderNotchHangAndPullUp`, lines 528–677):** Feet are two disconnected ellipses kicking horizontally; arms are a single bezier curve with no elbow joint.
4. **Mascot (`renderChubbyMascot`, lines 680–751):** In lines 721–724 and 742–745, **leg limbs were omitted**; it draws only detached foot pads. `drawChubbyLimb` is never called for legs.
5. **Crawling (`renderChubbyMascot` + `evaluateCrawling`):** The engine computes full quadruped limb movement, but the renderer completely ignores rear leg bones, drawing only floating foot pads.

### 6.2 Stroke Width Joint Swallowing
In [`KinematicSkeleton.swift:211`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicSkeleton.swift#L211), bone lengths are $L = 8.0\text{ pt}$.
In [`CreatureRigView.swift:973-997`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L973-L997), `drawChubbyLimb` strokes the limb with width $7.5\text{ pt}$ and `.round` line join.
- The round cap at the elbow has diameter $7.5\text{ pt}$.
- The bone length is $8.0\text{ pt}$.
- The joint circle covers nearly $94\%$ of the bone length.
- Any elbow flexion overlaps itself completely, turning the joint into an unbending, shapeless blob.

### 6.3 Mathematical Discontinuity in Waddle Bounce ($C^1$ Velocity Jerk)
In [`CreatureRigView.swift:249`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L249):
$$\text{bounce}(u) = -2.0 \cdot |\sin(2\pi u)|$$
Differentiating with respect to $u$:
- As $u \to 0.5^-$, $\frac{d}{du}[-2\sin(2\pi u)] = -4\pi \cos(\pi) = +4\pi \approx +12.57\text{ pt/cycle}$.
- As $u \to 0.5^+$, $\frac{d}{du}[+2\sin(2\pi u)] = +4\pi \cos(\pi) = -4\pi \approx -12.57\text{ pt/cycle}$.
The vertical velocity undergoes an instantaneous step change of $\Delta v = -8\pi \approx -25.13\text{ pt/cycle}$. This infinite jerk creates a sharp mechanical judder at the apex of every single step.

### 6.4 The "Backflip" Owl Neck Spin Defect
In [`SettingsView.swift:1081`](file:///Users/dharmitparmar/Doc/Notch/Sources/Settings/SettingsView.swift#L1081), clicking "Backflip" triggers `CompanionCoordinator.shared.onCreatureClicked()` $\to$ `evaluateCelebrating()`.
In [`KinematicEngine.swift:1098-1102`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L1098-L1102):
```swift
let p = min(1.0, behaviorTime / 0.8)
let jumpY = CGFloat(sin(p * .pi)) * 12.0
pose.torso.root = visibleBodyRoot(at: CGPoint(x: rootWorldX, y: walkY - 14.0 - jumpY))
pose.headAngle = p * 360.0
```
`pose.torso.spineAngle` remains upright ($-\frac{\pi}{2}$). The torso does not rotate or pitch; only the head spins $360^\circ$ around its neck axis like an owl while the body performs a small vertical hop.

---

## 7. Problem 5: The Notch Dip Traversal Mechanics

In [`KinematicEngine.swift:398-415`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L398-L415):
```swift
effectiveWalkY += 26.0 * (p * p * (3.0 - 2.0 * p))
```
1. **Floating $50\text{ pt}$ Below the Notch:** `walkLedgeY = 56.0\text{ pt}`. Under the notch, `effectiveWalkY = 56.0 + 26.0 = 82.0\text{ pt}`. The bottom of the notch is at $y = 32.0\text{ pt}$. The creature walks with feet at $y = 82.0\text{ pt}$—floating $50.0\text{ pt}$ in empty desktop space over open windows with no visual ground.
2. **Root Y vs. Foot Y Conceptual Confusion:** In `KinematicEngine.swift:40`, `walkLedgeY = ledgeY + 24.0`. The author confused the torso root position with the foot contact plane. In `computeWalkPose`, feet are locked to `walkLedgeY`, pushing the feet 24 pt below the menu bar and 50 pt below the notch.
3. **Rigid Vertical Spine on $23.4^\circ$ Slope:** The dip drops $26\text{ pt}$ over $60\text{ pt}$ horizontally ($\text{slope} \approx 0.433$, or $23.4^\circ$). The spine angle remains locked at $-\frac{\pi}{2}$, failing to pitch or lean into the slope.
4. **Planted Foot Slippage:** `leftFootWorldY` latches to old `walkY` while body drops with new `walkY`, distorting the hip-to-foot distance.

---

## 8. Problem 6: Creature Settings, Timers, & Coordinator Architecture

1. **`companionAllowSlips` Defect:** In `SettingsView.swift:1247`. The user deleted the slip trigger block from `companionRouteDidAdvance()`. However, `executeRandomAction()` in `CompanionCoordinator.swift:235` continues to call `executeSlipSequence()` autonomously when `.dangling` is selected, **without checking `companionAllowSlips`**. Turning the toggle OFF does not stop slips from the den, but slips never occur while walking.
2. **Deleted Extra Props (`drawMiniLaptop` & `drawMiniHeadphones`):** In `SettingsView.swift:1205, 1222`, the user is offered options for typing mimicry with a mini laptop and music grooving with mini headphones. In `CreatureRigView.swift`, the code rendering these props was deleted.
3. **`companionSleepDuringDND` has Zero Implementation:** In `SettingsView.swift:1264`. There is no notification listener for `com.apple.controlcenter.user-focus-changed`. Completely inert.
4. **`hasSlippedInSession` is a Write-Only Dead Variable:** In `CompanionCoordinator.swift:26, 330`. Set to `true` on slip, never read anywhere.
5. **Collectible Skins Ear Overrides:** `renderLipPeek`, `renderNotchHangAndPullUp`, and `renderChubbyWaddleWalk` hardcode circular Bubu bear ears instead of calling `drawHeadEars`. Selecting Kuro, Boba, Cyber, or Pixel displays bear ears during walking, hanging, and peeking.
6. **Interactive Click Target Misalignment:** In `CompanionWindow.swift:141-147`, `clickPanel` is positioned from `pose.root` ($y \approx 58\text{–}68\text{ pt}$), while `renderLipPeek` renders the head at $y \approx 18\text{ pt}$. The click target hovers $40\text{–}50\text{ pt}$ below the visible face; user clicks miss completely.
7. **Peek Timer Race Condition:** In `CompanionCoordinator.swift:253`, a random timer of 6.0–8.5s fires before the 5.8–6.6s ducking animation finishes, abruptly popping the window out mid-motion.
8. **Cursor Hover Ignores Active States:** In `CompanionCoordinator.swift:428`, hovering only reacts when `state == .sleeping`. Hovering during walking, peeking, or hanging does nothing.

---

## 9. Master Defect Matrix (27 Verified Defects)

| ID | Subsystem | File & Lines | Severity | Root Cause | Behavioral Impact |
|---|---|---|---|---|---|
| **DEF-01** | Peeking | `CreatureRigView.swift:408-427` | **Critical** | Head initialized statically inside menu bar ($y \in [7, 37\text{ pt}]$); translates only $4\text{ pt}$ vertically and $14\text{ pt}$ horizontally. | Peeking does not emerge from behind notch; sits statically against notch wall. |
| **DEF-02** | Peeking | `CreatureRigView.swift:463-472` | **Critical** | `dumplingHeadPath` closed bottom arc stroked with $2.2\text{ pt}$ dark outline *after* torso. | Head is visually severed from torso, appearing as a cut-off half-circle/dome. |
| **DEF-03** | Peeking | `CreatureRigView.swift:490-524` | **High** | Forearms squashed into a $2\text{ pt}$ flat line; paws slide as detached pills; skipped entirely when `rise < 0.15`. | Character has no visible arm articulation during peek; head pops up limbless. |
| **DEF-04** | Peeking | `CreatureRigView.swift:384` | **High** | `renderLipPeek` ignores `pose` from `KinematicEngine.swift:831-964`. | 5-phase storytelling choreography (paws, single-eye peek, dip, smile) completely lost. |
| **DEF-05** | 3D Depth | `CreatureRigView.swift:464, 359, 612` | **High** | Radial gradient stops 0.0 to 0.35 have $\Delta < 1\%$ color change for Bubu white fur. | Gradient is imperceptible to human eye; reads as 100% flat 2D white fill. |
| **DEF-06** | 3D Depth | `CreatureRigView.swift:1067, 1100` | **High** | `renderChubbyMascot` fills head and torso with flat solid `skin.primaryColor`. | Mascot states (thinking, typing, curious, groove) are 100% unshaded 2D cutouts. |
| **DEF-07** | 3D Depth | `CreatureRigView.swift:273, 515, 605` | **High** | All extremities (paws, feet, arms, ears) filled with flat solid colors and $2.2\text{ pt}$ strokes. | Uniform heavy strokes and unshaded limbs flatten entire character into a 2D sticker. |
| **DEF-08** | Hanging | `KinematicEngine.swift:211, 746-760` | **Critical** | Active hand spacing $16\text{ pt}$ holding $34\text{ pt}$ head suspended $60\text{ pt}$ below notch. | Silhouette inverts athletic pull-up V-taper, reading as an upside-down dangling bat or fruit. |
| **DEF-09** | Pull-Up | `KinematicEngine.swift:798-809` | **Critical** | Pull-up apex reaches `root.y = 64.0 pt`, placing chin at $y = 57.0\text{ pt}$ ($25\text{ pt}$ below ledge). | Chin never clears the bar; character fails to achieve a true pull-up position. |
| **DEF-10** | Pull-Up | `KinematicEngine.swift:115-118` | **Critical** | `visibleRouteHead` clamps `headCenter.y >= ledgeY + 12.0` ($44\text{ pt}$) to satisfy tests. | Mathematical ceiling prevents pull-up from ever lifting the head above the ledge. |
| **DEF-11** | Kinematics | `CreatureRigView.swift:262-299, 721` | **Critical** | Specialized renderers discard 2-bone IK; `renderChubbyMascot` omitted leg bones entirely. | Limbs appear frozen; feet are static dots and arms slide as rigid piston capsules. |
| **DEF-12** | Kinematics | `CreatureRigView.swift:973-997` | **High** | $7.5\text{ pt}$ stroke width equals the $8.0\text{ pt}$ bone length. | Round line join at elbow swallows both bone segments, turning flexion into an unbending blob. |
| **DEF-13** | Traversal | `KinematicEngine.swift:398-415` | **High** | Continuous walk dips to $y = 82.0\text{ pt}$ ($50\text{ pt}$ below notch) with rigid vertical spine. | Character walks in mid-air over open desktop space without leaning into incline/decline. |
| **DEF-14** | Settings | `CompanionCoordinator.swift:235` | **High** | `executeRandomAction` calls `executeSlipSequence` without checking `companionAllowSlips`. | Slips occur from den even when toggle is OFF; slips never occur organically while walking. |
| **DEF-15** | Settings | `SettingsView.swift:1264` | **Medium** | `companionSleepDuringDND` has zero notification listeners or system observers. | UI toggle that misleads users by doing nothing when flipped. |
| **DEF-16** | Settings | `CreatureRigView.swift:454, 602, 349` | **Medium** | Renderers hardcode `.bubu` bear ears instead of calling `drawHeadEars`. | Collectible skins (Kuro cat, Boba dino, Cyber robot) display bear ears during walking and peeking. |
| **DEF-17** | Window | `CompanionWindow.swift:141-147` | **High** | Click panel positioned from `pose.root`, but `renderLipPeek` invents local coordinates. | Click target hovers $40\text{–}50\text{ pt}$ below visible head during peeking; clicks miss. |
| **DEF-18** | Coordinator | `CompanionCoordinator.swift:253` | **Medium** | Action timer ($6.0\text{–}8.5\text{ s}$) fires before ducking animation ($5.8\text{–}6.6\text{ s}$) finishes. | Window abruptly disappears mid-animation when timer selects low duration. |
| **DEF-19** | Settings | `CreatureRigView.swift:88-93` | **High** | `drawMiniLaptop` and `drawMiniHeadphones` deleted from working tree. | Typing mimic and music groove display generic mascot without promised props. |
| **DEF-20** | Peeking | `CreatureRigView.swift:415, KinematicEngine:109` | **High** | On non-notch displays, `notchLeft` is $\frac{\text{width}}{2}$; peek emerges in mid-screen air. | Peeking appears broken and ungrounded on external displays and clamshell setups. |
| **DEF-21** | 3D Depth | `CreatureRigView.swift:467, 362, 615` | **High** | Hardcoded beige gradient stops (`0.90, 0.86, 0.84`) clobber non-white collectible skins. | Kuro, Boba, and Cyber skins suffer discolored beige rims and broken palettes. |
| **DEF-22** | Motion | `KinematicEngine.swift:1102` | **Medium** | Backflip button rotates only `headAngle` $360^\circ$ while torso remains strictly upright. | Head spins $360^\circ$ like an owl/exorcist rather than performing a physical backflip. |
| **DEF-23** | Kinematics | `CreatureRigView.swift:721, KinematicEngine:1115` | **High** | Crawling gait calculates 4-legged crawl, but mascot renderer omits rear leg bones. | Creature crawls on front arms while dragging two detached floating foot dots. |
| **DEF-24** | Motion | `CreatureRigView.swift:249` | **High** | Waddle bounce uses `-abs(sin(2*pi*u))` having a derivative discontinuity at $u = 0.5$. | Instantaneous velocity reversal ($\Delta v = 8\pi$) creates a jarring mechanical shudder every step. |
| **DEF-25** | Physics | `KinematicEngine.swift:752-755` | **Medium** | Pendulum angle hard-clamped at $0.32\text{ rad}$ with `pendulumVelocity *= -0.45`. | Swinging creature bounces unnaturally off an invisible wall in mid-air. |
| **DEF-26** | Storytelling | `CreatureRigView.swift:79, KinematicEngine:624` | **Medium** | `renderChubbyWaddleWalk` overwrites cliff-peek pupil and head angles during far-corner turn. | Creature fails to look curiously over the edge of the display before turning around. |
| **DEF-27** | Interaction | `CompanionCoordinator.swift:428` | **Low** | `onCursorHover` only reacts during `.sleeping`; ignores walking, peeking, and hanging. | Character feels unresponsive and lifeless when the user hovers over it during action states. |

---

## 10. Actionable Architectural Blueprints & Implementation Guide

### 10.1 Peeking: True Organic Emergence & Continuous Geometry
1. **Vertical Emergence from Behind the Ledge:**
   Initialize `headY` below the ledge ($y = \text{ledgeY} + 18.0\text{ pt}$) and animate upward to $y = \text{ledgeY} - 8.0\text{ pt}$:
   $$y(t) = (\text{ledgeY} + 18.0) - 26.0 \cdot \text{rise}(t)$$
   Initialize `headX` at $\text{notchLeft} - 22.0\text{ pt}$ (completely clear of the notch glass):
   $$x(t) = (\text{notchLeft} - 16.0) - 10.0 \cdot \text{rise}(t)$$
2. **Eliminate the Dividing Neck Stroke:**
   In `dumplingHeadPath`, render the bottom contour as an open arc, or stroke the head outline *before* the torso fill, eliminating the dividing line across the neck.
3. **Connect 2-Bone Forearms to Paws:**
   Bind paws to `pose.leftArm.end` and `pose.rightArm.end`. Stroke articulated 2-bone limbs from `pose.torso.leftShoulderAnchor` through `pose.leftArm.joint` to paws resting on the ledge.

### 10.2 Procedural Faux-3D Engine (Zero-RAM Budget)
Replace flat fills with a calibrated 5-stop volumetric lighting shader in `GraphicsContext`:
```swift
// Calibrated Volumetric Faux-3D Shader (0 MB RAM overhead)
let lightCenter = CGPoint(x: headCenter.x - headW * 0.22, y: headCenter.y - headH * 0.26)
let sphereGrad = Gradient(stops: [
    .init(color: .white.opacity(0.95), location: 0.0),                          // Specular core
    .init(color: skin.primaryColor, location: 0.25),                            // Diffuse body
    .init(color: skin.primaryColor.opacity(0.85), location: 0.65),              // Body tone
    .init(color: skin.darkAccentColor.opacity(0.35), location: 0.92),           // Ambient rim bounce
    .init(color: skin.outlineColor.opacity(0.80), location: 1.0)                // Contour edge tone
])
context.fill(headShape, with: .radialGradient(sphereGrad, center: lightCenter, startRadius: 1.0, endRadius: headW * 0.62))
```
- Replace hardcoded beige constants with semantic derivations from `skin.primaryColor` and `skin.darkAccentColor`.
- Apply cylindrical linear gradients to limb hulls perpendicular to the bone vector.
- Add soft ambient occlusion drop shadows beneath paws (`Color.black.opacity(0.25)`, radius $2.0\text{ pt}$) and under the chin (`Color.black.opacity(0.20)`, height $3.5\text{ pt}$).

### 10.3 Athletic Pull-Up & Hanging Kinematics
1. **Reduce Hanging Arm Length & Expand Grip:**
   Change `armLength` from $60.0\text{ pt}$ to **$28.0\text{ pt}$**. Space hands $28.0\text{ pt}$ apart (`handL = midX - 14.0`, `handR = midX + 14.0`), creating an athletic shoulder-width grip.
2. **Elevate Chin Over the Bar:**
   In `evaluatePullingUp`, lift `rootY` to $\text{ledgeY} + 12.0\text{ pt}$.
   This lifts `headCenter.y` to $\text{ledgeY} - 2.0\text{ pt}$ ($30.0\text{ pt}$), placing the chin at $y = 30.0 + 10.0 = 40.0\text{ pt}$ and allowing the eyes ($y = 26.0\text{ pt}$) to look comfortably over the bar.
3. **Decouple Unit Test Clamping from Pull-Ups:**
   In `CompanionProductionPoseChecks.swift:41, 112`, update the notch overlap assertion to apply only during `.walking`, and exempt `.pullingUp`.
   In `KinematicEngine.swift:115-118`, unclamp `visibleRouteHead` during pull-ups.
4. **Z-Order Layer Inversion:**
   In `renderNotchHangAndPullUp`, paint the head *before* front arms so flared elbows ($90^\circ$ flexion) bend in front of the cheeks and torso without being swallowed.

### 10.4 Restore Articulated Limbs & Motion Dynamics
1. **Connect 2-Bone IK in Walking:**
   In `renderChubbyWaddleWalk`, replace static ellipses with calls to `drawChubbyLimb` using `pose.leftLeg` and `pose.rightLeg`, and animate stubby knee flexion.
2. **Calibrate Limb Thickness:**
   Reduce limb stroke thickness from $7.5\text{ pt}$ to **$5.0\text{ pt}$** with an inner fill of $2.8\text{ pt}$, preventing the joint circle from swallowing the $8.0\text{ pt}$ bone length.
3. **Smooth Harmonic Gait Bounce ($C^\infty$ Smoothness):**
   Replace the absolute value bounce with a continuous cosine wave:
   $$\text{bounce}(u) = -1.5 \cdot (1.0 - \cos(4\pi u))$$
   This eliminates the infinite jerk at $u = 0.5$ while preserving the double-bounce gait rhythm.
4. **Physically Grounded Backflip:**
   Rotate both `pose.torso.spineAngle` and `pose.headAngle` simultaneously by $p \cdot 360^\circ$ around the center of mass with dynamic knee tucking.

### 10.5 Wire Settings Toggles & Fix Coordinator Races
1. **Enforce `companionAllowSlips` Toggle:**
   In `executeRandomAction()`, guard the `.dangling` branch with `SettingsStore.shared.companionAllowSlips`. Re-integrate the dynamic slip probability during walking traversal.
2. **Restore Deleted Props:**
   Re-implement `drawMiniLaptop` and `drawMiniHeadphones` with floating musical notes for `.typingMimic` and `.musicGroove`.
3. **Implement Focus Mode / DND Listener:**
   Add a distributed notification listener in `CompanionCoordinator` for `com.apple.controlcenter.user-focus-changed` to activate `.sleeping` when Do Not Disturb is active.
4. **Unify Collectible Skin Ears:**
   Replace hardcoded bear ears in `renderLipPeek`, `renderNotchHangAndPullUp`, and `renderChubbyWaddleWalk` with calls to `drawHeadEars(...)`.
5. **Synchronize Click Target Origin:**
   In `CompanionClickPanel.updatePosition`, derive the origin from `pose.headCenter` during peeking so user clicks register reliably on the creature's face.

---

## 11. Remaining Questions & Gaps

1. **Multi-Monitor & External Display Anchoring:**
   When `hasPhysicalNotch` is false (e.g. MacBook connected to an external Apple Studio Display or closed in clamshell mode), should peeking emerge from the top-left screen edge (adjacent to the Apple logo) or remain centered along the top screen edge?
2. **Pull-Up Multi-Rep Workout vs. Single Hang:**
   Clarify product intent for the pull-up behavior: should the creature perform 2–3 continuous workout reps with strain wiggles before resting, or remain a single hold-and-sigh sequence?
3. **Walking Ground Plane Alignment:**
   Determine whether walking should align directly to the bottom line of the menu bar ($y = 24.0\text{ pt}$ / $32.0\text{ pt}$) across all displays, eliminating the mid-air float entirely.
4. **Prioritized Action Plan for Implementation:**
   - **Phase 1 (Critical Visual Fixes):** Fix peeking origin to $y > \text{ledgeY}$, remove dividing neck stroke, and invert painter's algorithm Z-order in pull-ups.
   - **Phase 2 (Kinematic Articulation):** Connect `TwoBoneIK` solver to walking/hanging renderers, reduce stroke thickness to $5.0\text{ pt}$, raise pull-up apex above `ledgeY`, and replace $V$-cusp waddle bounce with smooth harmonic cosine.
   - **Phase 3 (Volumetric Shading & Props):** Deploy 5-stop radial gradient engine and contact shadows across all mascot states, restore deleted laptop and headphone props, and dynamically derive rim shades from skin colors.
   - **Phase 4 (Settings & State Machine):** Wire `companionAllowSlips` guard to `executeRandomAction`, implement DND notification listener, and unify `drawHeadEars` across all renderers.
