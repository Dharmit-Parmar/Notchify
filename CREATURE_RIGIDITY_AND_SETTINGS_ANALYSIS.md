# Comprehensive Forensic Analysis: Creature Settings, Peeking Geometry, 3D Depth & Limb Kinematics

**Target System:** macOS Ambient Notch Desktop Companion (`Bubu` Mascot & Collectibles)  
**Workspace:** `/Users/dharmitparmar/Doc/Notch`  
**Directives Enforced:** No modifications to source code (`.swift` files); exhaustive forensic analysis of working tree diffs, coordinate geometry, settings toggles, physical dips, and kinematic rigidity.  
**Author:** Antigravity Forensic Investigation Worker  

---

## 1. Executive Summary & Forensic Audit of the Code Changes

### 1.1 Context & Problem Statement
The user implemented features intended to bring the chubby cartoon mascot **Bubu** (and collectible archetypes Mochi, Kuro, Boba, Pixel, Cyber) to life around the MacBook notch. However, the resulting active codebase in the working tree exhibits critical flaws observed by the user:
1. **Peeking Malfunction:** The creature cannot peek properly. It appears as an amputated, flat "half-circle on the notch/note" rather than an organic character emerging from behind hardware.
2. **Absence of 3D Volumetric Depth:** The character appears as a flat 2D sticker or planar vector cutout with muddy halos, lacking true 3D toy/plush presence.
3. **Hanging & Pull-Up Failure:** The character appears to hang upside down (resembling a bat or fruit dangling by its heels), fails to clear the ledge during pull-ups, and vanishes mid-air.
4. **Frozen & Rigid Limb Kinematics:** Limbs appear motionless or mechanically rigid (robotic piston slides and static dots), lacking cute, natural animal motion.
5. **Defective Creature Settings & Props:** User settings toggles in `SettingsView.swift` are either disconnected, dead, or have had their visual rendering props (`drawMiniLaptop`, `drawMiniHeadphones`) deleted from the codebase.
6. **The Notch Dip Traversal:** Traversal under the notch and along the ledge exhibits severe vertical displacement ($24\text{ pt}$ float below menu bar, $61\text{ pt}$ drop below notch), causing the creature to walk through mid-air desktop space.

### 1.2 Audit of the User's Git Diff
A line-by-line inspection of the working tree diff across `Sources/Modules/Companion/` reveals the exact origin of these issues:
- **`CreatureRigView.swift` Modifications:**
  - *Deleted Props:* Lines 88–93 (`drawMiniLaptop` and `drawMiniHeadphones`) were deleted.
  - *Deleted Leg Bones:* Lines 722–725 and 743–746 (`drawChubbyLimb` for legs in `renderChubbyMascot`) were deleted, leaving only detached floating foot dots.
  - *Decoupled Walking Limbs:* In `renderChubbyWaddleWalk`, the 2-bone IK solver was bypassed; feet were locked to static $X$ offsets ($\pm 7.5\text{ pt}$) and arms were replaced with rigid vertical pills sliding up and down by $\pm 3.0\text{ pt}$.
  - *The Neck Severance Stroke:* In `renderLipPeek`, `dumplingHeadPath` was rendered as a closed path stroked with a $2.2\text{ pt}$ dark charcoal stroke *after* the torso, slicing the head off with a thick black horizontal border.
  - *Narrow Grip Hanging:* In `renderNotchHangAndPullUp`, hand spacing was narrowed to $16.0\text{ pt}$ for a $34.0\text{ pt}$ head, and arms were rendered as a single quadratic curve with no elbow joint.
- **`KinematicEngine.swift` Modifications:**
  - *The Notch Clamping Trap:* `visibleRouteHead` was modified to clamp `headCenter.y >= ledgeY + 12.0` ($44.0\text{ pt}$), mathematically preventing pull-ups from lifting the head or chin to the ledge ($32.0\text{ pt}$).
  - *Disjoint Traversal Stages:* `routeStage` was fragmented into `.lowerToHang`, `.monkeyBarTraversal`, and `.climbOntoRightLedge`, but `CreatureRigView.swift` only checks for `.lowerToHang` and `.monkeyBarTraversal`, causing `.climbOntoRightLedge` to abruptly revert to a walking gait while hanging $93\text{ pt}$ down.
- **`CompanionCoordinator.swift` Modifications:**
  - *Deleted Walk Slip Trigger:* The slip check inside `companionRouteDidAdvance()` was deleted.
  - *Ignored Settings Toggle:* `executeRandomAction()` triggers `executeSlipSequence()` without respecting `SettingsStore.shared.companionAllowSlips`.

---

## 2. Topic 1: Peeking Malfunction — The "Half-Circle on the Notch" & Missing Emergence

### 2.1 The Coordinate Geometry of the "Half-Circle"
On MacBook displays, the camera notch is a black hardware bezel spanning $y \in [0, 32\text{ pt}]$ between $x = \text{notchLeft}$ and $x = \text{notchRight}$. The illuminated menu bar pixels exist strictly to the left ($x < \text{notchLeft}$) and right ($x > \text{notchRight}$) from $y = 0$ down to $y = \text{ledgeY}$ ($32.0\text{ pt}$).

In [`Sources/Modules/Companion/CreatureRigView.swift:408-427`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L408-L427):
```swift
if side < 0 {
    let startX = engine.notchLeft - 18.0
    let targetX = engine.notchLeft - 32.0
    headX = startX + (targetX - startX) * rise
    headY = gripY - 10.0 - (4.0 * rise)
}
```
Given a 14" MacBook Pro where `notchLeft = 645.5 pt` and `gripY = 32.0 pt`:
- At $t = 0$ (`rise = 0.0`):
  $$\text{headX} = 645.5 - 18.0 = 627.5\text{ pt}$$
  $$\text{headY} = 32.0 - 10.0 = 22.0\text{ pt}$$
