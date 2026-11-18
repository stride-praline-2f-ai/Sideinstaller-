import Foundation

/// Width-driven dashboard layout for the iPhone Duo and iPad mini.
/// Reference implementation only; requires integration with Plumi's SwiftUI source.
public enum PlumiPaneMode: Equatable {
    case stacked
    case twoColumn(mainWidth: Double, sidebarWidth: Double)
}

public struct PlumiPanePolicy {
    public var minimumMainWidth: Double = 460
    public var minimumSidebarWidth: Double = 300
    public var maximumSidebarWidth: Double = 350
    public var sidebarFraction: Double = 0.33
    public var spacing: Double = 20
    public init() {}
    public func mode(availableWidth width: Double) -> PlumiPaneMode {
        guard width.isFinite, width > 0 else { return .stacked }
        guard width >= minimumMainWidth + minimumSidebarWidth + spacing
              else { return .stacked }
        let side = min(maximumSidebarWidth, max(minimumSidebarWidth, width * sidebarFraction))
        let main = width - side - spacing
        return main >= minimumMainWidth
            ? .twoColumn(mainWidth: main, sidebarWidth: side) : .stacked
    }
}
