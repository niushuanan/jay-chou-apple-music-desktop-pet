import AppKit

@MainActor
extension AppDelegate {
    func setupWindow() {
        let size = NSSize(width: 140, height: 160)
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(x: screen.maxX - size.width - 80, y: screen.minY + 120)

        let win = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true

        let view = PetView(frame: NSRect(origin: .zero, size: size))
        view.setMenuProvider { [weak self] in self?.buildContextMenu() ?? NSMenu() }
        view.onDragBegan = { [weak self] in
            self?.state.beginDraggingPet()
        }
        view.onDrag = { [weak self] in
            self?.layoutBubble()
        }
        view.onDragEnded = { [weak self] in
            self?.state.endDraggingPet()
        }
        win.contentView = view
        win.delegate = self
        win.makeKeyAndOrderFront(nil)

        window = win
        petView = view

        let controller = LyricBubbleWindowController()
        controller.onAction = { [weak self] action in
            switch action {
            case .previous:
                self?.onPrev()
            case .playPause:
                self?.onPlayPause()
            case .next:
                self?.onNext()
            }
        }
        bubbleController = controller
    }

    func windowDidMove(_ notification: Notification) {
        layoutBubble()
    }

    func resolvedPetAnchorFrame() -> NSRect? {
        guard let window, let petView, let localRect = petView.displayedOpaqueFrame() ?? petView.displayedCanvasFrame() else {
            return nil
        }
        let rectInWindow = petView.convert(localRect, to: nil)
        let rectOnScreen = window.convertToScreen(rectInWindow)
        let insets = state.currentAlbum?.bubbleLayout.resolvedVisualInsets ?? .zero
        return NSRect(
            x: round(rectOnScreen.minX + insets.left),
            y: round(rectOnScreen.minY + insets.bottom),
            width: max(round(rectOnScreen.width - insets.left - insets.right), 1),
            height: max(round(rectOnScreen.height - insets.top - insets.bottom), 1)
        )
    }
}
