// Audio2Text-iOS shared source

#if os(macOS)
import AppKit
#endif
import SwiftUI

// All application control geometry and visual styles live here. Panels choose
// semantic variants and sizes; they do not define their own control chrome.
enum AppControlMetrics {
    #if os(macOS)
    static let height: CGFloat = 30
    static let compactHeight: CGFloat = 24
    #else
    static let height: CGFloat = 44
    static let compactHeight: CGFloat = 36
    #endif
    static let iconWidth: CGFloat = 40
    static let minimumHitTarget: CGFloat = {
        #if os(macOS)
        0
        #else
        44
        #endif
    }()
    static let cornerRadius: CGFloat = 8
    static let horizontalPadding: CGFloat = 12
    static let compactPadding: CGFloat = 6
    static let iconFontSize: CGFloat = 16
    static let compactIconFontSize: CGFloat = 12
    static let fieldPadding: CGFloat = 8
    static let controlSpacing: CGFloat = 8
    static let toolbarHeight: CGFloat = 42
    static let episodeRowHeight: CGFloat = 54
    static let selectionTargetHeight: CGFloat = 44
    static let progressIndicatorSize: CGFloat = 14
    static let progressBarHeight: CGFloat = 4

    enum Sidebar {
        static let sectionSpacing: CGFloat = 10
        static let rowSpacing: CGFloat = 2
        static let sourceRowHeight: CGFloat = AppControlMetrics.height
        static let itemRowHeight: CGFloat = 28
        static let sourceIconSize: CGFloat = 19
        static let sourceIconFrame: CGFloat = 22
        static let rowCornerRadius: CGFloat = AppControlMetrics.cornerRadius
        static let rowHorizontalPadding: CGFloat = 8
        static let titleFontSize: CGFloat = 14
        static let countFontSize: CGFloat = 12
        static let headerFontSize: CGFloat = 12
    }
}

enum AppControlSize: Equatable {
    case regular
    case compact

    var height: CGFloat {
        self == .regular ? AppControlMetrics.height : AppControlMetrics.compactHeight
    }

    var iconWidth: CGFloat {
        self == .regular ? AppControlMetrics.iconWidth : AppControlMetrics.compactHeight
    }

    var padding: CGFloat {
        self == .regular ? AppControlMetrics.horizontalPadding : AppControlMetrics.compactPadding
    }

    var font: Font {
        self == .regular ? .callout.weight(.semibold) : .caption.weight(.medium)
    }

    var iconFont: Font {
        .system(
            size: self == .regular ? AppControlMetrics.iconFontSize : AppControlMetrics.compactIconFontSize,
            weight: .medium
        )
    }
}

enum AppControlVariant: Equatable {
    case normal
    case prominent
    case destructive
    case subtle
}

private struct AppControlSizeKey: EnvironmentKey {
    static let defaultValue = AppControlSize.regular
}

extension EnvironmentValues {
    var appControlSize: AppControlSize {
        get { self[AppControlSizeKey.self] }
        set { self[AppControlSizeKey.self] = newValue }
    }
}

struct AppButtonStyle: ButtonStyle {
    var variant: AppControlVariant = .normal
    var size: AppControlSize? = nil
    var iconOnly = false
    var foregroundColor: Color? = nil
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        AppControlLabel(
            label: configuration.label,
            variant: configuration.role == .destructive ? .destructive : variant,
            size: size,
            iconOnly: iconOnly,
            foregroundColor: foregroundColor,
            tint: tint,
            isPressed: configuration.isPressed
        )
    }
}

// Row buttons retain their content's layout while sharing the same interaction
// policy. Their selected backgrounds are supplied by the shared row surface.
struct AppRowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.8 : 1)
    }
}