- The head width is $\text{headW} = 36.0\text{ pt}$ (radius $R_x = 18.0\text{ pt}$), and height is $\text{headH} = 30.0\text{ pt}$ (radius $R_y = 15.0\text{ pt}$).
- Calculating the bounding box of the head at frame 0:
  $$x_{\min} = 627.5 - 18.0 = 609.5\text{ pt}, \quad x_{\max} = 627.5 + 18.0 = 645.5\text{ pt} = \text{notchLeft}$$
  $$y_{\min} = 22.0 - 15.0 = 7.0\text{ pt}, \quad y_{\max} = 22.0 + 15.0 = 37.0\text{ pt}$$

#### Mathematical Consequence:
1. **Zero Emergence:** At $t = 0$, the head is **not hidden behind the notch**. It is already $100\%$ rendered inside the visible menu bar pixels ($x \in [609.5, 645.5]$).
2. **Static Shift Instead of Rising:** Over the entire 1.2-second animation, $\text{headY}$ only shifts upward by $4.0\text{ pt}$ ($22.0 \to 18.0\text{ pt}$), and $\text{headX}$ translates leftward by $14.0\text{ pt}$. The creature does not "peek" out from behind an occlusion edge; it simply sits against the notch wall and slides sideways.

### 2.2 The Neck Stroke Severance Bug (The Literal "Half-Circle")
In [`CreatureRigView.swift:435-473`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L435-L473):
1. `torsoPath` is drawn at $y \in [headY + 7.0, headY + 29.0\text{ pt}]$.
2. `headShape` is computed via `dumplingHeadPath(width: 36.0, height: 30.0)`.
3. In `dumplingHeadPath` (lines 757–798), the geometry is closed with `path.closeSubpath()`. Its bottom contour runs along $y = \text{headY} + 0.48h = 18.0 + 14.4 = 32.4\text{ pt}$.
4. In line 473, after the torso has already been painted, the renderer executes:
   ```swift
   context.stroke(headShape, with: .color(outlineColor), style: cartoonStrokeStyle)
   ```
5. Because `headShape` is stroked *on top* of the torso with a $2.2\text{ pt}$ dark charcoal stroke, **it paints an opaque black line directly across the neck at $y = 32.4\text{ pt}$**.
6. This black contour line visually amputates the head from the body. The viewer's brain perceives the bottom arc of the head as an isolated, flat, closed semi-circle sitting on the menu bar shelf.

### 2.3 Crushed Arm Geometry & Missing Limbs
In lines 491–525:
- Arms and paws are wrapped in `if rise > 0.15`. During the first $0.18\text{ s}$ of the peek, the head dome floats on screen with **zero arms and zero paws**.
- When `rise > 0.15`, the forearms are drawn as:
  ```swift
  p.move(to: CGPoint(x: headX - 10.0, y: headY + 11.0)) // y = 29.0 pt
  p.addQuadCurve(to: CGPoint(x: pawOuterX, y: gripY - 1.0), ...) // y = 31.0 pt
  ```
- The vertical span of the forearm is only $31.0 - 29.0 = 2.0\text{ pt}$! The arm is flattened into a horizontal line with zero elbow articulation, while paws slide as disconnected pill shapes.

### 2.4 Complete Discard of `evaluatePeek` Choreography
In [`KinematicEngine.swift:944-1076`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L944-L1076), a rich 5-phase storytelling sequence was implemented:
- **Phase 1 ($t < 0.6\text{s}$):** Hidden in den.
- **Phase 2 ($0.6 \le t < 1.6\text{s}$):** Paws reach up first and curl over the notch ledge (`gripY`).
- **Phase 3 ($1.6 \le t < 3.4\text{s}$):** Single-eye curious peek looking around.
- **Phase 4 ($3.4 \le t < 4.2\text{s}$):** Transition dip and eye blink.
- **Phase 5 ($4.2 \le t < 5.8\text{s}$):** Full face reveal with beaming smile.
- **Phase 6 ($t \ge 5.8\text{s}$):** Smooth ducking back into the den.

**The Code Flaw:** In [`CreatureRigView.swift:74`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L74), when `state == .peekingLeft || state == .peekingRight`, it calls `renderLipPeek(...)`. `renderLipPeek` **completely ignores `pose`** and uses its own hardcoded formula. The entire 5-phase kinematic sequence is discarded.

---

## 3. Topic 2: Absence of 3D — Why It Looks Like a 2D Planar Sticker Cutout

### 3.1 The Mathematical Optical Contrast Failure
In `renderLipPeek` (line 465), `renderChubbyWaddleWalk` (line 360), and `renderNotchHangAndPullUp` (line 613):
```swift
let headGrad = Gradient(stops: [
    .init(color: .white.opacity(skin == .kuro ? 0.35 : 0.95), location: 0.0),
    .init(color: bodyColor, location: 0.40),
    .init(color: skin.darkAccentColor.opacity(0.30), location: 1.0)
])
```
1. For the default `.bubu` mascot, `bodyColor` is `Color(red: 0.99, green: 0.99, blue: 0.98)` (pure warm white).
2. Stop 0.0 is `.white.opacity(0.95)` and Stop 0.40 is `bodyColor`.
3. Across the entire core of the head (from radius $0$ to $40\%$), the color difference is $\Delta E < 0.01$ (less than $1\%$). To the human eye, this transition is completely imperceptible. The center of the head reads as a flat, unshaded white disc.

### 3.2 Muddy Perimeter Halos on Collectible Skins
1. At Stop 1.0, the gradient transitions to `skin.darkAccentColor.opacity(0.30)`. For Bubu, `darkAccentColor` is dark chocolate brown (`0.22, 0.14, 0.15`).
2. Blending $30\%$ dark chocolate brown directly over white produces a **muddy, dirty brownish perimeter** rather than an ambient self-shadow or spherical rim light.
3. For skins like `.cyber` (slate chassis) or `.boba` (pastel matcha), this produces severe discoloration at the perimeter.

