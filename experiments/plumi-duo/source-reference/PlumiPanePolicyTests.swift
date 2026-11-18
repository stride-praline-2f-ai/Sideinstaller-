import Foundation

let policy = PlumiPanePolicy()

func check(_ windowWidth: Double, expectedTwoColumns: Bool) {
    // In the reference SwiftUI component, 16pt margins apply on each side.
    let available = windowWidth - 32
    switch policy.mode(availableWidth: available) {
    case .stacked:
        precondition(!expectedTwoColumns, "Unexpected stacked mode at \(windowWidth)")
    case .twoColumn(let main, let side):
        precondition(expectedTwoColumns, "Unexpected two columns at \(windowWidth)")
        precondition(main >= 480)
        precondition(side >= 376)
        precondition(abs(main + side + 16 + 32 - windowWidth) < 0.001)
        if windowWidth == 951 {
            precondition(main == 527 && side == 376,
                         "Duo target must preserve 376pt sidebar within 951pt")
        }
    }
}
check(0, expectedTwoColumns: false)
check(393, expectedTwoColumns: false)
check(469, expectedTwoColumns: false)
check(679, expectedTwoColumns: false)
check(744, expectedTwoColumns: false) // iPad mini portrait
check(903, expectedTwoColumns: false)
check(904, expectedTwoColumns: true) // exact minimum for split
check(951, expectedTwoColumns: true) // measured Duo inner landscape
check(1024, expectedTwoColumns: true)
check(1133, expectedTwoColumns: true) // iPad mini landscape reference
check(.nan, expectedTwoColumns: false)
check(.infinity, expectedTwoColumns: false)
print("All 12 Duo/iPad mini geometry tests passed.")
