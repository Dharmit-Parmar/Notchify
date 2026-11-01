import AppKit
import SwiftUI

@main
@MainActor
struct CompanionFrameStripGenerator {
    static func main() throws {
        let engine = KinematicEngine.shared
        let coordinator = CompanionCoordinator.shared
        let store = SettingsStore.shared
        let dt = 1.0 / 60.0
        store.companionDebugSkeleton = true
        store.companionSkin = .mochi

        let output = URL(fileURLWithPath: "artifacts/companion-frame-strips", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        func image() -> CGImage {
            let renderer = ImageRenderer(content: CreatureRigView().frame(width: engine.screenWidth, height: 160))
            renderer.scale = 2
            renderer.isOpaque = false
            guard let image = renderer.cgImage else { fatalError("SwiftUI failed to render the production companion view") }
            return image
        }

        func strip(_ name: String, frames: [CGImage], centers: [CGFloat]) throws {
            let cropWidth = 112
            let cropHeight = 140
            let scale = max(1, CGFloat(image().width) / engine.screenWidth)
            let frameWidth = Int(CGFloat(cropWidth) * scale)
            let frameHeight = Int(CGFloat(cropHeight) * scale)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(data: nil, width: frameWidth * frames.count, height: frameHeight,
                                          bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                fatalError("Could not allocate frame strip")
            }
            context.setFillColor(NSColor(white: 0.22, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: frameWidth * frames.count, height: frameHeight))

            for (index, frame) in frames.enumerated() {
                let sourceScale = CGFloat(frame.width) / engine.screenWidth
                let left = max(0, min(engine.screenWidth - CGFloat(cropWidth), centers[index] - CGFloat(cropWidth) / 2))
                let crop = CGRect(x: left * sourceScale, y: 0, width: CGFloat(cropWidth) * sourceScale,
                                  height: CGFloat(cropHeight) * sourceScale)
                guard let cropped = frame.cropping(to: crop) else { fatalError("Could not crop rendered frame") }
                let destination = CGRect(x: index * frameWidth, y: 0, width: frameWidth, height: frameHeight)
                context.draw(cropped, in: destination)

                // The physical camera housing sits in front of the overlay.
                let notchLeft = max(engine.notchLeft, left)
                let notchRight = min(engine.notchRight, left + CGFloat(cropWidth))
                if notchLeft < notchRight {
                    context.setFillColor(NSColor.black.cgColor)
                    context.fill(CGRect(x: CGFloat(index * frameWidth) + (notchLeft - left) * scale,
                                        y: CGFloat(frameHeight) - engine.notchHeight * scale,
                                        width: (notchRight - notchLeft) * scale, height: engine.notchHeight * scale))
                }
            }

            guard let result = context.makeImage(),
                  let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:]) else {
                fatalError("Could not encode frame strip")
            }
            try data.write(to: output.appendingPathComponent("\(name).png"))
        }

        func capture(_ name: String, frames count: Int, update: () -> Void) throws {
            var images: [CGImage] = []
            var centers: [CGFloat] = []
            for _ in 0..<count {
                update()
                images.append(image())
                centers.append(engine.currentPose.root.x)
            }
            try strip(name, frames: images, centers: centers)
        }

        coordinator.state = .walking
        engine.setBehavior(.walking)
        try capture("walk", frames: 16) { for _ in 0..<3 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }

        engine.setBehavior(.walking, startingFromRight: true)
        try capture("walk-right", frames: 16) { for _ in 0..<3 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }

        coordinator.state = .crawling
        engine.setBehavior(.crawling)
        try capture("crawl", frames: 16) { for _ in 0..<3 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }

        coordinator.state = .dangling
        engine.setBehavior(.dangling)
        try capture("hang", frames: 16) { for _ in 0..<6 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }

        coordinator.state = .pullingUp
        engine.setBehavior(.pullingUp)
        try capture("pull-up", frames: 16) { for _ in 0..<9 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }

        coordinator.state = .walking
        engine.setBehavior(.walking)
        while engine.routeStage != .monkeyBarTraversal { engine.update(deltaTime: dt, cursorScreenPos: .zero) }
        try capture("monkey-bar", frames: 16) { for _ in 0..<3 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }

        engine.setBehavior(.walking)
        while engine.routeStage != .climbOntoRightLedge { engine.update(deltaTime: dt, cursorScreenPos: .zero) }
        try capture("climb-over", frames: 16) { for _ in 0..<6 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }

        coordinator.state = .peekingLeft
        engine.setBehavior(.peekingLeft)
        try capture("peek-left", frames: 20) { for _ in 0..<20 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }

        store.companionDebugSkeleton = false
        coordinator.state = .walking
        engine.setBehavior(.walking, startingFromRight: true)
        try capture("walk-right-clean", frames: 16) { for _ in 0..<3 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }
        coordinator.state = .dangling
        engine.setBehavior(.dangling)
        try capture("hang-clean", frames: 16) { for _ in 0..<6 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }
        coordinator.state = .peekingLeft
        engine.setBehavior(.peekingLeft)
        try capture("peek-left-clean", frames: 20) { for _ in 0..<20 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }
        coordinator.state = .sleeping
        engine.setBehavior(.sleeping)
        try capture("sleep-clean", frames: 16) { for _ in 0..<6 { engine.update(deltaTime: dt, cursorScreenPos: .zero) } }
        print("Wrote eight debug strips and four clean strips with the production SwiftUI Canvas renderer to \(output.path)")
    }
}
