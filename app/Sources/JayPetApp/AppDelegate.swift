import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let state = PetStateStore()
    var statusItem: NSStatusItem?
    var window: NSWindow?
    var petView: PetView?
    var bubbleController: LyricBubbleWindowController?
    let animationRuntime = PetAnimationRuntime()
    var animationTimer: Timer?
    var renderedImageKey: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupMenuBar()
        setupAnimationTimer()
        state.start { [weak self] in
            self?.applyAnimationInputAndRender()
        }
        applyAnimationInputAndRender()
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationTimer?.invalidate()
        state.stop()
    }
}
