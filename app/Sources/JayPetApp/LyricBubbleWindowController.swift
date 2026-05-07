import AppKit

struct BubbleContent {
    let title: String
    let detail: String?
    let controlSymbolName: String
}

enum BubbleAction {
    case previous
    case playPause
    case next
}

final class LyricBubbleWindowController: NSWindowController {
    private let bubbleView = LyricBubbleView(frame: NSRect(x: 0, y: 0, width: 212, height: 64))
    private let edgePadding: CGFloat = 12
    private let minBubbleWidth: CGFloat = 200
    private let preferredBubbleWidth: CGFloat = 300
    var onAction: ((BubbleAction) -> Void)?

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 212, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.contentView = bubbleView
        super.init(window: panel)
        bubbleView.onAction = { [weak self] action in
            self?.onAction?(action)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(content: BubbleContent, near petFrame: NSRect, visibleFrame: NSRect, layout: BubbleLayout) {
        guard let window else { return }
        let characterSpacing = layout.resolvedMinimumCharacterSpacing
        let availableLeftWidth = petFrame.minX - visibleFrame.minX - edgePadding - layout.gap - characterSpacing
        let widthCap = min(preferredBubbleWidth, max(availableLeftWidth, minBubbleWidth))
        let size = bubbleView.preferredSize(for: content, maxWidth: widthCap)
        let origin = bestOrigin(for: size, petFrame: petFrame, visibleFrame: visibleFrame, layout: layout)
        window.setContentSize(size)
        bubbleView.frame = NSRect(origin: .zero, size: size)
        window.setFrameOrigin(NSPoint(x: round(origin.x), y: round(origin.y)))
        bubbleView.update(content: content)
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func bestOrigin(for size: NSSize, petFrame: NSRect, visibleFrame: NSRect, layout: BubbleLayout) -> NSPoint {
        let headSafetyPadding = max(layout.resolvedHeadSafetyPadding * 0.09, 1)
        let centeredX = petFrame.midX - (size.width / 2) + layout.offsetX
        let aboveY = petFrame.maxY + layout.gap + headSafetyPadding + layout.offsetY
        let clampedX = min(
            max(centeredX, visibleFrame.minX + edgePadding),
            visibleFrame.maxX - size.width - edgePadding
        )
        let clampedY = min(
            max(aboveY, visibleFrame.minY + edgePadding),
            visibleFrame.maxY - size.height - edgePadding
        )
        return NSPoint(x: clampedX, y: clampedY)
    }
}

private final class LyricBubbleView: NSView {
    private let minBubbleWidth: CGFloat = 200
    private let buttonSize: CGFloat = 24
    private let buttonSpacing: CGFloat = 4
    private let leftInset: CGFloat = 12
    private let rightInset: CGFloat = 10
    private let textControlGap: CGFloat = 6
    private let materialView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let previousButton = NSButton()
    private let playPauseButton = NSButton()
    private let nextButton = NSButton()
    var onAction: ((BubbleAction) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        materialView.material = .hudWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 16
        materialView.layer?.masksToBounds = true
        materialView.alphaValue = 0.92
        addSubview(materialView)

        titleLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        materialView.addSubview(titleLabel)

        detailLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 1
        detailLabel.lineBreakMode = .byTruncatingTail
        materialView.addSubview(detailLabel)

        configureButton(previousButton, action: #selector(onPreviousTap))
        configureButton(playPauseButton, action: #selector(onPlayPauseTap))
        configureButton(nextButton, action: #selector(onNextTap))
        materialView.addSubview(previousButton)
        materialView.addSubview(playPauseButton)
        materialView.addSubview(nextButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(content: BubbleContent) {
        titleLabel.stringValue = content.title
        detailLabel.stringValue = content.detail ?? ""
        detailLabel.isHidden = (content.detail ?? "").isEmpty
        setSymbol(named: "backward.fill", on: previousButton)
        setSymbol(named: content.controlSymbolName, on: playPauseButton)
        setSymbol(named: "forward.fill", on: nextButton)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        materialView.frame = bounds

        let controlsWidth = controlGroupWidth
        let controlsX = bounds.maxX - rightInset - controlsWidth
        let controlsY = bounds.midY - (buttonSize / 2)
        previousButton.frame = NSRect(x: controlsX, y: controlsY, width: buttonSize, height: buttonSize)
        playPauseButton.frame = NSRect(x: controlsX + buttonSize + buttonSpacing, y: controlsY, width: buttonSize, height: buttonSize)
        nextButton.frame = NSRect(x: controlsX + (buttonSize + buttonSpacing) * 2, y: controlsY, width: buttonSize, height: buttonSize)

        let textWidth = max(controlsX - textControlGap - leftInset, 1)
        if detailLabel.isHidden {
            let titleHeight = wrappedTextHeight(
                titleLabel.stringValue,
                font: titleLabel.font ?? NSFont.systemFont(ofSize: 12, weight: .semibold),
                width: textWidth
            )
            titleLabel.frame = NSRect(
                x: leftInset,
                y: bounds.midY - (titleHeight / 2),
                width: textWidth,
                height: titleHeight
            )
            detailLabel.frame = .zero
            return
        }

        let detailHeight: CGFloat = 14
        let titleHeight = wrappedTextHeight(
            titleLabel.stringValue,
            font: titleLabel.font ?? NSFont.systemFont(ofSize: 12, weight: .semibold),
            width: textWidth
        )
        detailLabel.frame = NSRect(x: leftInset, y: 8, width: textWidth, height: detailHeight)
        titleLabel.frame = NSRect(x: leftInset, y: detailLabel.frame.maxY + 3, width: textWidth, height: titleHeight)
    }

    func preferredSize(for content: BubbleContent, maxWidth: CGFloat) -> NSSize {
        update(content: content)
        let reservedWidth = leftInset + textControlGap + controlGroupWidth + rightInset
        let maxTextWidth = max(maxWidth - reservedWidth, 84)
        let titleFont = titleLabel.font ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
        let detailFont = detailLabel.font ?? NSFont.systemFont(ofSize: 11, weight: .medium)
        let detailText = content.detail ?? ""
        let naturalTextWidth = max(
            singleLineWidth(content.title, font: titleFont),
            detailText.isEmpty ? 0 : singleLineWidth(detailText, font: detailFont)
        )
        let textWidth = min(max(naturalTextWidth, 84), maxTextWidth)
        let width = min(max(textWidth + reservedWidth, minBubbleWidth), maxWidth)
        let finalTextWidth = max(width - reservedWidth, 1)
        let titleHeight = wrappedTextHeight(content.title, font: titleFont, width: finalTextWidth)
        let titleLineCount = max(1, Int(ceil(titleHeight / 16)))
        let height: CGFloat
        if detailText.isEmpty {
            height = titleLineCount > 1 ? 54 : 40
        } else {
            height = titleLineCount > 1 ? 70 : 56
        }
        return NSSize(width: width, height: height)
    }

    private var controlGroupWidth: CGFloat {
        buttonSize * 3 + buttonSpacing * 2
    }

    private func singleLineWidth(_ text: String, font: NSFont) -> CGFloat {
        let size = (text as NSString).size(withAttributes: [.font: font])
        return ceil(size.width)
    }

    private func wrappedTextHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: 80),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .paragraphStyle: paragraph
            ]
        ).integral
        return max(ceil(rect.height), 16)
    }

    private func configureButton(_ button: NSButton, action: Selector) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        button.contentTintColor = .labelColor
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = true
    }

    private func setSymbol(named symbolName: String, on button: NSButton) {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        button.image = image
    }

    @objc private func onPlayPauseTap() {
        onAction?(.playPause)
    }

    @objc private func onPreviousTap() {
        onAction?(.previous)
    }

    @objc private func onNextTap() {
        onAction?(.next)
    }
}
