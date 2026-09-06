//
//  PassportWidgetLiveActivity.swift
//  PassportWidget
//
//  Created by George Clinkscales on 9/5/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PassportWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PassportWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PassportWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PassportWidgetAttributes {
    fileprivate static var preview: PassportWidgetAttributes {
        PassportWidgetAttributes(name: "World")
    }
}

extension PassportWidgetAttributes.ContentState {
    fileprivate static var smiley: PassportWidgetAttributes.ContentState {
        PassportWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PassportWidgetAttributes.ContentState {
         PassportWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PassportWidgetAttributes.preview) {
   PassportWidgetLiveActivity()
} contentStates: {
    PassportWidgetAttributes.ContentState.smiley
    PassportWidgetAttributes.ContentState.starEyes
}
