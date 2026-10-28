import AppKit
import ServiceManagement

@MainActor final class App: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let login: NSMenuItem
    // hover preview: a borderless panel to the right of the highlighted transform item (3 lines of the result + a count)
    let preview = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 170, height: 96), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let previewText = NSTextField(wrappingLabelWithString: "")
    let previewCount = NSTextField(labelWithString: "")
    let previewStack: NSStackView

    override init() {
        let menu = NSMenu()
        login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        previewStack = NSStackView()
        super.init()
        preview.level = .popUpMenu
        preview.isOpaque = false
        preview.backgroundColor = .clear
        preview.hasShadow = true
        preview.ignoresMouseEvents = true
        let box = NSVisualEffectView(frame: preview.contentView!.bounds)
        box.material = .menu
        box.state = .active
        box.wantsLayer = true
        box.layer?.cornerRadius = 8
        box.layer?.masksToBounds = true
        preview.contentView = box
        let header = NSTextField(labelWithString: "PREVIEW")
        header.font = .systemFont(ofSize: 10, weight: .semibold)
        header.textColor = .secondaryLabelColor
        previewText.font = .systemFont(ofSize: 11)
        previewText.maximumNumberOfLines = 3  // wraps, then ellipsizes the third line; a truncating lineBreakMode would stop the wrapping
        previewText.preferredMaxLayoutWidth = 150
        previewCount.font = .systemFont(ofSize: 10)
        previewCount.textColor = .secondaryLabelColor
        let stack = previewStack
        stack.setViews([header, previewText, previewCount], in: .top)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.frame = box.bounds
        stack.autoresizingMask = [.width, .height]
        box.addSubview(stack)
        // shortcut: capitalized lowercases the rest of each word ("iPhone NASA" -> "Iphone Nasa", "3rd" -> "3Rd"), upgrade if acronyms matter
        let transforms: [(String, (String) -> String)] = [
            ("UPPERCASE", { $0.uppercased() }), ("lowercase", { $0.lowercased() }),
            ("Title Case", { $0.capitalized }), ("Remove Formatting", { $0 }),  // writing only .string drops rich text
        ]
        for (title, f) in transforms {
            let m = menu.addItem(withTitle: title, action: #selector(transform(_:)), keyEquivalent: "")
            m.target = self
            m.representedObject = f
        }
        menu.addItem(.separator())
        login.target = self
        menu.addItem(login)
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self
        item.menu = menu
        // template glyph (clipboard + sparkle) matching assets/icon.svg; coordinates are a 24-unit grid, y down
        let glyph = NSImage(size: NSSize(width: 22, height: 22), flipped: true) { _ in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.translateBy(x: 1.8, y: 1)  // keeps the glyph where it was after scaling down; the star tip stays inside the 22pt image
            ctx.scaleBy(x: 20.0 / 24, y: 20.0 / 24)
            let board = NSBezierPath(roundedRect: NSRect(x: 3, y: 6, width: 14, height: 16), xRadius: 3, yRadius: 3)
            board.lineWidth = 1.8
            board.stroke()
            NSBezierPath(roundedRect: NSRect(x: 7, y: 3.5, width: 6, height: 4), xRadius: 1.5, yRadius: 1.5).fill()
            NSBezierPath(rect: NSRect(x: 6, y: 12, width: 8, height: 1.6)).fill()
            NSBezierPath(rect: NSRect(x: 6, y: 16, width: 5, height: 1.6)).fill()
            let star = NSBezierPath()
            star.move(to: NSPoint(x: 18, y: 2))
            for (x, y) in [(19.3, 5.7), (23, 7), (19.3, 8.3), (18, 12), (16.7, 8.3), (13, 7), (16.7, 5.7)] { star.line(to: NSPoint(x: x, y: y)) }
            star.close()
            star.lineWidth = 3.2
            star.lineJoinStyle = .round
            ctx.setBlendMode(.clear)  // knock the sparkle's outline out of the board
            star.stroke()
            ctx.setBlendMode(.normal)
            star.fill()
            return true
        }
        glyph.isTemplate = true
        glyph.accessibilityDescription = "Clippy"
        item.button?.image = glyph
    }

    func clipboardText() -> String? {
        let pb = NSPasteboard.general
        // bail on files/images: Finder and "Copy Image" also put text on the pasteboard, and clearContents would wipe them
        guard pb.availableType(from: [.fileURL, .tiff, .png]) == nil else { return nil }
        return pb.string(forType: .string)
    }

    @objc func transform(_ sender: NSMenuItem) {
        guard let s = clipboardText(), let f = sender.representedObject as? (String) -> String else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(f(s), forType: .string)
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard let item, let f = item.representedObject as? (String) -> String, let s = clipboardText(), let bar = self.item.button?.window, let screen = bar.screen else { return preview.orderOut(nil) }
        previewText.stringValue = f(String(s.prefix(200)))  // 3 lines never show more than this
        previewCount.stringValue = "\(s.count.formatted()) characters"
        preview.setContentSize(NSSize(width: 170, height: previewStack.fittingSize.height))  // 1 to 3 lines tall, no empty space
        // the menu hangs below the status item, left-aligned with it; flip the card left when the status item is near the screen edge
        var x = bar.frame.minX + menu.size.width + 6
        if x + preview.frame.width > screen.frame.maxX { x = bar.frame.minX - 6 - preview.frame.width }
        // shortcut: row offset assumes equal row heights (the separator is shorter), upgrade if the card drifts off the hovered item
        let row = menu.size.height / CGFloat(menu.items.count) * CGFloat(menu.index(of: item))
        preview.setFrameTopLeftPoint(NSPoint(x: x, y: bar.frame.minY - row))
        preview.orderFront(nil)
    }

    func menuDidClose(_ menu: NSMenu) { preview.orderOut(nil) }

    @objc func toggleLogin() {
        let s = SMAppService.mainApp
        do {
            switch s.status {
            case .enabled: try s.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default:
                try s.register()
                if s.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            NSApp.activate()  // accessory apps' alerts otherwise open behind other windows
            NSAlert(error: error).runModal()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // image instead of .state: macOS 26 gives Quit an icon, which pushes the state checkmark out of line with the text
        login.image = NSImage(systemSymbolName: SMAppService.mainApp.status == .enabled ? "checkmark.circle.fill" : "circle", accessibilityDescription: nil)
    }
}

let app = NSApplication.shared
let delegate = App()
app.run()