struct AppControlLabel<Label: View>: View {
    let label: Label
    var variant: AppControlVariant = .normal
    var size: AppControlSize? = nil
    var iconOnly = false
    var foregroundColor: Color? = nil
    var tint: Color = .accentColor
    var isPressed = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appControlSize) private var inheritedSize
    @State private var isHovered = false

    private var resolvedSize: AppControlSize { size ?? inheritedSize }

    var body: some View {
        label
            .font(iconOnly ? resolvedSize.iconFont : resolvedSize.font)
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, iconOnly ? 0 : resolvedSize.padding)
            .frame(width: iconOnly ? resolvedSize.iconWidth : nil, height: resolvedSize.height)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius)
                    .strokeBorder(borderStyle, lineWidth: isHovered && isEnabled ? 1 : 0)
            }
            .frame(minWidth: iconOnly ? AppControlMetrics.minimumHitTarget : 0, minHeight: AppControlMetrics.minimumHitTarget)
            .contentShape(RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .onHover { isHovered = $0 }
    }

    private var foregroundStyle: Color {
        guard isEnabled else { return .secondary.opacity(0.48) }
        if let foregroundColor { return foregroundColor }
        switch variant {
        case .normal, .subtle: return isHovered ? .primary : .secondary
        case .destructive: return .red
        case .prominent: return .white
        }
    }

    private var backgroundStyle: Color {
        guard isEnabled else { return .secondary.opacity(variant == .subtle ? 0 : 0.06) }
        switch variant {
        case .normal, .subtle:
            if isPressed { return .accentColor.opacity(0.22) }
            return isHovered ? .accentColor.opacity(0.16) : .secondary.opacity(variant == .subtle ? 0 : 0.10)
        case .destructive:
            if isPressed { return .red.opacity(0.20) }
            return isHovered ? .red.opacity(0.14) : .secondary.opacity(0.10)
        case .prominent:
            return tint.opacity(isPressed ? 0.72 : isHovered ? 0.88 : 0.82)
        }
    }

    private var borderStyle: Color {
        switch variant {
        case .normal, .subtle: return .accentColor.opacity(0.36)
        case .destructive: return .red.opacity(0.32)
        case .prominent: return .clear
        }
    }
}

struct AppMenu<Label: View, Content: View>: View {
    var size: AppControlSize? = nil
    var iconOnly = false
    var variant: AppControlVariant = .normal
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label
    @Environment(\.appControlSize) private var inheritedSize

    var body: some View {
        // macOS renders Menu labels natively and drops their SwiftUI backgrounds.
        // Apply the common chrome around the menu instead of inside its label.
        AppControlLabel(
            label: nativeMenu
                .fixedSize(horizontal: true, vertical: false)
                .frame(
                    width: iconOnly ? max((size ?? inheritedSize).iconWidth, AppControlMetrics.minimumHitTarget) : nil,
                    height: max((size ?? inheritedSize).height, AppControlMetrics.minimumHitTarget)
                ),
            variant: variant,
            size: size,
            iconOnly: iconOnly
        )
    }

    @ViewBuilder
    private var nativeMenu: some View {
        #if os(macOS)
        Menu(content: content, label: label)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        #else
        Menu(content: content, label: label)
            .buttonStyle(.plain)
        #endif
    }
}

struct AppIconButton: View {
    let systemName: String
    let label: String
    var role: ButtonRole? = nil
    var isDisabled = false
    var foregroundColor: Color? = nil
    var size: AppControlSize? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) { Image(systemName: systemName) }
            .buttonStyle(AppButtonStyle(variant: .subtle, size: size, iconOnly: true, foregroundColor: foregroundColor))
            .disabled(isDisabled)
            .accessibilityLabel(label)
            .help(label)
    }
}

struct AppLabeledIconButton: View {
    let title: String
    let systemName: String
    var role: ButtonRole? = nil
    var isDisabled = false
    let action: () -> Void

    @Environment(\.appControlSize) private var size

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemName).font(size.iconFont)
                Text(title).font(.caption2.weight(.medium)).lineLimit(1)
            }
        }
        .buttonStyle(AppButtonStyle(variant: .subtle, iconOnly: true))
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

struct AppSelectionButton: View {
    let isSelected: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(AppControlSize.regular.iconFont)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: max(AppControlMetrics.compactHeight, AppControlMetrics.minimumHitTarget), height: AppControlMetrics.selectionTargetHeight)
        }
        .buttonStyle(AppRowButtonStyle())
        .accessibilityLabel(label)
    }
}

struct AppMenuLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    var inline = false
    @Environment(\.appControlSize) private var size

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, inline ? 0 : AppControlMetrics.fieldPadding)
            .frame(minHeight: size.height)
            .background(inline ? Color.clear : AppControlColors.fieldBackground, in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius)
                    .strokeBorder(Color.secondary.opacity(inline ? 0 : 0.22), lineWidth: 1)
            }
    }

}

private enum AppControlColors {
    static var fieldBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}

