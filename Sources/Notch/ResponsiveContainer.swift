import SwiftUI

// MARK: - Environment Keys for Responsive Notch Island Sizing

private struct NotchCompactKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct NotchTightKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct NotchContentHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 330.0
}

public extension EnvironmentValues {
    /// True when available content height is less than 240 pt.
    var notchCompact: Bool {
        get { self[NotchCompactKey.self] }
        set { self[NotchCompactKey.self] = newValue }
    }
    
    /// True when available content height is less than 170 pt (tight minimum).
    var notchTight: Bool {
        get { self[NotchTightKey.self] }
        set { self[NotchTightKey.self] = newValue }
    }
    
    /// The exact available height allocated for content inside the expanded notch.
    var notchContentHeight: CGFloat {
        get { self[NotchContentHeightKey.self] }
        set { self[NotchContentHeightKey.self] = newValue }
    }
}

// MARK: - Responsive Tab Content Container

/// Single shared responsive wrapper providing real GeometryReader height,
/// environment values (`notchCompact`, `notchTight`, `notchContentHeight`),
/// and non-clipping vertical scroll fallback when content exceeds available height.
public struct ResponsiveTabContent<Content: View>: View {
    private let enablesVerticalScrollFallback: Bool
    @ViewBuilder private let content: (CGFloat) -> Content
    
    public init(
        enablesVerticalScrollFallback: Bool = true,
        @ViewBuilder content: @escaping (CGFloat) -> Content
    ) {
        self.enablesVerticalScrollFallback = enablesVerticalScrollFallback
        self.content = content
    }
    
    public var body: some View {
        GeometryReader { geo in
            let availableH = geo.size.height
            let isCompact = availableH < 240.0
            let isTight = availableH < 170.0
            
            Group {
                if enablesVerticalScrollFallback {
                    ViewThatFits(in: .vertical) {
                        content(availableH)
                            .frame(maxWidth: .infinity, alignment: .top)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            content(availableH)
                                .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }
                } else {
                    content(availableH)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .environment(\.notchCompact, isCompact)
            .environment(\.notchTight, isTight)
            .environment(\.notchContentHeight, availableH)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
