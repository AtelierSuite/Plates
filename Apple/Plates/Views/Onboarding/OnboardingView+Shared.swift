import SwiftUI

extension OnboardingView {
    // MARK: - Step header

    func stepHeader(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .padding(10)
                .frame(width: 80, height: 80)
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .padding(.top, 80)
            Text(title)
                .font(.largeTitle.bold())
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Feature row

    /// An icon beside a title and a line under it. Narrow icons sit in the same column as wide
    /// ones, so a page of narrow icons can draw the text in closer.
    func featureRow(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        spacing: CGFloat = 14
    ) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: 36, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Page

    /// A step's scrolling content, with its buttons held at the bottom of the screen.
    func page(
        @ViewBuilder content: () -> some View,
        @ViewBuilder buttons: () -> some View
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                buttons()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Buttons

    func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
    }

    func secondaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }
}
