//
//  MacCompat.swift
//  Stamped! A City Passport
//
//  Lets the shared iPhone/iPad code compile as a native Mac app.
//  Each shim below has the same name as the iOS API it stands in for, so the
//  iOS code paths stay exactly as they were. On the Mac they either map to
//  the AppKit equivalent (UIColor → NSColor, UIImage → NSImage) or do nothing
//  (title display mode, keyboard type, full-screen covers become sheets).
//

import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Colors

typealias UIColor = NSColor

extension NSColor {
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemBackground: NSColor { .controlBackgroundColor }
    static var tertiarySystemBackground: NSColor { .underPageBackgroundColor }
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }
    static var tertiarySystemGroupedBackground: NSColor { .underPageBackgroundColor }
    static var tertiarySystemFill: NSColor { .quaternaryLabelColor }
    static var tertiaryLabel: NSColor { .tertiaryLabelColor }
    static var systemGray2: NSColor { .systemGray.withAlphaComponent(0.8) }
    static var systemGray3: NSColor { .systemGray.withAlphaComponent(0.6) }
    static var systemGray4: NSColor { .systemGray.withAlphaComponent(0.4) }
    static var systemGray5: NSColor { .systemGray.withAlphaComponent(0.25) }
    static var systemGray6: NSColor { .systemGray.withAlphaComponent(0.12) }
}

// MARK: - Images

typealias UIImage = NSImage

extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}

extension Image {
    init(uiImage: NSImage) { self.init(nsImage: uiImage) }
}

extension ImageRenderer {
    @MainActor var uiImage: NSImage? { nsImage }
}

// MARK: - Representables

// Lets the existing UIKit wrappers (Look Around, Apple's place card, the 3D
// model view) build on the Mac, where MapKit and SceneKit hand back AppKit views.
protocol UIViewControllerRepresentable: NSViewControllerRepresentable
where NSViewControllerType == UIViewControllerType {
    associatedtype UIViewControllerType: NSViewController
    func makeUIViewController(context: Context) -> UIViewControllerType
    func updateUIViewController(_ controller: UIViewControllerType, context: Context)
}

extension UIViewControllerRepresentable {
    func makeNSViewController(context: Context) -> UIViewControllerType {
        makeUIViewController(context: context)
    }
    func updateNSViewController(_ controller: UIViewControllerType, context: Context) {
        updateUIViewController(controller, context: context)
    }
}

protocol UIViewRepresentable: NSViewRepresentable where NSViewType == UIViewType {
    associatedtype UIViewType: NSView
    func makeUIView(context: Context) -> UIViewType
    func updateUIView(_ view: UIViewType, context: Context)
}

extension UIViewRepresentable {
    func makeNSView(context: Context) -> UIViewType { makeUIView(context: context) }
    func updateNSView(_ view: UIViewType, context: Context) { updateUIView(view, context: context) }
}

typealias UITapGestureRecognizer = NSClickGestureRecognizer

final class UIActivityIndicatorView: NSProgressIndicator {
    enum Style { case medium, large }

    convenience init(style: Style) {
        self.init(frame: .zero)
        self.style = .spinning
        controlSize = style == .large ? .large : .regular
        isDisplayedWhenStopped = false
    }

    /// AppKit spinners can't be tinted; a light color switches to the dark look.
    var color: NSColor {
        get { .labelColor }
        set { appearance = NSAppearance(named: newValue == .white ? .darkAqua : .aqua) }
    }

    func startAnimating() { startAnimation(nil) }
    func stopAnimating() { stopAnimation(nil) }
}

// MARK: - Opening links

final class UIApplication {
    static let shared = UIApplication()
    func open(_ url: URL) { NSWorkspace.shared.open(url) }
}

// MARK: - Navigation bar

struct NavigationBarItem {
    enum TitleDisplayMode { case automatic, inline, large }
}

extension ToolbarItemPlacement {
    static var topBarLeading: ToolbarItemPlacement { .navigation }
    static var topBarTrailing: ToolbarItemPlacement { .primaryAction }
    static var navigationBarLeading: ToolbarItemPlacement { .navigation }
    static var navigationBarTrailing: ToolbarItemPlacement { .primaryAction }
}

