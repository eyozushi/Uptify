import ActivityKit
import WidgetKit
import SwiftUI

struct TaskPlayerAttributes: ActivityAttributes {
    public typealias ContentState = TaskPlayerContentState
    
    public struct TaskPlayerContentState: Codable, Hashable {
        var currentTime: String
        var totalTime: String
        var progress: Double
        var isPlaying: Bool
        var isAutoPlay: Bool
    }
    
    var taskTitle: String
    var albumName: String
}