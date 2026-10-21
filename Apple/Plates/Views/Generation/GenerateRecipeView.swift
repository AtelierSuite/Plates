import CulinaryIntelligence
import SwiftUI

/// The sheet that asks for a new recipe and shows it before it is saved. A named dish the
/// kitchen can make is written straight away. Anything else is offered as five ideas first, and
/// the cook picks one or lets Jev pick it. Gemma writes the recipe and Apple Intelligence sorts
/// it, so the sheet waits on both.
struct GenerateRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let store: RecipeStore
    /// Starts a blank recipe instead, titled with whatever was typed, for the cook to fill in.
    let writeByHand: (String) -> Void

    @State private var generator = RecipeGenerator(observer: GenerationActivity.generation)
    @State private var request: GenerationRequest
    @State private var draft: Recipe?
    /// The dishes offered for a request that did not name one the kitchen can make.
    @State private var ideas: [RecipeIdea] = []
    /// The ID a Decide for me pick of these ideas is sent with.
    @State private var requestID = ""
    /// How many Decide for me picks are left today, once the Worker has said.
    @State private var decisionsRemaining: Int?
    @State private var isDeciding = false
    @State private var decideError: String?
    /// Changes the cook asks for once the recipe is written, made before it is saved.
    @State private var editor = RecipeAskEditor(observer: GenerationActivity.edit)
    @State private var revision = ""
    @State private var revisionError: String?
    @FocusState private var isDescriptionFocused: Bool

    /// Opens with the dish already written in when the cook named one before the sheet came
    /// up, as they do at the end of onboarding.
    init(store: RecipeStore, dish: String = "", writeByHand: @escaping (String) -> Void) {
        self.store = store
        self.writeByHand = writeByHand
        _request = State(initialValue: GenerationRequest(description: dish))
    }

    var body: some View {
        NavigationStack {
            Group {
                if isRevising {
                    RevisionProgressView(progress: editor.progress)
                } else if let draft {
                    RecipeConfirmationView(recipe: ConfirmationRecipe(draft)) {
                        DishIcon(recipe: draft, size: 168)
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                            .frame(maxWidth: .infinity)
                    }
                } else if isGenerating {
                    progress
                } else if isPlanning {
                    planning
                } else if !ideas.isEmpty {
                    ideaList
                } else {
                    form
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                        .disabled(isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let draft {
                        Button("Shared.Save") {
                            store.save(draft, isNew: true)
                            dismiss()
                        }
                        .disabled(isBusy)
                    } else if !ideas.isEmpty, !isBusy {
                        Button("Generate.Ideas.Edit") { ideas = [] }
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                if draft != nil {
                    RecipeRevisionBar(
                        text: $revision,
                        isEnabled: editor.isAvailable && !isBusy,
                        canSend: canRevise,
                        send: revise
                    )
                }
            }
        }
        .alert(
            "Edit.Ask.Title",
            isPresented: Binding(
                get: { revisionError != nil },
                set: { if !$0 { revisionError = nil } }
            )
        ) {
            Button("Shared.Done", role: .cancel) {}
        } message: {
            Text(verbatim: revisionError ?? "")
        }
        .interactiveDismissDisabled(isBusy)
        // A pass can take a while, and the sheet is not touched while it runs, so the screen
        // is held awake rather than locking part way through a recipe.
        .onChange(of: isBusy) { UIApplication.shared.isIdleTimerDisabled = isBusy }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// A generated recipe titles itself, so its title is shown as written.
    private var title: Text {
        if let draft {
            Text(verbatim: draft.title)
        } else {
            Text("Generate.Title")
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField(
                    "Generate.Description.Label",
                    text: $request.description,
                    prompt: Text("Generate.Description.Prompt"),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .focused($isDescriptionFocused)
            } footer: {
                Text("Generate.Description.Footer")
            }
        }
        .safeAreaInset(edge: .bottom) { generateBar }
        // The keyboard comes up with the sheet.
        .onAppear { isDescriptionFocused = true }
    }

    /// The one thing left to do on this screen, so it floats over the form rather than sitting
    /// at the end of it. Whatever is keeping the model from answering is said above the button,
    /// and the recipe can always be written by hand instead.
    private var generateBar: some View {
        VStack(spacing: 8) {
            if let reason = generator.unavailableReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if case let .failed(message) = generator.state {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await start() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.intelligence")
                    Text("Menu.Generate")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(!canGenerate)

            Button {
                writeByHand(request.description.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                    Text("Generate.ByHand")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(isBusy)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// While the model works, the form goes away and the passes have the screen to themselves.
    /// The recipe grows under them, so it scrolls rather than running off the bottom.
    private var progress: some View {
        ScrollView {
            GenerationProgressView(progress: generator.progress)
                .padding(.listRowInset)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var isGenerating: Bool { generator.state == .generating }

    private var isPlanning: Bool { generator.state == .planning }

    private var isRevising: Bool { editor.state == .working }

    private var isBusy: Bool { isGenerating || isPlanning || isDeciding || isRevising }

    private var canGenerate: Bool {
        generator.isAvailable && !isBusy && !request.isEmpty
    }

    // MARK: - Revision

    private var trimmedRevision: String {
        revision.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canRevise: Bool {
        editor.isAvailable && !isBusy && !trimmedRevision.isEmpty
    }

    /// The recipe is not saved yet and comes back to this screen to be read, so the changes the
    /// editor plans are made without a separate review. A failed change leaves the draft as it was.
    private func revise() {
        guard let draft, canRevise else { return }
        let ask = trimmedRevision
        Task {
            if let revised = await editor.revise(draft, request: ask) {
                self.draft = revised
                revision = ""
            } else if case let .failed(message) = editor.state {
                revisionError = message
            }
        }
    }

    // MARK: - Ideas

    /// Writes the request as asked, or brings up the ideas for it.
    private func start() async {
        decideError = nil
        guard let plan = await generator.plan(request) else { return }
        switch plan {
        case .write:
            draft = await generator.generate(request)
        case let .ideas(offered, id):
            ideas = offered
            requestID = id
            decisionsRemaining = await generator.decisionsRemaining()
        }
    }

    private func write(_ idea: RecipeIdea) {
        decideError = nil
        Task { draft = await generator.generate(request, idea: idea) }
    }

    /// Jev picks for the cook. A pick that fails leaves the list as it was, and the cook can
    /// still pick one themselves.
    private func decide() {
        decideError = nil
        isDeciding = true
        Task {
            defer { isDeciding = false }
            do {
                let pick = try await generator.decide(request, ideas: ideas, requestID: requestID)
                decisionsRemaining = pick.remaining
                guard ideas.indices.contains(pick.index) else { return }
                write(ideas[pick.index])
            } catch CloudError.limitReached {
                decisionsRemaining = 0
            } catch {
                decideError = error.localizedDescription
            }
        }
    }

    private var planning: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Generate.Planning")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var ideaList: some View {
        List {
            Section {
                ForEach(ideas) { idea in
                    Button {
                        write(idea)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: idea.title)
                                .font(.headline)
                            if !idea.summary.isEmpty {
                                Text(verbatim: idea.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                    .disabled(isBusy)
                }
            } header: {
                Text("Generate.Ideas.Header")
            } footer: {
                Text("Generate.Ideas.Footer")
            }
        }
        .safeAreaInset(edge: .bottom) { decideBar }
    }

    /// Decide for me, with what is left of today's picks. The line above it says why the button
    /// is out for the day, or what went wrong.
    private var decideBar: some View {
        VStack(spacing: 8) {
            if let message = decideError ?? failedMessage {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if decisionsRemaining == 0 {
                Text("Generate.Ideas.Decide.LimitReached")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                decide()
            } label: {
                HStack(spacing: 8) {
                    if isDeciding {
                        ProgressView()
                    } else {
                        Image(systemName: "dice")
                    }
                    Text("Generate.Ideas.Decide")
                    if let decisionsRemaining, decisionsRemaining > 0 {
                        Text(verbatim: String(
                            format: String(localized: "Generate.Ideas.Decide.Remaining"),
                            decisionsRemaining
                        ))
                        .fontWeight(.regular)
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .disabled(isBusy || decisionsRemaining == 0)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var failedMessage: String? {
        if case let .failed(message) = generator.state { message } else { nil }
    }
}