### 3.3 Flat Solid Mascot Shading
In [`CreatureRigView.swift:1068, 1101`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L1068):
```swift
context.fill(path, with: .color(skin.primaryColor))
context.fill(shape, with: .color(skin.primaryColor))
```
During `.thinking`, `.curious`, `.typingMimic`, `.musicGroove`, `.celebrating`, and `.crawling`, both the head and torso are filled with **$100\%$ flat, solid `skin.primaryColor`** with zero lighting or gradients.

### 3.4 Flat Extremities & Uniform Thick Outlines
- **Limbs and Paws:** Paws (lines 516, 668, 1031), feet (lines 274, 560, 1011), and arms (lines 503, 656, 994) are filled with $100\%$ flat solid color and outlined with a uniform $2.2\text{ pt}$ charcoal stroke.
- **Flash Vector Aesthetic:** A $2.2\text{ pt}$ stroke on an $8\text{ pt}$ shape represents $> 27\%$ of the shape's width. This heavy outline flattens the character into an early-2000s 2D Flash vector sticker.
- **No Occlusion Shadows:** There are zero drop shadows beneath the paws on the notch lip, zero shading beneath the chin on the chest, and zero ambient occlusion in joint creases.

---

## 4. Topic 3: Hanging & Pull-Up Failure — Hanging Upside-Down & Incomplete Pull-Ups

### 4.1 Why the Character Appears to Hang Upside Down
The user observed: *"It is not hanging properly. It is hanging upside down, but I want hanging pull-ups position."*

#### 1. Inverted Silhouette Triangle (The "Dangling Bat" Phenomenon)
- **Hand Spacing:** In [`KinematicEngine.swift:217-218`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L217-L218):
  $$\text{handL} = \text{midX} - 8.0, \quad \text{handR} = \text{midX} + 8.0 \implies \Delta x = 16.0\text{ pt}$$
- **Head Width:** $\text{headW} = 34.0\text{ pt}$.
- **Shoulder Width:** $\text{shoulderW} = 20.0\text{ pt}$.
- **Hanging Arm Length:** In `KinematicEngine.swift:860`:
  $$\text{armLength} = 60.0\text{ pt}$$
- **Root Displacement:**
  $$\text{rootY} = \text{gripY} + 60.0 \cdot \cos(\theta) = 35.0 + 60.0 = 95.0\text{ pt}$$

```
Grip Apex:   (x = midX - 8)  •  • (x = midX + 8)  [Width = 16pt]
Arm Lines:                  /    \                 [Length = 60pt noodle]
Head & Torso:              (  Head  )              [Width = 34pt]
                          (  Torso   )             [Width = 28pt]
Feet:                       •     •                [Kicking at y = 105pt]
```
- In an athletic pull-up or ledge grip, hands are placed **wider than the shoulders** ($\Delta x \approx 36\text{–}44\text{ pt}$), forming an upright V-taper.
- Here, hands spaced $16\text{ pt}$ apart holding a $34\text{ pt}$ wide head suspended $60\text{ pt}$ below creates an extreme **inverted V-shape** ($/\backslash$).
- The silhouette tapers to a narrow apex at the hands and swells to a heavy bulb at the bottom with kicking feet. The visual cortex instantly recognizes this silhouette as an **inverted fruit, dead bat, or opossum dangling upside down by its heels**.

#### 2. Arm Inward Pinch
Because the hands ($\Delta x = 16\text{ pt}$) are narrower than the shoulders ($\Delta x = 20\text{ pt}$), the arms slope inward toward each other at an angle of:
$$\theta = \arctan\left(\frac{10 - 8}{60}\right) \approx 1.9^\circ \text{ inward}$$
This inward slant confirms to the viewer that the limbs are bound together at the apex like tied feet, completely contradicting an athletic hanging posture.

