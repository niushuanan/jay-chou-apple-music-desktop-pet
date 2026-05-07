import AppKit

@MainActor
extension AppDelegate {
    func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "JayPet"
        item.menu = buildStatusMenu()
        statusItem = item
    }

    func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "打开 Music", action: #selector(onOpenMusic), keyEquivalent: "o")
        menu.addItem(withTitle: "播放 / 暂停", action: #selector(onPlayPause), keyEquivalent: " ")
        menu.addItem(withTitle: "下一首", action: #selector(onNext), keyEquivalent: "]")
        menu.addItem(withTitle: "上一首", action: #selector(onPrev), keyEquivalent: "[")
        menu.addItem(withTitle: "停止播放", action: #selector(onStop), keyEquivalent: "s")
        menu.addItem(NSMenuItem.separator())
        let lyricItem = NSMenuItem(title: "歌词气泡", action: #selector(onToggleLyrics), keyEquivalent: "l")
        lyricItem.state = state.isLyricsBubbleEnabled ? .on : .off
        menu.addItem(lyricItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出", action: #selector(onQuit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        return menu
    }

    func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "播放 / 暂停", action: #selector(onPlayPause), keyEquivalent: "")
        menu.addItem(withTitle: "下一首", action: #selector(onNext), keyEquivalent: "")
        menu.addItem(withTitle: "上一首", action: #selector(onPrev), keyEquivalent: "")
        menu.addItem(withTitle: "停止播放", action: #selector(onStop), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "打开 Music", action: #selector(onOpenMusic), keyEquivalent: "")
        menu.addItem(withTitle: "歌词气泡开关", action: #selector(onToggleLyrics), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出", action: #selector(onQuit), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc func onPlayPause() { state.playPauseToggle() }
    @objc func onNext() { state.nextTrack() }
    @objc func onPrev() { state.previousTrack() }
    @objc func onStop() { state.stopPlayback() }
    @objc func onOpenMusic() { state.openMusic() }

    @objc func onToggleLyrics() {
        state.toggleLyricsBubble()
        applyAnimationInputAndRender()
    }

    @objc func onQuit() {
        NSApplication.shared.terminate(nil)
    }
}
