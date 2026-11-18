import SwiftUI

/// SOURCE-LEVEL reference. Replace only Plumi's Chemistry dashboard pane
/// composition. Never override the entire UIWindowScene's size classes.
public struct PlumiAdaptiveColumns<MainContent: View, SidebarContent: View>: View {
    private let main: MainContent
    private let sidebar: SidebarContent
    private let policy = PlumiPanePolicy()
    private let outerPadding: Double = 16

    public init(@ViewBuilder main: () -> MainContent,
                @ViewBuilder sidebar: () -> SidebarContent) {
        self.main = main()
        self.sidebar = sidebar()
    }

    public var body: some View {
        GeometryReader { proxy in
            let available = max(0, Double(proxy.size.width) - outerPadding * 2)
            let mode = policy.mode(availableWidth: available)
            ScrollView(.vertical) {
                switch mode {
                case .stacked:
                    VStack(alignment: .leading, spacing: CGFloat(policy.spacing)) {
                        main.frame(maxWidth: .infinity, alignment: .leading)
                        sidebar.frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .twoColumn(let mainWidth, let sidebarWidth):
                    HStack(alignment: .top, spacing: CGFloat(policy.spacing)) {
                        main.frame(width: CGFloat(mainWidth), alignment: .topLeading)
                        sidebar.frame(width: CGFloat(sidebarWidth), alignment: .topLeading)
                    }
                }
            }
            .safeAreaPadding(.horizontal, CGFloat(outerPadding))
        }
    }
}
