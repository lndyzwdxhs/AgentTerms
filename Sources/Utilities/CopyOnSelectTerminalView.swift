import AppKit
import SwiftTerm

/// A terminal view subclass that supports automatic copy-on-select and IME inline display.
final class CopyOnSelectTerminalView: LocalProcessTerminalView {
    var copyOnSelectEnabled: Bool = false

    // MARK: - Copy on Select

    override func selectionChanged(source: Terminal) {
        super.selectionChanged(source: source)
        guard copyOnSelectEnabled else { return }
        copy(self)
    }

    // MARK: - IME Marked Text (inline pre-edit display)

    private var _markedText: String = ""
    private var _markedSelectedRange: NSRange = .init(location: 0, length: 0)
    private lazy var markedLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.isBezeled = false
        label.drawsBackground = true
        label.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9)
        label.textColor = NSColor.labelColor
        label.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        label.isHidden = true
        addSubview(label)
        return label
    }()

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)

        if let attrStr = string as? NSAttributedString {
            _markedText = attrStr.string
        } else if let str = string as? String {
            _markedText = str
        } else {
            _markedText = ""
        }
        _markedSelectedRange = selectedRange

        if _markedText.isEmpty {
            markedLabel.isHidden = true
        } else {
            markedLabel.stringValue = _markedText
            markedLabel.font = self.font
            markedLabel.sizeToFit()
            // Position at the caret location (inline)
            let caretRect = firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil)
            if caretRect != .zero, let window = self.window {
                let windowRect = window.convertFromScreen(caretRect)
                let viewPoint = convert(windowRect.origin, from: nil)
                markedLabel.frame.origin = NSPoint(
                    x: viewPoint.x,
                    y: viewPoint.y
                )
            }
            markedLabel.isHidden = false
        }
    }

    override func unmarkText() {
        super.unmarkText()
        _markedText = ""
        _markedSelectedRange = NSRange(location: 0, length: 0)
        markedLabel.isHidden = true
    }

    override func hasMarkedText() -> Bool {
        return !_markedText.isEmpty
    }

    override func markedRange() -> NSRange {
        if _markedText.isEmpty {
            return NSRange(location: NSNotFound, length: 0)
        }
        return NSRange(location: 0, length: _markedText.count)
    }
}
