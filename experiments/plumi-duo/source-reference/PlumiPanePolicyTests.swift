import Foundation

let policy = PlumiPanePolicy()
func check(_ width: Double, _ two: Bool) {
    switch policy.mode(availableWidth: width) {
    case .stacked: precondition(!two, "Unexpected stacked mode at \(width)")
    case .twoColumn(let main, let side):
        precondition(two, "Unexpected two columns at \(width)")
        precondition(main >= 460 && side >= 300 && main + side + 20 <= width + 0.01)
    }
}
check(0, false)
check(469, false)
check(679, false)
check(727, false)
check(779, false)
check(780, true)
check(834, true)
check(1024, true)
check(.nan, false)
check(.infinity, false)
print("All 10 width policy tests passed.")
