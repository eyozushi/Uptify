import Flutter
import ActivityKit
import WidgetKit

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<TaskPlayerAttributes>?
    
    func startActivity(with data: [String: Any]) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return false
        }
        
        let attributes = TaskPlayerAttributes(
            taskTitle: data["taskTitle"] as? String ?? "",
            albumName: data["albumName"] as? String ?? ""
        )
        
        let state = TaskPlayerAttributes.ContentState(
            currentTime: data["currentTime"] as? String ?? "00:00",
            totalTime: data["totalTime"] as? String ?? "00:00",
            progress: data["progress"] as? Double ?? 0.0,
            isPlaying: data["isPlaying"] as? Bool ?? false,
            isAutoPlay: data["isAutoPlay"] as? Bool ?? false
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            return true
        } catch {
            print("Live Activity開始エラー: \(error)")
            return false
        }
    }
    
    func updateActivity(with data: [String: Any]) {
        guard let activity = currentActivity else { return }
        
        let state = TaskPlayerAttributes.ContentState(
            currentTime: data["currentTime"] as? String ?? "00:00",
            totalTime: data["totalTime"] as? String ?? "00:00",
            progress: data["progress"] as? Double ?? 0.0,
            isPlaying: data["isPlaying"] as? Bool ?? false,
            isAutoPlay: data["isAutoPlay"] as? Bool ?? false
        )
        
        Task {
            await activity.update(using: .init(state: state, staleDate: nil))
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}