struct AppToggleStyle: ToggleStyle {
    @Environment(\.appControlSize) private var size

    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            #if os(macOS)
            .toggleStyle(.checkbox)
            #else
            .toggleStyle(.switch)
            #endif
            .frame(minHeight: size.height)
    }
}

struct AppPicker<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content
    @Environment(\.appControlSize) private var size

    init(_ title: String, selection: Binding<Selection>, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        _selection = selection
        self.content = content
    }

    var body: some View {
        Picker(title, selection: $selection, content: content)
            .frame(minHeight: size.height)
    }
}

struct AppTextEditor: View {
    enum Mode {
        case prose
        case code
        case log

        var font: Font {
            switch self {
            case .prose: return .body
            case .code: return .system(.body, design: .monospaced)
            case .log: return .system(.caption, design: .monospaced)
            }
        }
    }

    @Binding var text: String
    var mode: Mode = .prose

    var body: some View {
        TextEditor(text: $text)
            .font(mode.font)
            .scrollContentBackground(.hidden)
            .padding(AppControlMetrics.fieldPadding)
            .background(AppControlColors.fieldBackground, in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius)
                    .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
            }
    }
}

struct AppProgressSpinner: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .frame(width: AppControlMetrics.progressIndicatorSize, height: AppControlMetrics.progressIndicatorSize)
    }
}

struct AppProgressBar: View {
    let value: Double
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.16))
                Capsule().fill(tint)
                    .frame(width: max(0, geometry.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: AppControlMetrics.progressBarHeight)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(min(1, max(0, value)) * 100)) percent")
    }
}

struct AppLink: View {
    let title: String
    let destination: URL

    init(_ title: String, destination: URL) {
        self.title = title
        self.destination = destination
    }

    var body: some View {
        Link(title, destination: destination)
            .buttonStyle(AppButtonStyle())
    }
}

private struct AppRowSurface: ViewModifier {
    var isSelected: Bool
    var isEmphasized: Bool
    var isCard: Bool
    var background: Color?

    func body(content: Content) -> some View {
        content
            .background(
                isSelected ? Color.accentColor.opacity(isEmphasized ? 1 : 0.14) : background ?? Color.secondary.opacity(isCard ? 0.06 : 0),
                in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius)
                    .strokeBorder(Color.accentColor.opacity(isSelected ? 0.36 : 0), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
    }
}

struct AppControlBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        AppControlFlow(spacing: AppControlMetrics.controlSpacing) { content() }
            .padding(.horizontal, AppControlMetrics.horizontalPadding)
            .padding(.vertical, AppControlMetrics.controlSpacing)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius))
    }
}

struct AppControlFlow: Layout {
    var spacing: CGFloat = AppControlMetrics.controlSpacing

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + layout.origins[index].x, y: bounds.minY + layout.origins[index].y),
                anchor: .topLeading,
                proposal: ProposedViewSize(layout.sizes[index])
            )
        }
    }

    private func arrangement(width: CGFloat?, subviews: Subviews) -> (size: CGSize, origins: [CGPoint], sizes: [CGSize]) {
        let limit = width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0
        var rowStart = 0

        func alignRow(through end: Int) {
            for index in rowStart..<end {
                origins[index].y += (rowHeight - sizes[index].height) / 2
            }
        }

        for (index, size) in sizes.enumerated() {
            if x > 0 && x + size.width > limit {
                alignRow(through: index)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
                rowStart = index
            }
            origins.append(CGPoint(x: x, y: y))
            contentWidth = max(contentWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        alignRow(through: sizes.count)
        return (CGSize(width: max(width ?? contentWidth, contentWidth), height: y + rowHeight), origins, sizes)
    }
}

private struct AppControlTheme: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(AppButtonStyle())
            .textFieldStyle(AppTextFieldStyle())
            .toggleStyle(AppToggleStyle())
            .pickerStyle(.menu)
            .controlSize(.regular)
    }
}

extension View {
    func appControlTheme() -> some View { modifier(AppControlTheme()) }

    func appControlSize(_ size: AppControlSize) -> some View { environment(\.appControlSize, size) }

    func appRowSurface(isSelected: Bool = false, isEmphasized: Bool = false, isCard: Bool = false, background: Color? = nil) -> some View {
        modifier(AppRowSurface(isSelected: isSelected, isEmphasized: isEmphasized, isCard: isCard, background: background))
    }

