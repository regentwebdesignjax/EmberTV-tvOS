import Foundation

enum PlaybackProgressStore {
    private static let keyPrefix = "PlaybackProgress_"

    static func progress(for filmID: String) -> TimeInterval? {
        let key = keyPrefix + filmID
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return nil
        }
        let seconds = UserDefaults.standard.double(forKey: key)
        return seconds > 0 ? seconds : nil
    }

    static func saveProgress(_ seconds: TimeInterval, for filmID: String) {
        let key = keyPrefix + filmID
        UserDefaults.standard.set(seconds, forKey: key)
    }

    static func clearProgress(for filmID: String) {
        let key = keyPrefix + filmID
        UserDefaults.standard.removeObject(forKey: key)
    }
}
