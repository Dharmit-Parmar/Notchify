# Comprehensive Deep-Dive Diagnostic & Forensic Analysis: Notch Creature System

**Target Subsystem:** Ambient Notch Companion / Creature Rig  
**Scope of Analysis:** Kinematics, 2D/3D Rendering, Physical Notch Geometry, Behavior State Machine, Coordinate Systems, and Settings Architecture  
**Analyzed Source Files:**
- [`KinematicEngine.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift)
- [`CreatureRigView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift)
- [`KinematicSkeleton.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicSkeleton.swift)
- [`CompanionCoordinator.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionCoordinator.swift)
- [`CompanionWindow.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionWindow.swift)
- [`CompanionTypes.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionTypes.swift)
- [`SettingsView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Settings/SettingsView.swift)
- [`NotchModule.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Core/NotchModule.swift)
- Test Artifacts: `artifacts/companion-frame-strips/*.png` and [`CompanionProductionPoseChecks.swift`](file:///Users/dharmitparmar/Doc/Notch/Tests/CompanionProductionPoseChecks.swift)

---

## Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [Problem 1: Peeking Broken — Why It Appears as a Cut-off Flat 2D "Half-Circle" with No 3D](#2-problem-1-peeking-broken--why-it-appears-as-a-cut-off-flat-2d-half-circle-with-no-3d)
3. [Problem 2: Upside-Down Hanging & Pull-Up Kinematics Failure](#3-problem-2-upside-down-hanging--pull-up-kinematics-failure)
4. [Problem 3: Why Limbs Are Frozen / Not Moving](#4-problem-3-why-limbs-are-frozen--not-moving)
5. [Problem 4: Settings, Observers, & State Machine Architectural Defects](#5-problem-4-settings-observers--state-machine-architectural-defects)
6. [Problem 5: Prop, Asset, & Spatial Occlusion Bugs](#6-problem-5-prop-asset--spatial-occlusion-bugs)
7. [Comprehensive Defect Matrix](#7-comprehensive-defect-matrix)
8. [Concrete Technical Recommendations (Blueprints for Fixes)](#8-concrete-technical-recommendations-blueprints-for-fixes)

---

## 1. Executive Summary

A deep static analysis and frame-by-frame visual verification of the creature implementation reveals that the issues reported by the user are not isolated visual glitches; they stem from fundamental mathematical miscalculations, anatomical vector inversions, coordinate system conflicts, and incomplete state machines across the Companion subsystem:

1. **Peeking Half-Circle & Lack of 3D:** Peeking disables the torso and leg rendering entirely (`drawsTorso = false; drawsLegs = false`). Only a single flat 2D squircle is drawn for the head at `y = gripY + 2.0 = 37.0pt`. Because the physical MacBook camera housing is an opaque black hardware bezel spanning $y \in [0, 32\text{pt}]$, the top half of the head ($y \in [26, 32\text{pt}]$) is physically hidden behind the hardware bezel. Only the bottom half sticks out below the notch, appearing literally as a severed, flat 2D semicircle. Furthermore, the renderer in [`CreatureRigView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L306) uses a 100% flat vector fill (`context.fill(headPath, with: .color(skin.primaryColor))`) with zero 3D normals, lighting, specular highlights, sphere shading, or depth cues.
2. **Hanging Upside Down & Broken Pull-Ups:** 
   - **Shoulder & Hip Vector Inversion:** In [`KinematicSkeleton.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicSkeleton.swift#L134-L168), the torso normal vector is computed as `(-sin(spineAngle), cos(spineAngle))`. For standard upright/hanging spines ($\text{spineAngle} = -\pi/2$), $-\sin(-\pi/2) = +1.0$. This places the `leftShoulderAnchor` on the *right* of the neck ($+7\text{pt}$) and the `rightShoulderAnchor` on the *left* ($-7\text{pt}$). When the arms reach for the left and right hand grips, the two arms **cross over each other in an "X" directly across the chest and neck**. The same inversion affects the hips and legs, crossing the legs into an "X".
   - **Head Crushed Below Neck in Pull-Up:** During `pullingUp`, as the torso rises to $y=56\text{pt}$ (neck at $y=40\text{pt}$), [`visibleRouteHead`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L110-L114) forcibly clamps `headCenter.y` to $\ge 49\text{pt}$ to satisfy an overly aggressive notch avoidance assertion. As a result, the head is forced **9 points below the neck and inside the stomach**, inverting and crushing the skeleton into an upside-down bundle.
   - **No Pull-Up Reps:** The pull-up behavior is not a cyclic exercise; it executes a single 1.6-second upward translation where the chin never clears the hands, then freezes or retreats.
3. **Immobile Limbs:** In peeking, thinking, sleeping, and hanging, the limb IK target vectors are hardcoded constants (e.g., in peeking, hands are pinned to `(cornerX - 6, gripY)` and legs are hidden). In walking, the creature spawns at $x = 35.0\text{pt}$ at the far left display bezel, requiring 18 seconds of walking to even reach the notch. In addition, the 5.0pt line thickness drawn over 8.0pt bone lengths visually swallows the elbow and knee joints into rigid, unarticulated stubs.
4. **Fatal Settings Observer Bug:** In [`CompanionCoordinator.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionCoordinator.swift#L41-L48), `start()` guards against `isCompanionEnabled`. If disabled on launch, `setupObservers()` is never called. Consequently, toggling the feature "ON" in [`SettingsView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Settings/SettingsView.swift#L1032) fails to trigger the Combine subscriber, leaving the creature permanently dormant.

---

## 2. Problem 1: Peeking Broken — Why It Appears as a Cut-off Flat 2D "Half-Circle" with No 3D

### 2.1 The Code Causing the Cut-Off Half-Circle
In [`KinematicEngine.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L857-L930), the `evaluatePeek(side:dt:)` function defines the creature's pose during peeking:

```swift
// KinematicEngine.swift, Lines 887-904
} else if behaviorTime < 3.4 {
    pose.torso.root = CGPoint(x: cornerX, y: gripY + 18.0)
    pose.headCenter = CGPoint(x: cornerX, y: gripY + 2.0)
    pose.drawsTorso = false  // <--- Torso is explicitly hidden!
    pose.drawsLegs = false   // <--- Legs are explicitly hidden!
    pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: cornerX - 6.0, y: gripY), bendPositive: false)
    pose.leftArm.isPlantedOrGripping = true
    pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: cornerX + 6.0, y: gripY), bendPositive: true)
    pose.rightArm.isPlantedOrGripping = true
    ...
```

Notice what is happening:
1. **Torso & Legs Suppressed:** `pose.drawsTorso = false` and `pose.drawsLegs = false`. The creature has no body, no neck, and no lower limbs rendered.
2. **Physical Notch Occlusion Geometry:**
   - In screen coordinates (where $y=0$ is the top of the physical screen and increases downward in SwiftUI):
     - The physical MacBook notch bezel extends from $y = 0$ down to $y = \text{notchHeight}$ (typically $32.0\text{pt}$ to $38.0\text{pt}$).
     - The code sets $\text{ledgeY} = \text{notchHeight} = 32.0\text{pt}$.
     - It sets $\text{gripY} = \text{ledgeY} + 3.0 = 35.0\text{pt}$.
     - It places the center of the head at `pose.headCenter = CGPoint(x: cornerX, y: gripY + 2.0) = (cornerX, 37.0)`.
   - The head is drawn in [`CreatureRigView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L302-L304) as a squircle of height $\text{headSize} \approx 22.0\text{pt}$:
     $$\text{headRect.minY} = 37.0 - \frac{22.0}{2} = 26.0\text{pt}$$
     $$\text{headRect.maxY} = 37.0 + \frac{22.0}{2} = 48.0\text{pt}$$
   - **The hardware collision:** The physical camera housing on MacBook screens is made of **opaque black glass and aluminum**. The pixels from $y = 26.0\text{pt}$ to $y = 32.0\text{pt}$ are physically positioned behind the notch hardware.
   - Because the upper $6\text{pt}$ (the upper half of the head) lies under the physical black notch, and because `drawsTorso = false`, **only the bottom protruding arc of the squircle ($y \in [32, 48\text{pt}]$) emits light on the display**.
   - To the user, this appears exactly as a **flat, severed 2D semicircle hanging under the notch**.

### 2.2 Peeking in the Wrong Place (Bottom Edge vs. Side Curves)
In [`CompanionTypes.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionTypes.swift#L100-L101), the specification states:
```swift
case peekingLeft   // Peeking from left curve of notch
case peekingRight  // Peeking from right curve of notch
```
A true notch peek on a MacBook must emerge from behind the **lateral rounded ears / side vertical radiuses of the notch**, leaning horizontally into the menu bar:
- `cornerX` should be placed laterally along the notch radius ($x < \text{notchLeft}$ or $x > \text{notchRight}$), with $y$ positioned midway up the notch ($y \approx \text{notchHeight} / 2$).
- The torso should lean outward at an angle ($\text{spineAngle} \approx \pm 0.35\text{ rad}$), with one or two paws gripping the vertical curve.
- Instead, [`evaluatePeek`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L861) hardcodes `cornerX = notchLeft - 16.0` and anchors $y$ **below the bottom ledge**, completely missing the side curve.

### 2.3 Why It Looks 2D Instead of 3D
In [`CreatureRigView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L306-L307):
```swift
context.fill(headPath, with: .color(skin.primaryColor))
context.stroke(headPath, with: .color(Color.white.opacity(0.2)), lineWidth: 0.8)
```
1. **Flat 2D Canvas Fill:** The head is drawn with a single uniform solid color (`skin.primaryColor`, e.g., solid flat white `#FAFAF2` for Mochi or solid flat green `#73D18C` for Boba).
2. **Zero Shading / Depth:**
   - There is no radial gradient simulating a 3D sphere or pill.
   - There is no ambient occlusion or drop shadow cast onto or from the notch edge.
   - There is no specular highlight or rim lighting to indicate curvature or volume.
   - There are no 3D surface normals or depth buffer rendering.
3. **2D Eyes and Limbs:** Eyes are drawn as flat black ellipses (`context.fill(Path(ellipseIn: eyeRect))`), and limbs are simple 2-segment stroked poly-lines (`context.stroke(path, style: StrokeStyle(lineWidth: 4.5))`).

---

## 3. Problem 2: Upside-Down Hanging & Pull-Up Kinematics Failure

### 3.1 The Shoulder & Pelvis Inversion Bug (Crossed Limbs)
Look at the mathematical derivation of torso anchors in [`KinematicSkeleton.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicSkeleton.swift#L118-L169):

```swift
public struct TorsoBones: Equatable {
    public var root: CGPoint = .zero            // Hips center
    public var spineAngle: Double = -.pi / 2.0  // Points upward by default
    public var spineLength: CGFloat = 16.0
    public var shoulderWidth: CGFloat = 14.0
    public var hipWidth: CGFloat = 12.0
    
    public var neck: CGPoint {
        CGPoint(
            x: root.x + cos(spineAngle) * spineLength,
            y: root.y + sin(spineAngle) * spineLength
        )
    }
    
    // Normal vector perpendicular to spine
    private var normalVector: CGPoint {
        CGPoint(x: -sin(spineAngle), y: cos(spineAngle))
    }
    
    public var leftShoulderAnchor: CGPoint {
        let n = normalVector
        return CGPoint(
            x: neck.x + n.x * (shoulderWidth / 2.0),
            y: neck.y + n.y * (shoulderWidth / 2.0)
        )
    }
    
    public var rightShoulderAnchor: CGPoint {
        let n = normalVector
        return CGPoint(
            x: neck.x - n.x * (shoulderWidth / 2.0),
            y: neck.y - n.y * (shoulderWidth / 2.0)
        )
    }
...
```

Let us evaluate the math when the creature is hanging vertically ($\text{spineAngle} = -\frac{\pi}{2}$):
1. **Neck position:**
   $$\cos(-\pi/2) = 0, \quad \sin(-\pi/2) = -1$$
   $$\text{neck} = (\text{root}.x + 0 \cdot 16, \text{root}.y + (-1) \cdot 16) = (\text{root}.x, \text{root}.y - 16)$$
   In SwiftUI screen coordinates ($y$ increases downward), $\text{root}.y - 16$ is above $\text{root}.y$. This correctly places the neck above the hips.
2. **Normal vector ($n$):**
   $$n.x = -\sin(-\pi/2) = -(-1.0) = \mathbf{+1.0}$$
   $$n.y = \cos(-\pi/2) = 0.0$$
3. **Shoulder Anchors:**
   $$\text{leftShoulderAnchor}.x = \text{neck}.x + (+1.0) \cdot 7.0 = \mathbf{\text{neck}.x + 7.0 \quad (\text{Screen Right!})}$$
   $$\text{rightShoulderAnchor}.x = \text{neck}.x - (+1.0) \cdot 7.0 = \mathbf{\text{neck}.x - 7.0 \quad (\text{Screen Left!})}$$

**The Left Shoulder is placed on the RIGHT side of the body, and the Right Shoulder is placed on the LEFT side of the body!**

Now examine [`evaluateHangingUnderNotch`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L809-L812):
```swift
// Left hand grips handLWorldX (which is on the LEFT: midX - 8.0)
pose.leftArm.solveIK(from: pose.torso.leftShoulderAnchor, toward: CGPoint(x: handLWorldX, y: gripY), bendPositive: false)

// Right hand grips handRWorldX (which is on the RIGHT: midX + 8.0)
pose.rightArm.solveIK(from: pose.torso.rightShoulderAnchor, toward: CGPoint(x: handRWorldX, y: gripY), bendPositive: true)
```
- The **Left Arm** originates at `leftShoulderAnchor` (which is at $\text{neck}.x + 7.0$, on the **right**) and reaches leftward toward `handLWorldX` ($\text{midX} - 8.0$, on the **left**).
- The **Right Arm** originates at `rightShoulderAnchor` (which is at $\text{neck}.x - 7.0$, on the **left**) and reaches rightward toward `handRWorldX` ($\text{midX} + 8.0$, on the **right**).
- **Result:** The arms **cross over each other in an "X" directly in front of the creature's chest and head**.
- Exactly the same bug exists in `leftHipAnchor` and `rightHipAnchor`, causing the legs to cross over in an "X" as well (as verified visually in `artifacts/companion-frame-strips/hang.png`).

### 3.2 The Head-Inversion Clamping Bug in Pull-Ups
During `pullingUp`, the user expects the creature to perform a pull-up: gripping the notch lip, engaging its arms, flexing elbows downward/backward, pulling its chin and eyes **up level with or above the notch lip**, and cycling smoothly.

Instead, look at lines 831-838 of [`KinematicEngine.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L831-L838):
```swift
let rootY = pullUpStartY + (ledgeY + 24.0 - pullUpStartY) * easedLift
let rootX = (handLWorldX + handRWorldX) / 2.0

pose.torso.root = CGPoint(x: rootX, y: rootY)
pose.torso.spineAngle = -.pi / 2.0 + sin(Double(liftProgress) * .pi) * 0.12
pose.headCenter = visibleRouteHead(at: CGPoint(x: pose.torso.neck.x, y: pose.torso.neck.y - 18.0))
```

And look at `visibleRouteHead` (lines 110-114):
```swift
private func visibleRouteHead(at point: CGPoint) -> CGPoint {
    let headExtent: CGFloat = 16.0
    guard hasPhysicalNotch, point.x + headExtent > notchLeft, point.x - headExtent < notchRight else { return point }
    return CGPoint(x: point.x, y: max(point.y, ledgeY + headExtent + 1.0))
}
```

Trace what happens as the pull-up reaches its peak ($\text{liftProgress} = 1.0$):
1. `rootY` reaches $\text{ledgeY} + 24.0 = 32.0 + 24.0 = 56.0\text{pt}$.
2. The neck is at $\text{rootY} - 16.0 = 40.0\text{pt}$.
3. The formula requests the head at $\text{neck}.y - 18.0 = 40.0 - 18.0 = 22.0\text{pt}$.
4. Because the creature is directly under the notch ($x \in [\text{notchLeft}, \text{notchRight}]$), `visibleRouteHead` intercepts this and executes:
   $$y = \max(22.0, \text{ledgeY} + 16.0 + 1.0) = \max(22.0, 32.0 + 17.0) = \mathbf{49.0\text{pt}}$$
5. **The fatal inversion:**
   - `neck.y` = **40.0pt** (higher up)
   - `headCenter.y` = **49.0pt** (lower down!)
   - `root.y` = **56.0pt**
6. **The head is forced BELOW the neck and into the torso!**
   Instead of pulling up over the ledge, the body rises while the head is blocked by `visibleRouteHead`. The creature literally squashes its own neck, inverting its head into its abdomen.
7. Furthermore, the hands are at $y = \text{gripY} = 35.0\text{pt}$. The neck ($40.0\text{pt}$) never rises above the hands ($35.0\text{pt}$). The chin never clears the bar.

### 3.3 Static Damped Pendulum (Dead Hang)
In [`evaluateHangingUnderNotch`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L788-L794):
```swift
pendulumVelocity += angularAccel * dt
pendulumAngle += pendulumVelocity * dt
if abs(pendulumAngle) > 0.14 {
    pendulumAngle = max(-0.14, min(0.14, pendulumAngle))
    pendulumVelocity = 0.0  // <--- Velocity is brutally zeroed on frame 1!
}
```
In `setupHanging`, `pendulumAngle` is initialized to `0.20`. On the very first frame of hanging, `0.20 > 0.14`, so `pendulumAngle` is clamped to `0.14` and **`pendulumVelocity` is reset to 0.0**. The pendulum's initial kinetic energy is completely wiped out, resulting in a dead, lifeless hang with zero swing.

---

## 4. Problem 3: Why Limbs Are Frozen / Not Moving

The user noticed: *"There is no limbs of it which are moving."* Multiple compounding factors cause the limbs to appear completely stationary across different states:

### 4.1 State-by-State Limb Analysis

| Behavior State | Arm Motion | Leg Motion | Root Cause in Code |
| :--- | :--- | :--- | :--- |
| **Peeking** (`peekingLeft`, `peekingRight`) | **0% (Frozen)** | **0% (Hidden)** | `drawsLegs = false`. Arms are pinned to static target points `(cornerX - 6.0, gripY)` and `(cornerX + 6.0, gripY)`. |
| **Dangling / Slip** | **0% (Frozen)** | **Microscopic jitter** | Hands are pinned to `handLWorldX` and `handRWorldX`. Arms never bend or articulate. Pendulum velocity is zeroed at line 793. |
| **Pull-Up** | **Passive Compression Only** | **Static 14pt tuck** | Hands remain frozen at `gripY`. Arms only compress because root ascends. No muscular flexion or pull-up cycling. |
| **Thinking / Curious** | **0% (Frozen)** | **0% (Frozen)** | Left arm pinned to root ($-7, -2$); right arm pinned to chin ($+3, +6$). Legs pinned to floor. |
| **Sleeping** | **0% (Frozen)** | **0% (Frozen)** | Arms and legs pinned to static floor coordinates. View is explicitly paused (`paused: coordinator.state == .sleeping`). |
| **Music Groove** | **0% (Frozen)** | **0% (Frozen)** | Hands are permanently welded to headphones (`headCenter.x ± 11.0, headCenter.y + 4.0`). Legs are frozen. |
| **Typing Mimic** | **1-Bit Micro-Jitter (±3pt)** | **0% (Frozen)** | Legs are frozen. Paws only toggle a boolean 3pt vertical shift (`pawAlt ? -3.0 : 0.0`). |
| **Walking (Full Route)** | **Normal Gait** | **Normal Gait** | **Spawn Distance Bug:** Walks start at $x = 35.0\text{pt}$ (far left corner of screen). It takes 18 seconds to reach the notch! Users observing the notch see zero movement. |

### 4.2 Joint Visual Occlusion (Thick Lines on Short Bones)
In [`KinematicSkeleton.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicSkeleton.swift#L211-L214), the limbs have bone lengths:
$$\text{length1} = 8.0\text{pt}, \quad \text{length2} = 8.0\text{pt} \implies \text{Total Reach} = 16.0\text{pt}$$
In [`CreatureRigView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L115-L122), the limbs are drawn with:
```swift
drawLimb(context: &context, p1: lHipPt, p2: lKneePt, p3: lFootPt, thickness: 5.0, color: frontTone)
drawLimb(context: &context, p1: lShoulderPt, p2: lElbowPt, p3: lHandPt, thickness: 4.5, color: frontTone)
```
- A line thickness of $5.0\text{pt}$ with `.round` cap and `.round` join applied to an $8.0\text{pt}$ bone segment covers more than 60% of the bone's length.
- When the joint bends slightly (e.g. during a subtle step or sway), the round cap overlapping at the joint completely obscures the bend angle. To the human eye on a Retina screen, it appears as an unarticulated, rigid sausage or tooth-pick stub.

### 4.3 SwiftUI Canvas Architecture Issue: State Mutation in `onChange`
In [`CreatureRigView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L29-L45):
```swift
.onChange(of: timelineContext.date) { _, _ in
    ...
    engine.update(
        deltaTime: 1.0 / 60.0,
        cursorScreenPos: cursorScreenPos
    )
    coordinator.companionRouteDidAdvance()
    CompanionPanel.shared?.clickPanel?.updatePosition(pose: engine.currentPose, screen: screen)
}
```
- `engine.update` mutates `@Published public var currentPose: SkeletonPose`.
- Calling state mutations on an `@ObservedObject` inside a view's `.onChange(of: timelineContext.date)` triggers an `objectWillChange` publication while SwiftUI is evaluating the current render cycle.
- In macOS 14/15, SwiftUI frequently suppresses or drops rapid back-to-back render evaluations caused by `@ObservedObject` updates originating from inside a `TimelineView` body, causing frame drops or freezing animations entirely until an external event (like cursor movement) forces a redraw.

---

## 5. Problem 4: Settings, Observers, & State Machine Architectural Defects

### 5.1 The Fatal Observer Registration Bug (Settings Toggle Broken)
Look at [`CompanionCoordinator.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionCoordinator.swift#L41-L85):

```swift
// CompanionCoordinator.swift, Lines 41-48
public func start() {
    guard SettingsStore.shared.isCompanionEnabled else { return } // <--- Exits if disabled!
    guard !isStarted else { return }
    isStarted = true
    setupObservers()  // <--- Observers registered HERE!
    setupTypingMonitor()
    scheduleNextBehavior()
}

// CompanionCoordinator.swift, Lines 68-85
private func setupObservers() {
    guard !isObserving else { return }
    isObserving = true
    
    // 1. Observe Settings Enable / Disable Toggle
    SettingsStore.shared.$isCompanionEnabled
        .dropFirst()
        .receive(on: RunLoop.main)
        .sink { [weak self] enabled in
            guard let self = self else { return }
            if enabled {
                self.start()
            } else {
                self.stop()
            }
        }
        .store(in: &cancellables)
    ...
```

**The Catch-22 Bug:**
1. At application launch, [`AppDelegate.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/App/AppDelegate.swift#L139) calls `CompanionCoordinator.shared.start()`.
2. If `SettingsStore.shared.isCompanionEnabled` is `false` (default or previously turned off), `start()` hits `guard SettingsStore.shared.isCompanionEnabled else { return }` and **exits immediately**.
3. Because it exits, `setupObservers()` is **never called**.
4. The Combine subscription to `$isCompanionEnabled` is **never registered**.
5. When the user opens Preferences and clicks the toggle to enable the Companion, `SettingsStore.shared.isCompanionEnabled` updates to `true` in `UserDefaults`, **but `CompanionCoordinator` receives zero notification**.
6. The companion never starts until the entire application is restarted with the setting already saved as `true`.

### 5.2 Dead Settings (Phantom Toggles with Zero Underlying Logic)
1. **Sleep During Focus & Do Not Disturb (`companionSleepDuringDND`):**
   - In [`SettingsView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Settings/SettingsView.swift#L1253), a prominent toggle exists for *"Sleep During Focus & Do Not Disturb"*.
   - In [`NotchModule.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Core/NotchModule.swift#L269), `@Published public var companionSleepDuringDND: Bool = true` is persisted to `UserDefaults`.
   - **Grep Verification:** `companionSleepDuringDND` is **never referenced or checked anywhere else in the entire codebase**. There is no DND notification listener (`com.apple.notificationcenterui.dndprefs` or `NSDistributedNotificationCenter`), no focus status check, and no logic in `CompanionCoordinator`. It is a 100% phantom setting.
2. **Activity Level Picker (`companionActivityLevel`):**
   - When the user changes activity level from "Calm" (60–120s) to "Playful" (15–30s) in Settings, `schedulerTimer` in `CompanionCoordinator` is not cancelled or rescheduled. The companion remains asleep for the full duration of whatever timer was already active (up to 2 minutes).

### 5.3 Test Action Button Disconnects in Settings
In [`SettingsView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Settings/SettingsView.swift#L1048-L1074), buttons are provided to test animations:
- "Walk (Gait)", "Hang & Pull-Up", "Think & Track", "Type Mimic", "Backflip".
- When "Type Mimic", "Think & Track", or "Backflip" is triggered directly, their setup methods in [`KinematicEngine.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L209-L235) (`setupTyping()`, `setupThinking()`, `setupCelebrating()`) **fail to initialize `rootWorldX`**.
- As a result, the creature uses whatever `rootWorldX` was left behind by a previous animation (e.g. $x = 35.0\text{pt}$ at the far left edge of the display, or $x = 1440.0\text{pt}$ at the far right corner), rendering the test action completely off-screen or invisible to the user.

---

## 6. Problem 5: Prop, Asset, & Spatial Occlusion Bugs

### 6.1 The Disconnected Miniature Laptop
In [`CreatureRigView.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CreatureRigView.swift#L125-L126,L466-L472):
```swift
if coordinator.state == .typingMimic {
    drawMiniLaptop(context: &context, position: CGPoint(x: rootPt.x, y: engine.ledgeY - 4))
}
...
private func drawMiniLaptop(context: inout GraphicsContext, position: CGPoint) {
    let base = CGRect(x: position.x - 8, y: position.y - 1.5, width: 16, height: 3)
    let screen = CGRect(x: position.x - 7, y: position.y - 10, width: 14, height: 9)
    ...
```
1. `position.y` is passed as `engine.ledgeY - 4`. Since $\text{ledgeY} = 32.0\text{pt}$, the laptop is drawn at:
   $$y = 32.0 - 4.0 = \mathbf{28.0\text{pt}}$$
   The laptop screen spans $y \in [18, 27\text{pt}]$.
2. This is located **inside the physical MacBook notch bezel**, making the laptop completely invisible behind the hardware plastic on real MacBook screens.
3. Meanwhile, in [`evaluateTyping`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L991-L992), the paws are typing at:
   $$y = \text{walkLedgeY} - 7.0 = 56.0 - 7.0 = \mathbf{49.0\text{pt}}$$
4. **Spatial Disconnect:** The laptop is at $y = 28\text{pt}$ (behind the notch bezel), and the paws are tapping in thin air at $y = 49\text{pt}$, **21 points below the laptop keyboard!**

### 6.2 Crawling Stride Division by Zero (Stuck in Place)
In [`KinematicEngine.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/KinematicEngine.swift#L151-L159,L1033-L1035):
```swift
if hasPhysicalNotch && rootWorldX >= notchLeft - 42.0 && rootWorldX <= notchRight + 42.0 {
    rootWorldX = rootWorldX < (notchLeft + notchRight) / 2.0 ? notchLeft - 42.0 : notchRight + 42.0
}
crawlRootStartX = rootWorldX
crawlDirection = hasPhysicalNotch ? (rootWorldX < notchLeft ? 1.0 : -1.0) : ...
crawlBoundary = hasPhysicalNotch ? (crawlDirection > 0 ? notchLeft - 42.0 : notchRight + 42.0) : ...
crawlStride = nextCrawlStride()
```
And `nextCrawlStride()`:
```swift
min(14.0, max(0.0, (crawlBoundary - crawlRootStartX) * crawlDirection))
```
- If `rootWorldX` is clamped to `notchLeft - 42.0`, then `crawlRootStartX = notchLeft - 42.0`.
- Then `crawlBoundary = notchLeft - 42.0`.
- Therefore, `(crawlBoundary - crawlRootStartX) = 0.0`.
- `crawlStride` is calculated as **0.0pt**.
- When `evaluateCrawling` runs, $\text{rootWorldX} = \text{crawlRootStartX} + 0 \cdot \text{reach} = \text{constant}$.
- **The creature is trapped crawling in place with 0 velocity.**

---

## 7. Comprehensive Defect Matrix

| ID | Component | Location | Severity | Defect Description | User Impact |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **DEF-01** | `KinematicEngine` | `KinematicEngine.swift:866-922` | **Critical** | `drawsTorso` and `drawsLegs` set to `false` during peeking; head $y$-coordinate placed behind notch bezel ($y \in [26, 48]$). | Peeking appears as an amputated, flat 2D semicircle sticking out below the notch. |
| **DEF-02** | `CreatureRigView` | `CreatureRigView.swift:306-307` | **High** | Head, torso, and limbs rendered using flat 2D vector fills without shading, speculars, spherical normals, or 3D depth. | Creature lacks any 3D volume, looking like a flat sticker. |
| **DEF-03** | `KinematicSkeleton` | `KinematicSkeleton.swift:134-168` | **Critical** | Torso normal vector formula $-\sin(\theta)$ inverts shoulders and hips when $\theta = -\pi/2$, swapping left and right anchors. | Hanging creature has arms and legs crossed over each other in an "X". |
| **DEF-04** | `KinematicEngine` | `KinematicEngine.swift:110-114, 838` | **Critical** | `visibleRouteHead` forcibly clamps `headCenter.y >= 49.0` while neck rises to $40.0$, pushing head below neck. | Pull-up crushes the head inside the torso/stomach, making the body look inverted/upside-down. |
| **DEF-05** | `KinematicEngine` | `KinematicEngine.swift:791-794` | **Medium** | Damped pendulum angle clamp (`> 0.14`) resets `pendulumVelocity = 0.0` on frame 1. | Dangling hang has zero dynamic swing (dead hang). |
| **DEF-06** | `KinematicEngine` | Multiple locations | **High** | Limbs in peeking, thinking, sleeping, and hanging have hardcoded constant IK targets; limb thickness swallows joints. | Limbs are completely frozen or appear as rigid unmoving stubs. |
| **DEF-07** | `CompanionCoordinator` | `CompanionCoordinator.swift:41-85` | **Critical** | `start()` exits early if disabled on launch, preventing `setupObservers()` from ever subscribing to `$isCompanionEnabled`. | Creature cannot be enabled from Settings without a complete app restart. |
| **DEF-08** | `SettingsStore` / `Coordinator` | `NotchModule.swift:269`, `SettingsView.swift:1253` | **Medium** | `companionSleepDuringDND` toggle exists in UI/Store but has zero implementation in coordinator. | Focus/DND sleep feature is completely non-functional. |
| **DEF-09** | `KinematicEngine` | `KinematicEngine.swift:184` | **Medium** | `setupFullRouteWalk` starts at $x = 35.0\text{pt}$ (far left corner). | Walking test button appears to do nothing for 18 seconds while creature is off-screen. |
| **DEF-10** | `CreatureRigView` | `CreatureRigView.swift:126, 466` | **Medium** | Miniature laptop is drawn at $y=28\text{pt}$ (inside physical notch), while paws type at $y=49\text{pt}$. | Laptop is occluded by the notch hardware; creature types in thin air. |
| **DEF-11** | `KinematicEngine` | `KinematicEngine.swift:151-159, 1034` | **Medium** | `crawlBoundary` equals `crawlRootStartX`, causing `crawlStride` to evaluate to $0.0$. | Creature is frozen crawling in place. |
| **DEF-12** | `CreatureRigView` | `CreatureRigView.swift:29-45` | **High** | `engine.update` mutates `@Published currentPose` inside `.onChange(of: timelineContext.date)`. | Violates SwiftUI state lifecycle, causing dropped frames or animation freezes. |

---

## 8. Concrete Technical Recommendations (Blueprints for Fixes)

> **Note:** In strict adherence to your instructions, **no existing code has been altered**. The following architectural blueprints outline the exact code modifications required for the subsequent implementation phase.

### Recommendation 1: Fix Peeking Geometry & Add 3D Pseudo-Volume / SceneKit
To resolve the flat 2D half-circle:
1. **Redesign Peeking in `KinematicEngine.swift`:**
   - Instead of hiding the torso and legs, **render the full creature leaning out from behind the side curve of the notch**.
   - For `peekingLeft`: Position the root at `x = notchLeft - 18.0, y = notchHeight / 2 + 10.0`. Set `spineAngle = -0.35` (leaning rightward into the display).
   - Place paws gripping the notch's rounded corner: `pose.leftArm` grips `(notchLeft - 2.0, notchHeight - 8.0)`.
   - Ensure `drawsTorso = true`, `drawsHead = true`, and `drawsArms = true`.
2. **Add 3D Shading to `CreatureRigView.swift`:**
   - Replace the flat `context.fill(headPath, with: .color(skin.primaryColor))` with a **3D radial shading model**:
     ```swift
     let lightCenter = CGPoint(x: head.x - 4.0, y: head.y - 5.0)
     let shading = Gradient(stops: [
         .init(color: .white.opacity(0.45), location: 0.0),       // Specular highlight
         .init(color: skin.primaryColor, location: 0.35),          // Base diffuse body
         .init(color: skin.primaryColor.opacity(0.85), location: 0.80),
         .init(color: Color.black.opacity(0.35), location: 1.0)    // Ambient occlusion rim
     ])
     context.fill(headPath, with: .radialGradient(shading, center: lightCenter, startRadius: 1, endRadius: headSize))
     ```
   - Add a subtle drop shadow under the head and paws against the desktop background.
   - Alternatively, embed a lightweight SceneKit / RealityKit `SCNView` with a stylized low-poly 3D companion model (e.g., USDZ) anchored to the notch ledge.

### Recommendation 2: Correct Anatomical Anchors & Implement True Pull-Up Exercise
1. **Fix Normal Vector Calculation in `TorsoBones` (`KinematicSkeleton.swift`):**
   - Correct the perpendicular normal vector so that the left shoulder is on screen left and the right shoulder is on screen right:
     ```swift
     // When spineAngle is -.pi / 2 (pointing up), normal should point left (-1, 0)
     private var normalVector: CGPoint {
         CGPoint(x: sin(spineAngle), y: -cos(spineAngle))
     }
     ```
   - This immediately eliminates the arm and leg crossing bug, ensuring the arms and legs reach straight up without forming an "X".
2. **Decouple Head Clamping in `visibleRouteHead` During Pull-Ups:**
   - In `evaluatePullingUp`, when pulling up, the creature's head is supposed to rise **above** the grip ledge.
   - Replace the static clamp with a state-aware check:
     ```swift
     // Allow the head to rise past the ledge during pull-ups
     let chinLift = sin(liftProgress * .pi) * 8.0
     pose.headCenter = CGPoint(x: rootX, y: gripY - 6.0 - chinLift) // Chin clears the notch lip!
     ```
3. **Multi-Rep Pull-Up Cycle:**
   - Implement a recurring sinusoidal cycle in `evaluatePullingUp`:
     $$\text{repPhase} = \sin(\text{behaviorTime} \cdot 4.0)$$
     $$\text{elbowFlare} = \cos(\text{behaviorTime} \cdot 4.0) \cdot 12.0$$
   - The creature pulls up smoothly, pauses at the top (chin over ledge, elbows driving down), lowers down to dead hang, and repeats 2–3 reps before resting.

### Recommendation 3: Articulate Limbs in Idle & Ambient States
1. **Dynamic Paws & Micro-Motions:**
   - In `thinking`: Add subtle chin-scratch micro-motion ($\Delta y = \sin(t \cdot 6.0) \cdot 1.5\text{pt}$).
   - In `musicGroove`: Add rhythmic arm bounce ($\pm 4.0\text{pt}$) synchronized to the music beat.
   - In `dangling`: Implement genuine inverted pendulum motion with a sustained sinusoidal kick ($A = 12.0\text{pt}$) and un-clamped velocity.
2. **Limb Stroke Scaling:**
   - Reduce limb stroke thickness from `5.0pt` to `3.2pt`, or increase bone segment lengths from `8.0pt` to `12.0pt`, allowing the knee and elbow IK flexion angles to be clearly visible to the user.

### Recommendation 4: Fix Settings Lifecycle & Combine Observers
In [`CompanionCoordinator.swift`](file:///Users/dharmitparmar/Doc/Notch/Sources/Modules/Companion/CompanionCoordinator.swift#L41-L85):
- Move `setupObservers()` out of `start()` and call it unconditionally inside `CompanionCoordinator.init()`:
  ```swift
  private init() {
      setupObservers() // Always active, regardless of initial enabled state!
  }
  ```
- In `setupObservers()`, observe `$companionActivityLevel` to dynamically reschedule the next action timer when the user changes pacing in Preferences.
- Either implement macOS Focus API / `NSDistributedNotificationCenter` listeners for `companionSleepDuringDND`, or remove the non-functional toggle from `SettingsView.swift` to prevent user confusion.

---
*Report prepared via static code analysis, mathematical vector tracing, and test artifact verification.*
