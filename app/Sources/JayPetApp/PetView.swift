import AppKit

final class PetView: NSView {
    private let imageView = NSImageView()
    private var currentImage: NSImage?
    private var currentOpaqueInsets: PixelInsets = .zero
    private var dragStartWindowOrigin = NSPoint.zero
    private var dragStartMouseGlobal = NSPoint.zero
    private var menuProvider: (() -> NSMenu)?
    var onDragBegan: (() -> Void)?
    var onDrag: (() -> Void)?
    var onDragEnded: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: NSImage?, opaqueInsets: PixelInsets = .zero) {
        currentImage = image
        currentOpaqueInsets = opaqueInsets
        imageView.image = image
    }

    func displayedImageFrame() -> NSRect? {
        displayedCanvasFrame()
    }

    func displayedCanvasFrame() -> NSRect? {
        guard let image = currentImage else { return nil }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return nil
        }

        let widthScale = bounds.width / imageSize.width
        let heightScale = bounds.height / imageSize.height
        let scale = min(widthScale, heightScale)
        let renderedSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = NSPoint(
            x: bounds.midX - (renderedSize.width / 2),
            y: bounds.midY - (renderedSize.height / 2)
        )
        return NSRect(origin: origin, size: renderedSize)
    }

    func displayedOpaqueFrame() -> NSRect? {
        guard let canvasFrame = displayedCanvasFrame(), let image = currentImage else { return nil }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        let scaleX = canvasFrame.width / imageSize.width
        let scaleY = canvasFrame.height / imageSize.height
        let visibleOrigin = NSPoint(
            x: canvasFrame.origin.x + (CGFloat(currentOpaqueInsets.left) * scaleX),
            y: canvasFrame.origin.y + (CGFloat(currentOpaqueInsets.bottom) * scaleY)
        )
        let visibleSize = NSSize(
            width: max(canvasFrame.width - (CGFloat(currentOpaqueInsets.left + currentOpaqueInsets.right) * scaleX), 1),
            height: max(canvasFrame.height - (CGFloat(currentOpaqueInsets.top + currentOpaqueInsets.bottom) * scaleY), 1)
        )
        return NSRect(origin: visibleOrigin, size: visibleSize)
    }

    func setMenuProvider(_ provider: @escaping () -> NSMenu) {
        menuProvider = provider
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartWindowOrigin = window.frame.origin
        dragStartMouseGlobal = NSEvent.mouseLocation
        onDragBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let current = NSEvent.mouseLocation
        let deltaX = current.x - dragStartMouseGlobal.x
        let deltaY = current.y - dragStartMouseGlobal.y
        let newOrigin = NSPoint(x: round(dragStartWindowOrigin.x + deltaX), y: round(dragStartWindowOrigin.y + deltaY))
        window.setFrameOrigin(newOrigin)
        onDrag?()
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnded?()
    }
}
