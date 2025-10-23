import ActivityKit
import WidgetKit
import SwiftUI

struct TaskPlayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskPlayerAttributes.self) { context in
            // ロック画面での表示
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island での表示
            DynamicIslandView(context: context)
        }
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TaskPlayerAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // アルバム情報とコントロール
            HStack {
                // アルバムアートワーク
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.green, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white)
                            .font(.title2)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.taskTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(context.attributes.albumName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    if context.state.isAutoPlay {
                        Text("自動再生中")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // 再生ボタン
                Button(intent: PlayPauseIntent()) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            // 進捗バー
            VStack(spacing: 4) {
                ProgressView(value: context.state.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                
                HStack {
                    Text(context.state.currentTime)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(context.state.totalTime)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(.black)
    }
}