import Foundation

/// Source-level iPad mini-style responsive layout for iPhone Duo.
/// This policy does NOT replace compiled SwiftUI views inside the Plumi IPA.
public enum PlumiPaneMode: Equatable {
    case stacked
    case twoColumn(mainWidth: Double, sidebarWidth: Double)
}

public struct PlumiPanePolicy {
    /// Original Plumi's right-hand Chemistry content measured 376 points wide,
    /// while its current Duo sidebar viewport is only 304.3 points wide.
    public var minimumMainWidth: Double = 480
    public var sidebarContentWidth: Double = 376
    public var spacing: Double = 16

    public init() {}

    /// Pass width AFTER subtracting the actual horizontal safe-area and margins.
    public func mode(availableWidth width: Double) -> PlumiPaneMode {
        guard width.isFinite, width > 0 else { return .stacked }
        let required = minimumMainWidth + sidebarContentWidth + spacing
        guard width >= required else { return .stacked }
        return .twoColumn(
            mainWidth: width - sidebarContentWidth - spacing,
            sidebarWidth: sidebarContentWidth
        )
    }
}
