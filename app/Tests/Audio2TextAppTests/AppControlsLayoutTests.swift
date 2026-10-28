@testable import Audio2TextApp
import AppKit
import SwiftUI
import XCTest

final class AppControlsLayoutTests: XCTestCase {
    @MainActor
    func testRegularControlsHaveMatchingHeights() throws {
        let frames = try measureControls(size: .regular, width: 760)
        let heights = frames.values.map(\.height)
        XCTAssertEqual(frames.count, 5)
        let first = try XCTUnwrap(heights.first)
        XCTAssertGreaterThanOrEqual(first, 24)
        for height in heights { XCTAssertEqual(height, first, accuracy: 0.5) }
    }

    @MainActor
    func testCompactSizeAppliesToEveryControl() throws {
        let regular = try measureControls(size: .regular, width: 760)
        let compact = try measureControls(size: .compact, width: 760)
        XCTAssertEqual(regular.count, compact.count)
        for (name, frame) in regular {
            let compactFrame = try XCTUnwrap(compact[name])
            XCTAssertLessThan(compactFrame.height, frame.height)
            XCTAssertEqual(compactFrame.height, compact["button"]?.height ?? 0, accuracy: 0.5)
        }
    }

    @MainActor
    func testControlBarWrapsWithoutClippingOrOverlapping() throws {
        for width in [CGFloat(250), 450] {
            let frames = try measureControls(size: .regular, width: width)
            XCTAssertGreaterThan(Set(frames.values.map(\.minY)).count, 1)
            for frame in frames.values {
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertLessThanOrEqual(frame.maxX, width)
            }
            for (firstName, firstFrame) in frames {
                for (secondName, secondFrame) in frames where firstName != secondName {
                    XCTAssertFalse(firstFrame.intersects(secondFrame), "\(firstName) overlaps \(secondName)")
                }
            }
        }
    }

    @MainActor
    private func measureControls(size: AppControlSize, width: CGFloat) throws -> [String: CGRect] {
        let measurements = ControlMeasurements()
        let controls = AppControlBar {
            Button("Process 1") {}.controlFrame("button")
            AppMenu {
                Button("All time") {}
            } label: {
                AppMenuLabel(title: "All time", systemImage: "calendar")
            }
            .controlFrame("menu")
            TextField("URL", text: .constant(""))
                .frame(width: 140)
                .controlFrame("field")
            AppPicker("", selection: .constant(0)) {
                Text("First").tag(0)
                Text("Second").tag(1)
            }
            .frame(width: 100)
            .controlFrame("picker")
            Toggle("Unprocessed", isOn: .constant(false)).controlFrame("toggle")
        }
        .appControlTheme()
        .appControlSize(size)
        .coordinateSpace(name: "controls")
        .onPreferenceChange(ControlFramesKey.self) { measurements.frames = $0 }
        let host = NSHostingView(rootView: controls)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 220),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentView = host
        window.setContentSize(NSSize(width: width, height: 220))
        defer { window.contentView = nil }
        for _ in 0..<15 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return measurements.frames
    }
}

@MainActor
private final class ControlMeasurements {
    var frames: [String: CGRect] = [:]
}

private struct ControlFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private extension View {
    func controlFrame(_ name: String) -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(
                key: ControlFramesKey.self,
                value: [name: geometry.frame(in: .named("controls"))]
            )
        })
    }
}