extension ToolbarPlacement {
    static var navigationBar: ToolbarPlacement { .windowToolbar }
}

// MARK: - Pointer and accessibility

// iPad draws these with the system pointer. The Mac has no hover effect for custom
// cards and rows, so the same calls draw one with `.onHover`: a light tint for
// `.highlight` (rows), a small lift for `.lift` and `.automatic` (tiles and buttons).
enum HoverEffect { case automatic, highlight, lift }

extension View {
    func hoverEffect(_ effect: HoverEffect) -> some View {
        modifier(MacHoverEffect(effect: effect))
    }
}

private struct MacHoverEffect: ViewModifier {
    let effect: HoverEffect
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isHovering && effect == .highlight {
                    RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .allowsHitTesting(false)
                }
            }
            // With Reduce Motion on, a lift brightens instead of growing
            .scaleEffect(isHovering && effect != .highlight && !reduceMotion ? 1.03 : 1)
            .brightness(isHovering && effect != .highlight && reduceMotion ? 0.04 : 0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

enum UIAccessibility {
    enum Notification { case announcement, screenChanged }

    static func post(notification: Notification, argument: Any?) {
        guard let message = argument as? String else { return }
        AccessibilityNotification.Announcement(message).post()
    }
}

// MARK: - Text input

enum UIKeyboardType { case `default`, decimalPad, numberPad, emailAddress, URL, webSearch }

// Mac lists delete with the Delete key and context menus, so there is no edit mode to toggle.
struct EditButton: View {
    var body: some View { EmptyView() }
}

extension View {
    func listSectionSpacing(_ spacing: CGFloat) -> some View { self }
    func navigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View { self }
    func keyboardType(_ type: UIKeyboardType) -> some View { self }
}

// MARK: - Full-screen covers

// A Mac window has no full-screen cover; a sheet sized like a window is the closest fit.
extension View {
    func fullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .frame(minWidth: 720, minHeight: 600)
                .presentationSizing(.fitted)   // size the sheet to the content, not the Mac's default sheet size
        }
    }

    func fullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            content(item)
                .frame(minWidth: 720, minHeight: 600)
                .presentationSizing(.fitted)
        }
    }
}
#endif

// MARK: - Shared

extension ToolbarItemPlacement {
    /// The Done/Exit button that closes a sheet. Top-right on iPhone/iPad. On the Mac the trailing
    /// spot becomes `.primaryAction`, which a sheet doesn't show, so it goes where the Mac puts sheet buttons.
    static var closeSheet: ToolbarItemPlacement {
        #if os(macOS)
        .confirmationAction
        #else
        .navigationBarTrailing
        #endif
    }
}

extension SearchFieldPlacement {
    /// The search field that always shows under the navigation bar on iPhone/iPad;
    /// on the Mac, the window's own search field (at the top of the sidebar when there is one).
    static var alwaysVisible: SearchFieldPlacement {
        #if os(iOS)
        .navigationBarDrawer(displayMode: .always)
        #else
        .automatic
        #endif
    }

    /// The home screen's search: under the navigation bar on iPhone/iPad, at the top of the sidebar on the Mac.
    static var sidebarSearch: SearchFieldPlacement {
        #if os(macOS)
        .sidebar
        #else
        alwaysVisible
        #endif
    }
}

enum DeviceInfo {
    /// True where the roomier iPad layouts fit: iPad and Mac.
    static var isLargeScreen: Bool {
        #if os(macOS)
        true
        #elseif os(visionOS)
        false
        #else
        UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
}

extension View {
    /// Command-W on a sheet's Done button, so a keyboard closes the sheet the way it
    /// closes a window (iPad, and sheets on the Mac, which Command-W doesn't close by itself).
    func closesWithCommandW() -> some View {
        keyboardShortcut("w", modifiers: .command)
    }

    /// Mac: keeps content to a comfortable width, centered, however wide the window gets,
    /// so cards and lines of text don't stretch across a big screen. No change on iPhone/iPad.
    func macReadableWidth(_ maxWidth: CGFloat) -> some View {
        #if os(macOS)
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
        #else
        self
        #endif
    }
}
