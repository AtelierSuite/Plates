import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// The lock screen and Dynamic Island face of a recipe being written. Every string it draws
/// was localized by the app before it was handed over, so it is all shown verbatim.
struct GenerationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenerationActivityAttributes.self) { context in
            HStack(alignment: .top, spacing: 12) {
                glyph
                VStack(alignment: .leading, spacing: 6) {
                    header(context.state)
                    bar(context.state)
                }
                percent(context.state)
            }
            .padding(16)
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    glyph
                }
                DynamicIslandExpandedRegion(.trailing) {
                    percent(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        header(context.state)
                        bar(context.state)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "apple.intelligence")
                    .foregroundStyle(Color.plates)
            } compactTrailing: {
                ProgressView(value: context.state.fraction)
                    .progressViewStyle(.circular)
                    .tint(Color.plates)
                    .frame(width: 16, height: 16)
            } minimal: {
                ProgressView(value: context.state.fraction)
                    .progressViewStyle(.circular)
                    .tint(Color.plates)
            }
        }
    }

    /// The mark that says the writing is the model's work.
    private var glyph: some View {
        Image(systemName: "apple.intelligence")
            .font(.title3)
            .foregroundStyle(Color.plates)
            .frame(width: 28, height: 28)
    }

    /// The dish over the line saying what is being written, or how it ended.
    @ViewBuilder
    private func header(_ state: GenerationActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if let dish = state.dish, !dish.isEmpty {
                Text(verbatim: dish)
                    .font(.headline)
                    .lineLimit(1)
            }
            Text(verbatim: state.outcome ?? state.stage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// How far along the recipe is. There is nothing left to fill once it has an outcome, so
    /// the bar steps aside for the line that says how it ended.
    @ViewBuilder
    private func bar(_ state: GenerationActivityAttributes.ContentState) -> some View {
        if state.outcome == nil {
            ProgressView(value: state.fraction)
                .progressViewStyle(.linear)
                .tint(Color.plates)
        }
    }

    /// The same fraction in figures, for the corner the bar does not reach.
    @ViewBuilder
    private func percent(_ state: GenerationActivityAttributes.ContentState) -> some View {
        if state.outcome == nil {
            Text(verbatim: state.fraction.formatted(.percent.precision(.fractionLength(0))))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

extension Color {
    /// The app's accent, written out here because the widget extension carries no asset catalog.
    /// Both appearances are kept, since the lock screen draws the activity either way.
    static let plates = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xF2 / 255, green: 0x91 / 255, blue: 0x3F / 255, alpha: 1)
            : UIColor(red: 0xE0 / 255, green: 0x6F / 255, blue: 0x25 / 255, alpha: 1)
    })
}
