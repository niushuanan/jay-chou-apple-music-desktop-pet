import AppKit
import Foundation

@MainActor
extension AppDelegate {
    func setupAnimationTimer() {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.renderAnimationFrame(updateMenus: false)
            }
        }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    func applyAnimationInputAndRender() {
        let now = Date.timeIntervalSinceReferenceDate
        animationRuntime.apply(input: state.currentAnimationInput(), now: now)
        renderAnimationFrame(now: now, updateMenus: true)
    }

    func renderAnimationFrame(now: TimeInterval = Date.timeIntervalSinceReferenceDate, updateMenus: Bool) {
        let presentation = animationRuntime.frame(now: now)
        let imageKey = presentation?.cacheKey ?? "hidden"
        if renderedImageKey != imageKey {
            if let presentation {
                let assetName = presentation.assetName
                petView?.setImage(ResourceLoader.albumImage(named: assetName), opaqueInsets: ResourceLoader.opaqueInsets(named: assetName))
            } else {
                petView?.setImage(nil)
            }
            renderedImageKey = imageKey
            updateBubble()
        } else if updateMenus {
            updateBubble()
        }

        if updateMenus {
            statusItem?.menu = buildStatusMenu()
        }
    }
}
