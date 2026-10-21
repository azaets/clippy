import AppKit
import ServiceManagement

@MainActor final class App: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let login: NSMenuItem

    override init() {
        let menu = NSMenu()
        login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        super.init()
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

    @objc func transform(_ sender: NSMenuItem) {
        let pb = NSPasteboard.general
        // bail on files/images: Finder and "Copy Image" also put text on the pasteboard, and clearContents would wipe them
        guard pb.availableType(from: [.fileURL, .tiff, .png]) == nil, let s = pb.string(forType: .string), let f = sender.representedObject as? (String) -> String else { return }
        pb.clearContents()
        pb.setString(f(s), forType: .string)
    }

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
