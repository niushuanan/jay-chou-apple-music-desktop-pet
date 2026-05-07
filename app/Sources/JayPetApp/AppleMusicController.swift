import Foundation

final class AppleMusicController: @unchecked Sendable {
    func fetchSnapshotFast() -> TrackSnapshot? {
        let script = """
        tell application "Music"
            set playerStateText to (player state as string)
            set trackNameText to ""
            set trackArtistText to ""
            set trackAlbumText to ""
            set trackDurationValue to 0
            set trackPositionValue to 0
            try
                set currentTrackRef to current track
                set trackNameText to (name of currentTrackRef as string)
                set trackArtistText to (artist of currentTrackRef as string)
                set trackAlbumText to (album of currentTrackRef as string)
                set trackDurationValue to (duration of currentTrackRef as number)
                set trackPositionValue to (player position as number)
            end try
            return "state=" & playerStateText & "||title=" & trackNameText & "||artist=" & trackArtistText & "||album=" & trackAlbumText & "||duration=" & trackDurationValue & "||position=" & trackPositionValue
        end tell
        """
        guard let output = runAppleScript(script, timeoutSeconds: 1.8) else { return nil }
        return parse(output: output, lyrics: nil)
    }

    func fetchSnapshot() -> TrackSnapshot? {
        let script = """
        tell application "Music"
            set playerStateText to (player state as string)
            set trackNameText to ""
            set trackArtistText to ""
            set trackAlbumText to ""
            set trackLyricsText to ""
            set trackDurationValue to 0
            set trackPositionValue to 0
            try
                set currentTrackRef to current track
                set trackNameText to (name of currentTrackRef as string)
                set trackArtistText to (artist of currentTrackRef as string)
                set trackAlbumText to (album of currentTrackRef as string)
                set trackLyricsText to (lyrics of currentTrackRef as string)
                set trackDurationValue to (duration of currentTrackRef as number)
                set trackPositionValue to (player position as number)
            end try
            return "state=" & playerStateText & "||title=" & trackNameText & "||artist=" & trackArtistText & "||album=" & trackAlbumText & "||lyrics=" & trackLyricsText & "||duration=" & trackDurationValue & "||position=" & trackPositionValue
        end tell
        """
        guard let output = runAppleScript(script, timeoutSeconds: 2.5) else { return nil }
        return parse(output: output, lyrics: nil)
    }

    func playPauseToggle() {
        _ = runAppleScript("tell application \"Music\" to playpause", timeoutSeconds: 1.5)
    }

    func play() {
        _ = runAppleScript("tell application \"Music\" to play", timeoutSeconds: 1.5)
    }

    func pause() {
        _ = runAppleScript("tell application \"Music\" to pause", timeoutSeconds: 1.5)
    }

    func stop() {
        _ = runAppleScript("tell application \"Music\" to stop", timeoutSeconds: 1.5)
    }

    func nextTrack() {
        _ = runAppleScript("tell application \"Music\" to next track", timeoutSeconds: 1.5)
    }

    func previousTrack() {
        _ = runAppleScript("tell application \"Music\" to previous track", timeoutSeconds: 1.5)
    }

    func openApp() {
        _ = runAppleScript("tell application \"Music\" to activate", timeoutSeconds: 1.5)
    }

    func fetchLyricsCurrentTrack() -> String? {
        let script = """
        tell application "Music"
            set lyricsText to ""
            try
                set currentTrackRef to current track
                set lyricsText to (lyrics of currentTrackRef as string)
            end try
            return lyricsText
        end tell
        """
        return runAppleScript(script, timeoutSeconds: 2.0)
    }

    func parseFromPlayerInfo(userInfo: [AnyHashable: Any]) -> TrackSnapshot? {
        guard let rawState = userInfo["Player State"] as? String else { return nil }
        let state = TrackSnapshot.PlayerState(rawValue: rawState.lowercased()) ?? .unknown
        let title = userInfo["Name"] as? String ?? ""
        let artist = userInfo["Artist"] as? String ?? ""
        let album = userInfo["Album"] as? String ?? ""
        let duration = userInfo["Total Time"] as? Double ?? 0
        let position = userInfo["Player Position"] as? Double ?? 0
        return TrackSnapshot(
            title: title,
            artist: artist,
            album: album,
            lyrics: "",
            duration: duration,
            position: position,
            state: state
        )
    }

    private func parse(output: String, lyrics: String?) -> TrackSnapshot? {
        let pairs = output.components(separatedBy: "||")
            .filter { $0.contains("=") }

        var map: [String: String] = [:]
        for item in pairs {
            let parts = item.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { map[parts[0]] = parts[1] }
        }

        let state = TrackSnapshot.PlayerState(rawValue: map["state"]?.lowercased() ?? "") ?? .unknown
        return TrackSnapshot(
            title: map["title"] ?? "",
            artist: map["artist"] ?? "",
            album: map["album"] ?? "",
            lyrics: (lyrics ?? map["lyrics"] ?? "").replacingOccurrences(of: "\\r", with: "\n"),
            duration: Double(map["duration"] ?? "0") ?? 0,
            position: Double(map["position"] ?? "0") ?? 0,
            state: state
        )
    }

    private func runAppleScript(_ script: String, timeoutSeconds: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            let deadline = Date().addingTimeInterval(timeoutSeconds)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.03)
            }
            if process.isRunning {
                process.terminate()
                return nil
            }
            guard process.terminationStatus == 0 else { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