    func appLibraryRowSurface(isActive: Bool, isSelected: Bool) -> some View {
        appRowSurface(background: Color.accentColor.opacity(isSelected ? 0.28 : isActive ? 0.20 : 0))
    }

    func appSegmentedControl() -> some View { pickerStyle(.segmented) }

    // Segmented controls placed beside buttons and menus adopt the same
    // control height so the whole row shares one baseline and height.
    func appSegmentedControl(size: AppControlSize) -> some View {
        pickerStyle(.segmented)
            #if os(macOS)
            .controlSize(size == .regular ? .large : .small)
            #endif
            .frame(minHeight: size.height)
    }

}

#if os(macOS)
@MainActor
enum AppNativeControls {
    static func configureToolbarButton(_ button: NSButton) {
        button.bezelStyle = .texturedRounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: AppControlMetrics.iconFontSize, weight: .medium)
        button.setFrameSize(NSSize(width: AppControlMetrics.iconWidth, height: AppControlMetrics.height))
    }
}
#endif

private struct AppFastTooltipModifier: ViewModifier {
    let text: String

    @State private var isHovered = false
    @State private var isPresented = false
    @State private var presentationTask: Task<Void, Never>?

    private let delayNanoseconds: UInt64 = 180_000_000

    func body(content: Content) -> some View {
        content
            .onHover(perform: updateHoverState)
            .overlay(alignment: .bottom) {
                if isPresented {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Color.black.opacity(0.86),
                            in: RoundedRectangle(cornerRadius: AppControlMetrics.cornerRadius, style: .continuous)
                        )
                        .offset(y: 34)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .allowsHitTesting(false)
                }
            }
            .zIndex(isPresented ? 1 : 0)
            .animation(.easeOut(duration: 0.10), value: isPresented)
    }

    private func updateHoverState(_ hovered: Bool) {
        isHovered = hovered
        presentationTask?.cancel()

        if hovered {
            presentationTask = Task {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if isHovered {
                        isPresented = true
                    }
                }
            }
        } else {
            isPresented = false
            presentationTask = nil
        }
    }
}

extension View {
    func appFastTooltip(_ text: String) -> some View {
        modifier(AppFastTooltipModifier(text: text))
    }
}


#if os(macOS)
struct EditableComboBox: NSViewRepresentable {
    @Binding var text: String
    let options: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.controlSize = .regular
        comboBox.font = .systemFont(ofSize: NSFont.systemFontSize)
        comboBox.usesDataSource = false
        comboBox.isEditable = true
        comboBox.completes = false
        comboBox.delegate = context.coordinator
        comboBox.target = context.coordinator
        comboBox.action = #selector(Coordinator.comboBoxAction(_:))
        comboBox.addItems(withObjectValues: options)
        comboBox.stringValue = text
        return comboBox
    }

    func updateNSView(_ nsView: NSComboBox, context _: Context) {
        let currentItems = nsView.objectValues.compactMap { $0 as? String }
        if currentItems != options {
            nsView.removeAllItems()
            nsView.addItems(withObjectValues: options)
        }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSComboBoxDelegate, NSControlTextEditingDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func comboBoxAction(_ sender: NSComboBox) {
            commit(sender, preferSelection: true)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commit(comboBox, preferSelection: false)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commit(comboBox, preferSelection: false)
        }

        func comboBoxSelectionIsChanging(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commit(comboBox, preferSelection: true)
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commit(comboBox, preferSelection: true)
        }

        func comboBoxWillDismiss(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commit(comboBox, preferSelection: true)
        }

        private func commit(_ comboBox: NSComboBox, preferSelection: Bool) {
            if preferSelection, let selectedText = Self.selectedText(from: comboBox) {
                text = selectedText
                return
            }
            text = comboBox.stringValue
        }

        static func selectedText(from comboBox: NSComboBox) -> String? {
            guard let selected = comboBox.objectValueOfSelectedItem as? String else {
                return nil
            }
            let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : selected
        }
    }
}

#endif

#if os(iOS)
extension Color {
    static var mobileShellBackground: Color {
        Color(.systemGroupedBackground)
    }

    static var mobilePanelBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }

    static var mobileContentBackground: Color {
        Color(.systemGroupedBackground)
    }

    static var mobileReaderBackground: Color {
        Color(.systemBackground)
    }

    static var mobileSearchBackground: Color {
        Color(.tertiarySystemGroupedBackground)
    }

    static var mobileDivider: Color {
        Color(.separator)
    }
}
#endif
