import AppKit

/// The Spotlight-style window: a search field above the list of matching items.
/// Calls `onFinish` with the picked text, or with nil when the user cancels.
@MainActor
final class Menu: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let width: CGFloat = 680
    private let barHeight: CGFloat = 56
    private let rowHeight: CGFloat = 34
    private let bottomPadding: CGFloat = 8
    /// Transparent space between the background and the window's edges. While
    /// the window is key, Liquid Glass draws its own shadow up to about 48
    /// points out, and the window clips anything drawn past its edges.
    private let margin: CGFloat = 48

    private let items: [String]
    private let options: Options
    private let onFinish: (String?) -> Void
    private var matches: [String] = []
    /// Where the window's top-left corner goes. The window grows downward from it.
    private var topLeft = NSPoint.zero

    private let panel = Panel(contentRect: .zero, styleMask: .nonactivatingPanel, backing: .buffered, defer: false)
    private let icon = NSImageView()
    private let field = NSTextField()
    private let table = NSTableView()
    private let scrollView = NSScrollView()

    /// The rounded backdrop that holds the search bar and the list: Liquid
    /// Glass where available, the system blur otherwise.
    private lazy var background: NSView = {
        let content = NSView()
        content.autoresizingMask = [.width, .height]
        for view in [icon, field, scrollView] { content.addSubview(view) }

        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = barHeight / 2
            glass.contentView = content
            return glass
        }
        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = barHeight / 2
        blur.layer?.masksToBounds = true
        blur.addSubview(content)
        return blur
    }()

    init(items: [String], options: Options, onFinish: @escaping (String?) -> Void) {
        self.items = items
        self.options = options
        self.onFinish = onFinish
        super.init()

        // Float above every window, on every Space, including full-screen apps.
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.delegate = self

        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 20, weight: .medium)
        icon.contentTintColor = .secondaryLabelColor

        field.font = .systemFont(ofSize: 22)
        field.placeholderString = options.prompt
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.isScrollable = true
        field.delegate = self

        table.addTableColumn(NSTableColumn(identifier: .init("item")))
        table.headerView = nil
        table.style = .plain
        table.rowHeight = rowHeight
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.refusesFirstResponder = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(pickClickedRow)

        scrollView.documentView = table
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true

        // Glass draws its own shadow into the margin. The blur needs the window's.
        panel.hasShadow = background is NSVisualEffectView
        let container = Container()
        container.onMarginClick = { onFinish(nil) }
        container.addSubview(background)
        panel.contentView = container
    }

    /// Opens the window on the screen with the mouse pointer, where Spotlight opens.
    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? .zero
        topLeft = NSPoint(x: area.midX - width / 2, y: area.maxY - area.height * 0.2)

        update()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    /// Refilters the list, selects the first match, and resizes the window to fit.
    private func update() {
        matches = match(field.stringValue, in: items, caseInsensitive: options.caseInsensitive)
        table.reloadData()
        select(0)

        let rows = min(matches.count, options.lines)
        let listHeight = CGFloat(rows) * rowHeight
        let height = barHeight + (rows > 0 ? listHeight + bottomPadding : 0)
        let frame = NSRect(x: topLeft.x, y: topLeft.y - height, width: width, height: height)
        panel.setFrame(frame.insetBy(dx: -margin, dy: -margin), display: true)
        background.frame = NSRect(x: margin, y: margin, width: width, height: height)

        let fieldHeight = field.intrinsicContentSize.height
        icon.frame = NSRect(x: 20, y: height - (barHeight + 24) / 2, width: 24, height: 24)
        field.frame = NSRect(x: 54, y: height - (barHeight + fieldHeight) / 2, width: width - 74, height: fieldHeight)
        scrollView.frame = NSRect(x: 0, y: bottomPadding, width: width, height: listHeight)
        scrollView.isHidden = rows == 0
        panel.invalidateShadow()
    }

    private func select(_ row: Int) {
        guard !matches.isEmpty else { return }
        let row = min(max(row, 0), matches.count - 1)
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    // MARK: Keys and mouse

    func controlTextDidChange(_ notification: Notification) {
        update()
    }

    /// Handles the keys from the README. Ctrl-N and Ctrl-P arrive as moveDown and moveUp.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        let row = table.selectedRow
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            select(row - 1)
        case #selector(NSResponder.moveDown(_:)):
            select(row + 1)
        case #selector(NSResponder.insertNewline(_:)):
            let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            onFinish(shift || row < 0 ? field.stringValue : matches[row])
        case #selector(NSResponder.insertTab(_:)):
            guard row >= 0 else { break }
            textView.string = matches[row]
            textView.moveToEndOfDocument(nil)
            update()
        case #selector(NSResponder.cancelOperation(_:)):
            onFinish(nil)
        default:
            return false
        }
        return true
    }

    @objc private func pickClickedRow() {
        guard table.clickedRow >= 0 else { return }
        onFinish(matches[table.clickedRow])
    }

    /// Clicking outside the window cancels, as in Spotlight.
    func windowDidResignKey(_ notification: Notification) {
        onFinish(nil)
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        matches.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        RowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView ?? {
            let label = NSTextField(labelWithString: "")
            label.font = .systemFont(ofSize: 15)
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false

            let cell = NSTableCellView()
            cell.identifier = id
            cell.textField = label
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -20),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }()
        cell.textField?.stringValue = matches[row]
        return cell
    }
}

/// A borderless panel that can still take keyboard input.
private final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The window's transparent content view. It holds the background, and a click
/// in the margin around it cancels, like a click outside the window.
private final class Container: NSView {
    var onMarginClick: () -> Void = {}

    override func mouseDown(with event: NSEvent) {
        // Clicks that the background's views don't handle bubble up here too.
        let point = convert(event.locationInWindow, from: nil)
        if !subviews.contains(where: { $0.frame.contains(point) }) { onMarginClick() }
    }
}

/// Draws the selected row as a rounded accent-colored bar. Claiming to be
/// emphasized keeps the accent color and white text while the search field,
/// not the table, has keyboard focus.
private final class RowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { true }
        set {}
    }

    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.selectedContentBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 0), xRadius: 8, yRadius: 8).fill()
    }
}