### 4.2 The Chin Clearing Failure & The Unit Test Clamping Trap
In [`KinematicEngine.swift:554, 572, 604`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L554):
```swift
let hangStartY = gripY + 58.0 // 93.0 pt
let topPullUpY = gripY + 26.0 // 61.0 pt
...
let chinTargetY = gripY - 4.0 // 28.0 pt
pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: min(pose.torso.neck.y - 4.0, chinRiseY)))
```
Now examine [`KinematicEngine.swift:119-122`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L119-L122):
```swift
private func visibleRouteHead(at point: CGPoint) -> CGPoint {
    guard hasPhysicalNotch, point.x + 16 > notchLeft, point.x - 16 < notchRight else { return point }
    return CGPoint(x: point.x, y: max(point.y, ledgeY + 12.0))
}
```
And examine [`Tests/CompanionProductionPoseChecks.swift:41, 112`](file:///Users/dharmitparmar/Doc/Notch/Tests/CompanionProductionPoseChecks.swift#L41):
```swift
let headOverlapsNotch = pose.headCenter.x + 16 > engine.notchLeft && pose.headCenter.x - 16 < engine.notchRight
if pose.drawsHead && headOverlapsNotch { assert(pose.headCenter.y - 11 >= engine.ledgeY, "Face overlaps the notch in \(behavior)") }
```
- In `CompanionProductionPoseChecks.swift:41`, the author wrote a unit test assertion stating that if the creature's $X$ coordinate overlaps the notch, its face must not penetrate the notch: `pose.headCenter.y - 11 >= engine.ledgeY`.
- With $\text{ledgeY} = 32.0\text{ pt}$, this requires:
  $$\text{headCenter.y} \ge 32.0 + 11.0 = 43.0\text{ pt}$$
- To satisfy this unit test, `KinematicEngine.swift` clamped `headCenter` with `max(point.y, ledgeY + 12.0)` ($44.0\text{ pt}$).
- **The Mathematical Trap:** In a true pull-up, the chin must rise to the ledge ($y = 32.0\text{ pt}$), and the head center must rise to $y \approx 22.0\text{ pt}$ so the eyes can look over the bar.
- Because `visibleRouteHead` clamps `headCenter.y \ge 44.0\text{ pt}`, **the pull-up is mathematically forbidden from lifting the head above $44.0\text{ pt}$**!
- With `headH = 28.0\text{ pt}`, the chin is located at:
  $$\text{chinY} = \text{headCenter.y} + 14.0 = 44.0 + 14.0 = 58.0\text{ pt}$$
- The notch ledge is at $32.0\text{ pt}$. The chin remains **$26.0\text{ pt}$ below the bar** at the absolute top of the pull-up!
- The character strains and kicks, but its head remains clamped deep below the notch, failing completely to achieve a pull-up posture.

### 4.3 Abrupt Mid-Air Window Disappearance
In [`CompanionCoordinator.swift:344-354`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionCoordinator.swift#L344-L354):
```swift
actionDurationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.state = .pullingUp
        KinematicEngine.shared.setBehavior(.pullingUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.retreatToDen()
        }
    }
}
```
In `retreatToDen()`:
```swift
panel?.orderOut(nil)
clickPanel?.orderOut(nil)
```
At $2.5\text{ s}$ into the pull-up, `retreatToDen()` abruptly calls `orderOut(nil)`. The character **instantly vanishes from the screen mid-frame** while hanging under the notch, with zero climbing recovery or retreat animation.

---

## 5. Topic 4: Frozen / Rigid / Inhuman Limb Movements

### 5.1 Deletion of Leg Bones from `renderChubbyMascot`
A direct diff comparison of `CreatureRigView.swift` lines 721–746 shows:
```diff
- if pose.drawsLegs {
-     drawChubbyLimb(context: &context, p1: rHipPt, p2: rKneePt, p3: rFootPt, thickness: limbThickness, color: backTone, outlineColor: outlineColor)
-     drawChubbyFoot(context: &context, center: rFootPt, angle: 0, size: 7.5, color: backTone, soleColor: soleColor, outlineColor: outlineColor)
- }
+ if pose.drawsLegs {
+     let footPos = CGPoint(x: rFootPt.x, y: min(rFootPt.y, rootPt.y + 10.0))
+     drawChubbyFoot(context: &context, center: footPos, angle: 0, size: 8.0, color: backTone, soleColor: soleColor, outlineColor: outlineColor)
+ }
```
- In the active code, `drawChubbyLimb` for the legs was **completely deleted**.
- Only `drawChubbyFoot` is called.
- During `.thinking`, `.curious`, `.typingMimic`, `.celebrating`, and `.crawling`, **the creature has no legs**. It has two detached oval foot pads floating in empty space beneath the body.
- During `.crawling`, `evaluateCrawling` calculates complex 4-legged quadruped gait IK, but the renderer draws only the front arms, dragging two floating foot dots across the menu bar with zero connecting leg bones.

### 5.2 Walking Limb Rigidity: The 2-Bone IK Solver Bypass
In [`CreatureRigView.swift:269-299`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L269-L299):
```swift
// Left Foot
let leftFootX: CGFloat = -7.5
let leftFootY: CGFloat = 8.0 + (isLeftPlanted ? 0.0 : swingLift)
...
// Right Foot
let rightFootX: CGFloat = 7.5
let rightFootY: CGFloat = 8.0 + (!isLeftPlanted ? 0.0 : swingLift)
...
// Stubby Arms dangling and swinging at sides
let armSwing = sin(u * 2.0 * .pi) * 3.0
let armLRect = CGRect(x: -16.5, y: -7.0 + armSwing, width: 6.5, height: 11.0)
let armLPath = Path(roundedRect: armLRect, cornerRadius: 3.2)
```
1. **Static Foot Placement:** `leftFootX` is hardcoded to $-7.5\text{ pt}$ and `rightFootX` is hardcoded to $+7.5\text{ pt}$ relative to `bodyTransform`.
   - The feet have **zero horizontal stride** ($\Delta x = 0\text{ pt}$).
   - The feet do not step forward or backward; they merely oscillate vertically by $2.5\text{ pt}$ in place like vibrating pegs.
2. **Mechanical Piston Arms:**
   - The arms are vertical capsules (`6.5 x 11.0 pt`) translated vertically by `armSwing = sin(...) * 3.0`.
   - The arms do not swing forward or backward; they slide strictly up and down on a vertical rail like engine pistons.
   - There is zero shoulder rotation, zero elbow bend, and zero paw articulation.
3. **Wasted Kinematics:** While `KinematicEngine.swift:756-848` (`computeWalkPose`) executes full 2-bone analytical inverse kinematics for all 4 limbs, `renderChubbyWaddleWalk` completely ignores `pose.leftLeg`, `pose.rightLeg`, `pose.leftArm`, and `pose.rightArm`.

### 5.3 Joint Swallowing by Excessive Stroke Thickness
In [`KinematicSkeleton.swift:211`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicSkeleton.swift#L211):
$$\text{length1} = 8.0\text{ pt}, \quad \text{length2} = 8.0\text{ pt}$$
In [`CreatureRigView.swift:979-992`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L979-L992):
```swift
drawChubbyLimb(..., thickness: 7.5, color: bodyColor, outlineColor: outlineColor)
```
- In `drawChubbyLimb`, the limb path is stroked with `lineWidth = 7.5 pt` and `lineJoin = .round`.
- A `.round` join places a circle of diameter $7.5\text{ pt}$ (radius $3.75\text{ pt}$) centered directly on the elbow/knee joint.
- The bone segment length is $8.0\text{ pt}$.
- The joint circle covers:
  $$\frac{7.5}{8.0} = 93.75\% \text{ of the upper arm and forearm length!}$$
- When the elbow flexes $30^\circ$, $45^\circ$, or $90^\circ$, the two bone segments fold entirely inside the circular stroke blob. To the user's eye, there is zero visible articulation—the limb appears as a rigid, unbending mass.

### 5.4 Waddle Frequency Spasm (5.5 Hz Jackhammer)
In [`KinematicEngine.swift:52`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L52) and [`CreatureRigView.swift:250`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L250):
```swift
walkStepDuration = 0.36 // seconds per step
let bounce = -1.5 * (1.0 - cos(4.0 * .pi * u))
```
- A step phase $u \in [0, 1]$ completes in $0.36\text{ s}$.
- The bounce wave argument is $4\pi u$. Over one step ($u = 0 \to 1$), $4\pi u$ travels through $2$ full cycles ($720^\circ$).
- The body bounces up and down **twice during every single step**:
  $$f = \frac{2 \text{ bounces}}{0.36 \text{ s}} \approx 5.56\text{ Hz}$$
- A chubby marshmallow mascot vibrating vertically at $5.56\text{ Hz}$ does not read as a cute waddle; it reads as an aggressive mechanical spasm.

### 5.5 The "Backflip" Owl Neck Rotation
In [`KinematicEngine.swift:1211-1216`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L1211-L1216):
```swift
let p = min(1.0, behaviorTime / 0.8)
let jumpY = CGFloat(sin(p * .pi)) * 14.0
pose.torso.root = visibleBodyRoot(at: CGPoint(x: rootWorldX, y: walkY - 14.0 - jumpY))
pose.torso.spineAngle = -.pi / 2.0 + (p * 2.0 * .pi)
pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: pose.torso.neck.y - 8.0))
pose.headAngle = p * 360.0
```
- When the user taps the mascot or clicks "Backflip" in Settings:
  1. `pose.torso.spineAngle` rotates by $p \cdot 2\pi$ ($360^\circ$).
  2. `pose.headAngle` *also* rotates by $p \cdot 360.0$ ($360^\circ$).
  3. In `drawChubbyHead` (line 1088), the head transform applies `t.rotated(by: headAngle)`.
  4. Because `headCenter` already orbits around `torso.root` as `torso.spineAngle` rotates, adding `headAngle = p * 360.0` rotates the head a **second time**.
  5. The head spins $720^\circ$ relative to the body while the legs remain frozen at fixed offsets (`pose.torso.root.x ± 5.0, root.y + 6.0`), creating an uncanny "exorcist/owl" neck twist.

---

## 6. Topic 5: Forensic Analysis of Creature Settings & Dips ("Analyse Dips")

### 6.1 Dips Analysis — The Physical Notch & Traversal Dips
The companion system attempts to navigate the geometry of modern Mac screens. Modern Apple Silicon displays have a hardware camera notch extending $32\text{ pt}$ downward from the top bezel.

#### 1. Walking Floating $24\text{ pt}$ in Desktop Space
In [`KinematicEngine.swift:40-42`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L40-L42):
```swift
public var ledgeY: CGFloat { notchHeight } // 32.0 pt
private var walkLedgeY: CGFloat { ledgeY + 24.0 } // 56.0 pt
```
- In macOS, the menu bar height is $32.0\text{ pt}$ (on notch displays) or $24.0\text{ pt}$ (on non-notch displays).
- Setting `walkLedgeY = ledgeY + 24.0 = 56.0\text{ pt}` places the walking surface **$24.0\text{ pt}$ below the bottom border of the menu bar**.
- When Bubu waddles across the display, its feet do not walk on the menu bar shelf. They float in mid-air over open application windows and desktop wallpapers.

#### 2. The $61\text{ pt}$ Descent Under the Notch
In `evaluateLowerToHang`:
$$\text{targetY} = \text{gripY} + 58.0 = 35.0 + 58.0 = 93.0\text{ pt}$$
- To traverse under the notch, the creature descends to $y = 93.0\text{ pt}$ ($61.0\text{ pt}$ below the notch).
- This dip reaches into the user's active window content, creating a large, distracting intrusion.

#### 3. The `climbOntoRightLedge` State Machine Visual Glitch
In [`CreatureRigView.swift:76-82`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L76-L82):
```swift
} else if state == .dangling || state == .slipping || state == .pullingUp ||
          (state == .walking && (engine.routeStage == .lowerToHang || engine.routeStage == .monkeyBarTraversal)) {
    renderNotchHangAndPullUp(context: &context, pose: pose, skin: skin)
} else if state == .walking {
    renderChubbyWaddleWalk(context: &context, pose: pose, skin: skin)
}
```
- Notice the condition: `(engine.routeStage == .lowerToHang || engine.routeStage == .monkeyBarTraversal)`.
- When `engine.routeStage` advances to **`.climbOntoRightLedge`**, that condition becomes **`false`**!
- The renderer falls through to `else if state == .walking`, which invokes **`renderChubbyWaddleWalk`**!
- At this moment in `evaluateClimbOntoLedge`, the creature's body is still suspended at $y = 93.0\text{ pt}$ under the notch.
- **The Visual Glitch:** The hanging pull-up posture instantly snaps into a waddling mascot walking in empty air at $y = 93.0\text{ pt}$, sliding diagonally up to the menu bar.

---

### 6.2 Settings Analysis — Broken Toggles & Deleted Assets

#### 1. `companionMimicTyping` (Invisible Ghost Laptop)
- **Settings Promise:** *"Whips out a miniature laptop and frantically taps paws while you type."*
- **Code Reality:** In the working tree diff on `CreatureRigView.swift`, the code calling `drawMiniLaptop` and the implementation of `drawMiniLaptop` itself were **deleted**.
- When `triggerTypingMimic()` fires, `renderChubbyMascot` executes with front paws tapping alternately in mid-air. The laptop is completely invisible.

#### 2. `companionGrooveMusic` (Missing Headphones & Notes)
- **Settings Promise:** *"Puts on tiny headphones and bobs head with floating notes when audio/video plays."*
- **Code Reality:** The call to `drawMiniHeadphones` and the function itself were **deleted** from `CreatureRigView.swift`.
- When music or YouTube video plays, the creature bobs its head with no headphones and no floating notes.

#### 3. `companionAllowSlips` (Broken Logic)
- **Settings Promise:** *"Occasionally slips off the bottom lip of the notch, dangles with kicking feet, and climbs back up."*
- **Code Reality:**
  1. The user deleted the spontaneous slip trigger from `companionRouteDidAdvance()`. Slips **never happen naturally while walking**.
  2. In `CompanionCoordinator.swift:234-239`, when `executeRandomAction()` randomly selects `.dangling`:
     ```swift
     case .dangling, .slipping, .pullingUp:
         if SettingsStore.shared.companionAllowSlips {
             executeSlipSequence()
         } else {
             triggerPeek(side: .left)
         }
     ```
     Turning the toggle OFF does not suppress activity; it merely substitutes a left peek for a slip. Slips can only be triggered via the explicit button in Settings.

#### 4. `companionSleepDuringDND` (100% Dead Code)
- **Settings Promise:** *"Curled up asleep under the camera with floating Zzz particles during focus sessions."*
- **Code Reality:** A search across the entire repository confirms that `companionSleepDuringDND` is stored in `UserDefaults`, but **is never read, monitored, or referenced by `CompanionCoordinator` or any notification listener**. It is completely inert.

#### 5. Collectible Skins: Hardcoded Bear Ears
- In `CompanionTypes.swift`, 6 collectible skins are defined:
  - `Bubu` & `Mochi`: Round bear ears.
  - `Kuro`: Pointed triangular cat ears (`drawHeadEars` lines 815–829).
  - `Boba`: Coral dinosaur dorsal spines (lines 831–839).
  - `Pixel` & `Cyber`: Robotic antenna with glowing cyan orb (lines 841–848).
- In `renderLipPeek` (lines 455–461), `renderChubbyWaddleWalk` (lines 350–356), and `renderNotchHangAndPullUp` (lines 603–609):
  - All three specialized renderers **hardcode circular bear ears** via `Path(ellipseIn: earLRect)` and `Path(ellipseIn: earRRect)`.
  - They never invoke `drawHeadEars(...)`.
  - When the user selects Kuro, Boba, Pixel, or Cyber, the character displays **round Bubu bear ears** during walking, peeking, and hanging.

#### 6. Click Target Desynchronization
In [`CompanionWindow.swift:141-147`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionWindow.swift#L141-L147):
```swift
let root = pose.root
let screenX = screen.frame.origin.x + root.x - 24.0
let screenY = screen.frame.maxY - root.y - 24.0
```
- `clickPanel` is positioned from `pose.root`.
- In `renderLipPeek`, `pose.root` is ignored and the visible head is placed at local coordinate $y \approx 18.0\text{ pt}$.
- `pose.root` remains down at $y = 68.0\text{ pt}$.
- As a result, the invisible click target window hovers **$50.0\text{ pt}$ below the visible creature**. When the user tries to click on Bubu's peeking face, the click clicks through to desktop icons or underlying windows.

---

## 7. Master Defect Catalog

| ID | Category | Primary File & Lines | Severity | Root Cause | Observable Symptom |
|:---|:---|:---|:---|:---|:---|
| **DEF-01** | Peeking | `CreatureRigView.swift:408-427` | **Critical** | Head initialized at $x \in [609.5, 645.5]$, $y \in [7, 37]$; only shifts $4\text{ pt}$ vertically. | Creature never emerges from behind notch; statically drawn on active menu bar. |
| **DEF-02** | Peeking | `CreatureRigView.swift:463-473` | **Critical** | `dumplingHeadPath` closed path stroked with $2.2\text{ pt}$ dark outline *after* torso. | Opaque black line cuts across neck, rendering head as a severed half-circle dome. |
| **DEF-03** | Peeking | `CreatureRigView.swift:491-525` | **High** | Forearm curve spans only $2\text{ pt}$ vertically; wrapped in `if rise > 0.15`. | Head dome pops up with zero limbs; forearms squashed into flat lines. |
| **DEF-04** | Peeking | `CreatureRigView.swift:74` | **High** | `renderLipPeek` completely ignores `pose` from `KinematicEngine.evaluatePeek`. | Rich 5-stage storytelling peek (paws first, single eye, dip, smile) is lost. |
| **DEF-05** | 3D Depth | `CreatureRigView.swift:465, 360, 613` | **High** | Gradient stops $0.0 \to 0.40$ have $\Delta E < 1\%$ contrast on white fur. | Head core reads as a $100\%$ flat solid white 2D disc with zero lighting. |
| **DEF-06** | 3D Depth | `CreatureRigView.swift:1068, 1101` | **High** | `renderChubbyMascot` fills head and torso with flat solid `skin.primaryColor`. | Thinking, curious, crawling, typing mascot states have zero shading. |
| **DEF-07** | 3D Depth | `CreatureRigView.swift:274, 516, 605` | **High** | Extremities filled with flat unshaded colors and uniform $2.2\text{ pt}$ outlines. | Heavy outlines flatten character into a 2D Flash sticker; zero contact AO. |
| **DEF-08** | Hanging | `KinematicEngine.swift:217, 860` | **Critical** | Hands spaced $16\text{ pt}$ apart with $60\text{ pt}$ long noodle arms for $34\text{ pt}$ head. | Inverted silhouette resembles a bat or fruit dangling upside-down by its heels. |
| **DEF-09** | Pull-Up | `KinematicEngine.swift:119, Tests:41` | **Critical** | Unit test `headCenter.y - 11 >= ledgeY` forces engine to clamp head to $\ge 44\text{ pt}$. | Chin is locked $26\text{ pt}$ below the bar; character cannot perform pull-up. |
| **DEF-10** | Pull-Up | `CreatureRigView.swift:650-662` | **High** | Hanging arms drawn as a single quadratic curve with no elbow joint or IK. | Limbs lack articulation; hands narrower than shoulders slope inward. |
| **DEF-11** | Pull-Up | `CompanionCoordinator.swift:344-354` | **High** | Action timer dismisses window at $2.5\text{ s}$ via `panel?.orderOut(nil)`. | Creature vanishes mid-air mid-frame during pull-up instead of climbing back. |
| **DEF-12** | Limbs | `CreatureRigView.swift:722, 743` | **Critical** | `drawChubbyLimb` for legs was deleted from `renderChubbyMascot`. | Mascot has detached floating foot pads with zero leg bones connecting to hips. |
| **DEF-13** | Limbs | `CreatureRigView.swift:269-299` | **Critical** | `renderChubbyWaddleWalk` locks feet to static $X$ offsets ($\pm 7.5$) and arms to pistons. | Walking limbs do not move; legs have 0 stride and arms slide as rigid rods. |
| **DEF-14** | Limbs | `CreatureRigView.swift:979-992` | **High** | $7.5\text{ pt}$ stroke width on $8.0\text{ pt}$ bone length covers $93.75\%$ of segment. | Elbow round cap swallows both bones; joint flexion turns into unbending blob. |
| **DEF-15** | Limbs | `CreatureRigView.swift:250, Kinematic:52`| **Medium** | Bounce argument $4\pi u$ with $0.36\text{ s}$ step oscillates at $5.56\text{ Hz}$. | Creature vibrates like a jackhammer rather than a relaxed waddling mascot. |
| **DEF-16** | Limbs | `KinematicEngine.swift:1211-1216` | **Medium** | `torso.spineAngle` and `headAngle` both rotate $360^\circ$ around neck. | Head spins $720^\circ$ like an owl/exorcist while legs remain frozen in place. |
| **DEF-17** | Traversal | `KinematicEngine.swift:40-42` | **High** | `walkLedgeY = ledgeY + 24.0 = 56.0\text{ pt}` is $24\text{ pt}$ below the menu bar. | Creature walks in empty desktop space floating above application windows. |
| **DEF-18** | Traversal | `CreatureRigView.swift:76-82` | **High** | `CreatureRigView` does not match `.climbOntoRightLedge`, defaulting to walk. | Hanging creature abruptly snaps into a waddling mascot at $y = 93\text{ pt}$ mid-air. |
| **DEF-19** | Settings | `CreatureRigView.swift:88-93` | **High** | `drawMiniLaptop` and `drawMiniHeadphones` deleted from working tree. | Typing mimic and music groove display bare character with phantom props. |
| **DEF-20** | Settings | `CompanionCoordinator.swift:234, 286` | **High** | Slip trigger deleted from walk; `executeRandomAction` triggers peek when OFF. | Slips never occur while walking; toggle OFF still triggers random actions. |
| **DEF-21** | Settings | `Sources/Core/NotchModule.swift:269` | **Medium** | `companionSleepDuringDND` has zero notification listeners or system observers. | Focus/DND sleep toggle is completely inert and does nothing. |
| **DEF-22** | Settings | `CreatureRigView.swift:350, 455, 603` | **Medium** | Specialized renderers hardcode round bear ears, ignoring `drawHeadEars`. | Kuro cat, Boba dino, and Cyber robot display bear ears in walk and peek. |
| **DEF-23** | Window | `CompanionWindow.swift:141-147` | **High** | Click panel tracks `pose.root`, but peek renders head $50\text{ pt}$ higher. | Interactive click target is displaced $50\text{ pt}$ below visible head; clicks miss. |

---

## 8. Actionable Architectural Blueprints for Future Fixes

*(Note: In strict accordance with user instructions, no production files were modified in this run. The blueprints below provide the exact formulas and architectural contracts for the subsequent implementation phase.)*

### 8.1 Blueprint 1: Organic Peeking with True Occlusion & Connected Geometry
1. **Vertical Emergence from Behind the Bezel:**
   - Anchor peeking origin strictly below the menu bar ledge:
     $$y(t) = (\text{ledgeY} + 18.0) - 26.0 \cdot \text{rise}(t)$$
   - At $t = 0$, $y = 32.0 + 18.0 = 50.0\text{ pt}$ (hidden behind active window space/bezel).
   - As $\text{rise} \to 1.0$, $y \to 24.0\text{ pt}$ (peeking gracefully over the ledge).
2. **Eliminate the Neck Severance Stroke:**
   - In `dumplingHeadPath`, separate the outer crown contour from the chin line.
   - Alternatively, stroke the head contour *before* painting the upper torso fill, ensuring the neck junction remains seamless without a dividing black border.
3. **Paws-First Reveal:**
   - Wire `CreatureRigView` to render the `pose` produced by `KinematicEngine.evaluatePeek`:
     - $t \in [0.6, 1.6\text{s}]$: Two paws appear on the ledge.
     - $t \in [1.6, 3.4\text{s}]$: One curious eye peers over the edge with connected torso.
     - $t \in [4.2, 5.8\text{s}]$: Full smiling face reveals itself.

### 8.2 Blueprint 2: Procedural 5-Stop Volumetric 3D Engine (0 MB RAM Overhead)
Replace flat solid fills and low-contrast gradients with a calibrated procedural lighting shader in SwiftUI `Canvas`:
```swift
// Calibrated Volumetric Faux-3D Radial Lighting Shader (0 MB RAM overhead)
let lightCenter = CGPoint(x: headCenter.x - headW * 0.22, y: headCenter.y - headH * 0.28)
let sphereGrad = Gradient(stops: [
    .init(color: .white.opacity(skin == .kuro ? 0.40 : 0.95), location: 0.0),                  // Specular Highlight Core
    .init(color: skin.primaryColor, location: 0.25),                                            // True Diffuse Mascot Surface
    .init(color: skin.primaryColor.opacity(0.85), location: 0.65),                              // Terminator / Form Shadow
    .init(color: skin.darkAccentColor.opacity(skin == .kuro ? 0.50 : 0.25), location: 0.90),    // Ambient Bounce Rim Light
    .init(color: skin.outlineColor.opacity(0.80), location: 1.0)                                // Contour Edge Tone
])
context.fill(headShape, with: .radialGradient(sphereGrad, center: lightCenter, startRadius: 1.0, endRadius: headW * 0.65))
```
- **Contact Ambient Occlusion (AO):**
  - Add soft drop shadows beneath paws: `ellipseIn: CGRect(x: px - 5, y: gripY - 1, width: 10, height: 3.5)` with `Color.black.opacity(0.25)`.
  - Add neck occlusion shadow under chin: `ellipseIn: CGRect(x: headX - 12, y: headY + 12, width: 24, height: 4.5)` with `Color.black.opacity(0.20)`.

### 8.3 Blueprint 3: Athletic Hanging & True Pull-Up Kinematics
1. **Shoulder-Width Athletic Grip:**
   - Expand hand spacing from $16.0\text{ pt}$ to **$32.0\text{ pt}$**:
     $$\text{handLWorldX} = \text{midX} - 16.0, \quad \text{handRWorldX} = \text{midX} + 16.0$$
   - Reduce dangling arm length from $60.0\text{ pt}$ to **$32.0\text{ pt}$**.
   - The wider grip transforms the inverted dangling shape into an upright, athletic V-taper.
2. **Unclamp Pull-Up Apex & Clear Chin Over the Bar:**
   - In `evaluatePullingUp`, set pull-up apex to:
     $$\text{rootY} = \text{ledgeY} + 14.0\text{ pt}$$
   - Lift `headCenter.y` to $\text{ledgeY} - 4.0\text{ pt}$ ($28.0\text{ pt}$), placing the chin at $y = 38.0\text{ pt}$ and eyes at $y = 26.0\text{ pt}$ (clearly looking over the bar).
   - **Exempt Pull-Ups from Unit Test Clamping:** Update `CompanionProductionPoseChecks.swift:41` to assert notch clearance only during `.walking`, exempting `.pullingUp` and `.dangling`.
   - Update `visibleRouteHead` to unclamp during pull-up workout states.
3. **Flared Elbow 2-Bone IK Articulation:**
   - Solve 2-bone IK for arms with `bendPositive: false` on left and `bendPositive: true` on right, flaring elbows outward past the cheeks ($14\text{ pt}$ lateral displacement) rather than drawing a single quadratic curve.

### 8.4 Blueprint 4: Living Articulated Limbs & Natural Gait
1. **Restore Leg Bones in `renderChubbyMascot`:**
   - Re-insert `drawChubbyLimb` calls for legs connecting `torso.leftHipAnchor` $\to$ `knee` $\to$ `foot`.
2. **Connect 2-Bone IK in Walking (`renderChubbyWaddleWalk`):**
   - Connect `pose.leftLeg` and `pose.rightLeg` from `computeWalkPose` to `drawChubbyLimb`.
   - Set stride length to $12.0\text{ pt}$ with alternating foot planting, eliminating static X pegs.
3. **Calibrate Limb Stroke Width:**
   - Reduce `limbThickness` from $7.5\text{ pt}$ to **$5.0\text{ pt}$** with an inner fill of $2.8\text{ pt}$.
   - At $5.0\text{ pt}$, the elbow join circle covers only $62\%$ of bone length, allowing visible joint flexion.
4. **Relax Waddle Harmonic Bounce:**
   - Change bounce frequency to single harmonic wave per step:
     $$\text{bounce}(u) = -1.8 \cdot \sin(\pi u)$$
   - At $1.8\text{ pt}$ bounce once per step, the oscillation frequency drops from $5.56\text{ Hz}$ to a gentle, adorable $2.77\text{ Hz}$.
5. **Physically Grounded Backflip:**
   - Synchronize body rotation: Rotate torso and head together around the center of mass with tucking knees:
     $$\text{spineAngle} = -\frac{\pi}{2} + 2\pi p, \quad \text{kneeTuck} = 8.0 \cdot \sin(\pi p)$$

### 8.5 Blueprint 5: Re-Align Walking Ground Plane & Wire Settings
1. **Menu Bar Alignment:**
   - Align `walkLedgeY` directly to the bottom border of the menu bar:
     $$\text{walkLedgeY} = \text{ledgeY} + 2.0\text{ pt} = 34.0\text{ pt}$$
   - Eliminates the $24\text{ pt}$ floating desktop gap.
2. **Restore Props:**
   - Re-implement `drawMiniLaptop` for typing mimicry and `drawMiniHeadphones` with floating musical notes for music groove.
3. **Wire `companionSleepDuringDND`:**
   - Register a distributed notification observer for `com.apple.controlcenter.user-focus-changed` to transition into `.sleeping`.
4. **Unify Collectible Skin Ears:**
   - Replace hardcoded bear ear ellipses in `renderLipPeek`, `renderChubbyWaddleWalk`, and `renderNotchHangAndPullUp` with calls to `drawHeadEars(...)`.
5. **Synchronize Click Target Origin:**
   - In `CompanionClickPanel.updatePosition`, anchor origin to `pose.headCenter` during peeking states so clicks register on the face.

---

## 9. Remaining Questions & Gaps

1. **External & Clamshell Displays:**
   - When `hasPhysicalNotch == false` (e.g. external studio display or clamshell mode), should peeking emerge from behind the Apple menu logo in the far top-left or remain anchored at the screen center?
2. **Multi-Rep Pull-Up Workout:**
   - Should the creature perform multiple continuous pull-up reps (e.g., 2–3 repetitions with strain wiggles) before resting, or remain a single hold-and-sigh sequence?
3. **What the Next Worker Should Prioritize:**
   - **Step 1:** Fix `visibleRouteHead` and unit test clamping in `CompanionProductionPoseChecks.swift` to allow chin clearance in pull-ups.
   - **Step 2:** Restore leg bone drawing in `renderChubbyMascot` and wire 2-bone IK into `renderChubbyWaddleWalk`.
   - **Step 3:** Re-anchor peeking origin below `ledgeY` and remove the dividing neck stroke in `renderLipPeek`.
   - **Step 4:** Re-implement mini laptop and headphone props and wire `companionSleepDuringDND`.
