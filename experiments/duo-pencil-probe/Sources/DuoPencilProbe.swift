import SwiftUI
import UIKit

// Read-only diagnostic: does not pair devices, access Bluetooth, modify
// MobileGestalt, query kernel drivers, or inject touches into other apps.
struct PencilReading {
    let kind: String
    let force: CGFloat
    let maximumForce: CGFloat
    let altitudeRadians: CGFloat
    let location: CGPoint
    let count: Int
    let pencilCount: Int
    let fingerCount: Int
}

final class PencilCanvas: UIView {
    var onReading: ((PencilReading) -> Void)?
    private let pencilPath = UIBezierPath()
    private let fingerPath = UIBezierPath()
    private var lastTouchType = UITouch.TouchType.direct
    private var count = 0
    private var pencilCount = 0
    private var fingerCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = .secondarySystemBackground
        isMultipleTouchEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }

    override func draw(_ rect: CGRect) {
        UIColor.systemBlue.setStroke()
        pencilPath.lineWidth = 2.5
        pencilPath.stroke()
        UIColor.systemGray.setStroke()
        fingerPath.lineWidth = 2.5
        fingerPath.stroke()
    }

    private func report(_ touch: UITouch, began: Bool) {
        let point = touch.location(in: self)
        lastTouchType = touch.type
        let path = touch.type == .pencil ? pencilPath : fingerPath
        if began { path.move(to: point) }
        else { path.addLine(to: point) }
        count += 1
        if touch.type == .pencil { pencilCount += 1 }
        else { fingerCount += 1 }
        setNeedsDisplay()

        let kind: String
        switch touch.type {
        case .pencil: kind = "Pencil event detected"
        case .direct: kind = "Finger-like touch (not Pencil)"
        case .indirect: kind = "Indirect touch"
        @unknown default: kind = "Unknown touch type"
        }

        onReading?(PencilReading(kind: kind,
                                 force: touch.force,
                                 maximumForce: touch.maximumPossibleForce,
                                 altitudeRadians: touch.altitudeAngle,
                                 location: point,
                                 count: count,
                                 pencilCount: pencilCount,
                                 fingerCount: fingerCount))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        report(touch, began: true)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        report(touch, began: false)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        report(touch, began: false)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        report(touch, began: false)
    }
}

struct PencilCanvasRepresentable: UIViewRepresentable {
    @Binding var latest: PencilReading?
    func makeUIView(context: Context) -> PencilCanvas {
        let canvas = PencilCanvas()
        canvas.onReading = { sample in latest = sample }
        return canvas
    }
    func updateUIView(_ uiView: PencilCanvas, context: Context) {
        uiView.onReading = { sample in latest = sample }
    }
}

struct PencilProbeView: View {
    @State private var latest: PencilReading?
    private var value: String {
        guard let r = latest else { return "Nothing detected yet. Draw below." }
        return r.kind + "\n" +
            "Samples: \(r.count)  Pencil: \(r.pencilCount)  Other: \(r.fingerCount)\n" +
            String(format: "Force %.2f / %.2f; altitude %.1f°\nPosition %.0f, %.0f",
                   Double(r.force), Double(r.maximumForce),
                   Double(r.altitudeRadians * 180 / .pi),
                   Double(r.location.x), Double(r.location.y))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duo Pencil Compatibility Probe")
                .font(.headline)
            Text("Read-only touch input test. No system changes or Bluetooth pairing.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            PencilCanvasRepresentable(latest: $latest)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary))
            Text("Test with a finger, then a USB-C Pencil as a working baseline, then Pencil Pro. Blue lines are Pencil touches; grey lines are non-Pencil touches. No lines from Pro means iOS did not deliver input to this app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

@main struct DuoPencilProbeApp: App {
    var body: some Scene {
        WindowGroup { PencilProbeView() }
    }
}
