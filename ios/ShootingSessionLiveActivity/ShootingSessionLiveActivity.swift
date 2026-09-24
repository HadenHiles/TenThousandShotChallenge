import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ShootingSessionWidgets: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            ShootingSessionLiveActivity()
        }
    }
}

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    typealias LiveDeliveryData = ContentState

    struct ContentState: Codable, Hashable {}

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        "\(id)_\(key)"
    }
}

private let sharedDefaults = UserDefaults(
    suiteName: "group.com.howtohockey.tenthousandshotchallenge"
)!

@available(iOSApplicationExtension 16.1, *)
struct ShootingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            sessionView(context: context)
                .activityBackgroundTint(Color(red: 0.12, green: 0.12, blue: 0.14))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Shots", systemImage: "figure.hockey")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(shotCount(context))")
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    timer(context)
                }
            } compactLeading: {
                Image(systemName: "figure.hockey")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Text("\(shotCount(context))")
                    .font(.caption.bold())
            } minimal: {
                Image(systemName: "figure.hockey")
                    .foregroundStyle(.red)
            }
            .keylineTint(.red)
        }
    }

    private func sessionView(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.hockey")
                .font(.title2)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text("Shooting Session")
                    .font(.headline)
                timer(context)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(shotCount(context))")
                    .font(.title.bold())
                    .foregroundStyle(.red)
                Text("SHOTS")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func timer(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        Text(startDate(context), style: .timer)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private func shotCount(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> Int {
        sharedDefaults.integer(forKey: context.attributes.prefixedKey("shotCount"))
    }

    private func startDate(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> Date {
        let milliseconds = sharedDefaults.double(forKey: context.attributes.prefixedKey("startedAt"))
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }
}