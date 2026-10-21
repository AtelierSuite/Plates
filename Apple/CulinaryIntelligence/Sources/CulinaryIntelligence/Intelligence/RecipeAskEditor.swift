import FoundationModels
import Foundation

/// What the model decided to change, and where. The target is written as a plain token rather
/// than prose, so a plan can be carried out rather than read. Every change lands on one line of
/// the recipe, or adds or drops one, so no pass ever writes a whole list back.
enum EditTarget: String, CaseIterable, Sendable {
    case addIngredient = "add-ingredient"
    case changeIngredient = "change-ingredient"
    case removeIngredient = "remove-ingredient"
    case addTool = "add-tool"
    case changeTool = "change-tool"
    case removeTool = "remove-tool"
    case step
    case addStep = "add-step"
    case removeStep = "remove-step"
    case addNote = "add-note"
    case changeNote = "change-note"
    case removeNote = "remove-note"
    case title
    case time
    case serves

    /// Whether the change is to the title, the time, or the serving count, which are not on
    /// any list.
    var isDetail: Bool { self == .title || self == .time || self == .serves }

    /// Whether the change is about a line the recipe already has, and so needs its number.
    var needsLine: Bool {
        switch self {
        case .changeIngredient, .removeIngredient, .changeTool, .removeTool, .step, .removeStep,
             .changeNote, .removeNote:
            true
        default:
            false
        }
    }
}

/// One change from the plan, ready to carry out.
public struct PlannedEdit: Equatable, Sendable {
    var target: EditTarget
    /// What to call this change on screen. The model writes it, in the cook's language.
    public var title: String
    /// What to change, in the model's own words, handed to the pass that carries it out.
    public var instruction: String
    /// The line it is about, counting from 1 as the recipe was numbered for the plan. For a new
    /// step, the number it takes. 0 when it is about no one line.
    var line: Int
}

/// The plan: what the model decided to change about the recipe, in the order to change it.
@Generable(description: "The changes to make to a recipe")
struct GeneratedEditPlan {
    @Guide(description: "The changes to make, one line of the recipe each. Only what the cook asked for, nothing else.", .count(1...6))
    var edits: [GeneratedEdit]
}

@Generable
struct GeneratedEdit {
    @Guide(
        description: """
            What this change touches. 'add-ingredient', 'change-ingredient', and \
            'remove-ingredient' add, rewrite, or drop one ingredient, and the same for tools and \
            for troubleshooting notes. 'step' rewrites one step, 'add-step' adds one, and \
            'remove-step' drops one. 'title' renames the recipe, 'time' changes its total time, \
            and 'serves' changes how many people it feeds.
            """,
        .anyOf(EditTarget.allCases.map(\.rawValue))
    )
    var target: String

    @Guide(description: "What this change does, as a short imperative title of two to five words, in the language the recipe is written in")
    var title: String

    @Guide(description: "One sentence telling whoever makes this change exactly what to do, in the language the recipe is written in, naming ingredients and tools the way the recipe does")
    var instruction: String

    @Guide(description: "The label of the line this change is about, such as 'I3' for ingredient 3, 'T1' for tool 1, 'S2' for step 2, or 'N4' for note 4. For a new step, the label of the step it goes before. Leave empty for a new ingredient, tool, or note, and for the title, time, or serving count.")
    var line: String
}

/// How many the recipe serves, rewritten.
@Generable(description: "How many people a recipe serves")
struct GeneratedServes {
    @Guide(description: "How many people it serves, as a plain count such as '2' or '2 to 3'")
    var serves: String
}

/// The step an added ingredient goes into.
@Generable(description: "Where an ingredient is used in a recipe's method")
struct GeneratedPlacement {
    @Guide(description: "The number of the step that should use it, counting from 1")
    var step: Int
}

/// How far along a rewrite is. The rows are not known until the model has decided what to
/// change, so unlike a generation they are built as the run goes. A change to the lists adds
/// rows for the steps and notes that named what changed.
public struct EditProgress: Equatable, Sendable {
    /// One planned change, as the screen shows it.
    public struct Change: Equatable, Sendable, Identifiable {
        public enum State: Equatable, Sendable {
            case waiting
            case working
            case done
        }

        public let id: Int
        /// Written by the model, or the title of the step it follows, so shown as written
        /// rather than looked up.
        public var title: String
        public var state: State = .waiting
    }

    /// True until the model has settled on what to change.
    public var isPlanning = true
    public var changes: [Change] = []
    /// How many changes the plan itself called for. Anything past them followed from the plan,
    /// so the bar does not count it.
    var plannedCount = 0
    public var isFinished = false

    /// The recipe as it stands, so the preview under the checklist reads what the changes have
    /// done to it. Written by the model, so shown as written.
    public var title = ""
    public var time = ""
    public var serves = ""
    public var steps: [String] = []

    /// Takes the recipe as it now stands, after a change lands on it.
    mutating func show(_ recipe: Recipe) {
        title = recipe.title
        time = recipe.time
        serves = recipe.serves
        steps = recipe.steps.map(\.title)
    }

    /// Adds rows to the checklist and hands back their ids.
    mutating func append(_ titles: [String]) -> [Int] {
        let first = changes.count
        changes += titles.enumerated().map { Change(id: first + $0.offset, title: $0.element) }
        return Array(first..<changes.count)
    }

    mutating func mark(_ id: Int?, _ state: Change.State) {
        guard let id, changes.indices.contains(id) else { return }
        changes[id].state = state
    }

    /// The change being made right now, for the lock screen.
    var currentTitle: String? {
        changes.first { $0.state == .working }?.title
    }

    /// Working out the plan is worth the first sixth and the planned changes the rest. Only
    /// the planned changes are counted, so the rows added later never send the bar backwards.
    var fraction: Double {
        guard !isFinished else { return 1 }
        guard !isPlanning else { return 0.05 }
        let planned = changes.prefix(plannedCount).filter { $0.state == .done }.count
        let applied = plannedCount == 0 ? 1 : Double(planned) / Double(plannedCount)
        return 0.15 + applied * 0.85
    }

    var activity: ActivityProgress {
        let stage: LocalizedStringResource = if isPlanning {
            LocalizedStringResource(culinary: "Edit.Progress.Planning")
        } else {
            LocalizedStringResource(culinary: "Edit.Progress.Applying")
        }
        return ActivityProgress(
            stage: String(localized: stage),
            dish: currentTitle,
            fraction: fraction
        )
    }
}

/// Rewrites a recipe from a request in the cook's own words.
///
/// The model decides what to change once, against the recipe with every line numbered, and
/// each change it decides on lands on one line: one ingredient, one tool, one step, or one
/// note, rewritten, added, or dropped. Asked to write a whole list back with one thing changed,
/// the on-device model dropped lines, moved them between sections, lost their notes, and
/// rewrote the ones it was told to keep, so the lists are kept in code and only the line that
/// changes is ever written. A line is dropped in code, and a serving count is scaled in code.
///
/// What changed in the lists is then followed through in code: every step, note, and line
/// that names an ingredient or tool that was swapped or taken out is rewritten for it, one at a
/// time. The plan sees step titles only, so it cannot know which steps say "guanciale", and
/// left to it a swap changed the shopping list and none of the method.
///
/// There is no read through at the end. One was tried, checking the recipe against the request
/// and making what it found the same way, and on the edit evals it met no more requests than
/// going without, while undoing swaps the cook asked for, scaling a recipe a second time, and
/// writing its reasoning into the steps.
@MainActor
@Observable
public final class RecipeAskEditor {
    public enum State: Equatable {
        case idle
        case working
        case awaitingApproval
        case failed(String)
    }

    public private(set) var state: State = .idle

    public private(set) var progress = EditProgress() {
        didSet { observer?.runUpdated(progress.activity) }
    }

    public private(set) var proposedEdits: [PlannedEdit] = []
    private var plannedRecipe: Recipe?
    private var plannedRequest = ""

    /// The plan and the changes on it.
    private let passes = ModelPasses()

    /// Where the run reports how far along it is.
    private let observer: (any RunObserver)?

    public init(observer: (any RunObserver)? = nil) {
        self.observer = observer
    }

    public var isAvailable: Bool { passes.isAvailable }

    public var unavailableReason: LocalizedStringResource? { passes.unavailableReason }

    /// Plans changes without generating or saving any rewritten recipe content.
    public func prepare(_ recipe: Recipe, request: String) async {
        guard state != .working else { return }
        state = .working
        proposedEdits = []
        plannedRecipe = nil
        progress = EditProgress()
        progress.show(recipe)
        passes.beginBackgroundRun(named: "Recipe edit planning")
        defer { passes.endBackgroundRun() }
        do {
            let plan = try await planEdits(for: recipe, request: request)
            guard !plan.isEmpty else { throw EditError.nothingToChange }
            proposedEdits = plan
            plannedRecipe = recipe
            plannedRequest = request
            progress.isPlanning = false
            state = .awaitingApproval
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Plans the changes and makes them at once, for a recipe the cook reads again on the same
    /// screen. A request that fails leaves the editor ready for the next one.
    public func revise(_ recipe: Recipe, request: String) async -> Recipe? {
        await prepare(recipe, request: request)
        if let revised = await applyApprovedPlan() { return revised }
        if case .awaitingApproval = state { discardPlan() }
        return nil
    }

    public func discardPlan() {
        guard state != .working else { return }
        proposedEdits = []
        plannedRecipe = nil
        plannedRequest = ""
        state = .idle
    }

    /// Applies exactly the reviewed plan to the recipe it was prepared for.
    public func applyApprovedPlan() async -> Recipe? {
        guard state == .awaitingApproval, let recipe = plannedRecipe,
              !proposedEdits.isEmpty else { return nil }
        let plan = proposedEdits
        let request = plannedRequest
        state = .working
        progress = EditProgress()
        progress.show(recipe)
        progress.isPlanning = false
        progress.plannedCount = plan.count
        let rows = progress.append(plan.map(\.title))
        observer?.runStarted(progress.activity)
        passes.beginBackgroundRun(named: "Recipe editing")
        defer { passes.endBackgroundRun() }
        do {
            let edited = try await carryOut(Array(zip(plan, rows)), on: recipe, request: request)
            progress.isFinished = true
            state = .idle
            observer?.runEnded(progress.activity, succeeded: true)
            return Self.tidied(edited, against: recipe)
        } catch {
            state = .failed(error.localizedDescription)
            observer?.runEnded(progress.activity, succeeded: false)
            return nil
        }
    }

    // MARK: - Working out what to change

    /// Asks what to change. A plan with nothing in it that can be carried out, which is a plan
    /// pointing at lines the recipe does not have, is asked for once more before giving up.
    private func planEdits(for recipe: Recipe, request: String) async throws -> [PlannedEdit] {
        for _ in 0..<2 {
            let plan = try await passes.respond(
                GeneratedEditPlan.self,
                to: Self.planPrompt(for: recipe, request: request),
                instructions: Self.text("Edit.Prompt.Plan"),
                tokenLimit: Self.planTokenLimit
            )
            let edits = Self.swapping(Self.readable(plan.edits, for: recipe), in: recipe, request: request)
            if !edits.isEmpty { return edits }
        }
        return []
    }

    /// A plan with its swaps made into swaps. Told to change a line to swap it, the model still
    /// adds the new thing and leaves the old one listed, or adds one and drops the other. An
    /// addition that names a line the cook also named becomes a change to that line, and an
    /// addition and a removal in the same list become one change.
    private static func swapping(_ plan: [PlannedEdit], in recipe: Recipe, request: String) -> [PlannedEdit] {
        var plan = plan
        let lists: [(add: EditTarget, change: EditTarget, remove: EditTarget, names: [String])] = [
            (.addIngredient, .changeIngredient, .removeIngredient, ingredients(of: recipe).map(\.item)),
            (.addTool, .changeTool, .removeTool, recipe.tools.map(\.name)),
        ]
        for list in lists {
            for index in plan.indices where plan[index].target == list.add {
                let instruction = plan[index].instruction.lowercased()
                let named = list.names.enumerated()
                    .filter { Step.mentions($0.element, in: instruction) && Step.mentions($0.element, in: request) }
                    .min { first, second in
                        func position(_ name: String) -> Int {
                            instruction.range(of: name.lowercased()).map { instruction.distance(from: instruction.startIndex, to: $0.lowerBound) } ?? Int.max
                        }
                        return position(first.element) < position(second.element)
                    }
                guard let named else { continue }
                plan[index].target = list.change
                plan[index].line = named.offset + 1
            }
            let adds = plan.indices.filter { plan[$0].target == list.add }
            let removes = plan.indices.filter { plan[$0].target == list.remove }
            if adds.count == 1, removes.count == 1 {
                let removed = list.names[plan[removes[0]].line - 1]
                plan[adds[0]].target = list.change
                plan[adds[0]].line = plan[removes[0]].line
                plan[adds[0]].instruction = text("Edit.Prompt.Swap", removed, plan[adds[0]].instruction)
                plan.remove(at: removes[0])
            }
            // Two changes to the same line are one too many.
            var seen: Set<Int> = []
            plan.removeAll { $0.target == list.change && !seen.insert($0.line).inserted }
        }
        return plan
    }

    /// The letter each list's lines are labelled with in the plan. A line
    /// is pointed at by its label rather than its number alone: with every list numbered from 1,
    /// the plan asked for "change-ingredient 2" to shorten the second step.
    private static let labels: [(letter: Character, add: EditTarget, change: EditTarget, remove: EditTarget)] = [
        ("I", .addIngredient, .changeIngredient, .removeIngredient),
        ("T", .addTool, .changeTool, .removeTool),
        ("S", .addStep, .step, .removeStep),
        ("N", .addNote, .changeNote, .removeNote),
    ]

    /// The target a change is carried out as. The label says which list, and the target only
    /// whether a line is added, changed, or dropped.
    private static func target(_ target: EditTarget, labelled label: String) -> EditTarget {
        guard !target.isDetail, let letter = label.first,
              let list = labels.first(where: { $0.letter == letter }),
              let written = labels.first(where: { [$0.add, $0.change, $0.remove].contains(target) })
        else { return target }
        if target == written.add { return list.add }
        if target == written.remove { return list.remove }
        return list.change
    }

    /// Reads a plan the model wrote, dropping anything it cannot carry out: a target it made
    /// up, a line the recipe does not have, and the same change asked for twice.
    private static func readable(_ planned: [GeneratedEdit], for recipe: Recipe) -> [PlannedEdit] {
        var seen: Set<String> = []
        return planned.compactMap { edit in
            let token = edit.target.trimmingCharacters(in: .whitespaces).lowercased()
            let title = edit.title.withoutLeakedSyntax.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = edit.line.trimmingCharacters(in: .whitespaces).uppercased()
            guard let written = EditTarget(rawValue: token), !title.isEmpty else { return nil }
            let target = target(written, labelled: label)
            let number = Int(label.filter(\.isNumber)) ?? 0
            let count = switch target {
            case .changeIngredient, .removeIngredient: ingredients(of: recipe).count
            case .changeTool, .removeTool: recipe.tools.count
            case .step, .removeStep: recipe.steps.count
            case .changeNote, .removeNote: recipe.troubleshooting.count
            default: Int.max
            }
            if target.needsLine, !(1...max(1, count)).contains(number) || count == 0 { return nil }
            let line = target.needsLine || target == .addStep ? number : 0
            guard seen.insert("\(token) \(line) \(title)").inserted else { return nil }
            return PlannedEdit(
                target: target,
                title: title,
                instruction: edit.instruction.withoutLeakedSyntax.trimmingCharacters(in: .whitespacesAndNewlines),
                line: line
            )
        }
    }

    // MARK: - Carrying it out

    /// One planned change with the checklist row it ticks, or nil for a change that follows
    /// from another and has a row of its own made for it.
    private typealias Job = (edit: PlannedEdit, row: Int?)

    /// An ingredient or tool that was swapped for another or taken out, so the steps and notes
    /// that name it can be put right.
    private struct ListChange {
        var old: String
        /// What it was swapped for, or nil when it was taken out.
        var new: String?
    }

    /// Carries out a plan against the numbering the plan was written against. Lines are
    /// rewritten in place before any is dropped or added, so no change moves a line another
    /// change was counting on, and the lists are settled before the steps that use them.
    private func carryOut(_ requested: [Job], on original: Recipe, request: String) async throws -> Recipe {
        let (planned, serves) = try await refiled(requested, in: original, request: request)
        var recipe = original
        var changes: [ListChange] = []
        func jobs(_ targets: EditTarget...) -> [Job] {
            planned.filter { targets.contains($0.edit.target) }
        }

        // The shopping list.
        var entries = Self.ingredientEntries(of: recipe)
        var dropped: Set<Int> = []
        var added: [String] = []
        for job in jobs(.changeIngredient) {
            let index = job.edit.line - 1
            let entry = try await run(job) {
                try await changeIngredient(entries[index], job.edit.instruction, in: recipe, changes: changes)
            }
            if !Self.sameName(entry.ingredient.item, entries[index].ingredient.item) {
                changes.append(ListChange(old: entries[index].ingredient.item, new: entry.ingredient.item))
            }
            entries[index] = entry
        }
        for job in jobs(.removeIngredient) {
            let index = job.edit.line - 1
            dropped.insert(index)
            changes.append(ListChange(old: entries[index].ingredient.item, new: nil))
            mark(job, .done)
        }
        entries = entries.enumerated().filter { !dropped.contains($0.offset) }.map(\.element)
        for job in jobs(.addIngredient) {
            let entry = try await run(job) {
                try await addIngredient(job.edit.instruction, in: recipe, changes: changes)
            }
            guard !entries.contains(where: { Self.sameName($0.ingredient.item, entry.ingredient.item) }) else { continue }
            entries.append(entry)
            added.append(entry.ingredient.item)
        }
        // A swap to something the list already carried, such as pecorino to the parmesan
        // listed as its stand in, leaves one line for it rather than two.
        for change in changes {
            guard let new = change.new,
                  let kept = entries.firstIndex(where: { Self.sameName($0.ingredient.item, new) })
            else { continue }
            entries = entries.enumerated()
                .filter { $0.offset == kept || !Self.sameName($0.element.ingredient.item, new) }
                .map(\.element)
        }
        recipe.ingredients = Self.sections(entries)

        // The tools.
        var tools = recipe.tools
        dropped = []
        for job in jobs(.changeTool) {
            let index = job.edit.line - 1
            let tool = try await run(job) {
                try await changeTool(tools[index], job.edit.instruction, in: recipe, changes: changes)
            }
            if !Self.sameName(tool.name, tools[index].name) {
                changes.append(ListChange(old: tools[index].name, new: tool.name))
            }
            tools[index] = tool
        }
        for job in jobs(.removeTool) {
            let index = job.edit.line - 1
            dropped.insert(index)
            changes.append(ListChange(old: tools[index].name, new: nil))
            mark(job, .done)
        }
        tools = tools.enumerated().filter { !dropped.contains($0.offset) }.map(\.element)
        for job in jobs(.addTool) {
            let tool = try await run(job) {
                try await addTool(job.edit.instruction, in: recipe, changes: changes)
            }
            guard !tools.contains(where: { Self.sameName($0.name, tool.name) }) else { continue }
            tools.append(tool)
        }
        recipe.tools = tools
        progress.show(recipe)

        // Lines in the lists whose notes named what changed, such as pancetta "in place of the
        // guanciale".
        // A line written in this run already knows about the change.
        let written = Set(changes.compactMap(\.new).map(Step.comparable) + added.map(Step.comparable))
        entries = Self.ingredientEntries(of: recipe)
        for (index, entry) in entries.enumerated() where !written.contains(Step.comparable(entry.ingredient.item)) {
            guard let note = entry.ingredient.note,
                  let instruction = Self.following(changes, in: note)
            else { continue }
            let job = followUp(.changeIngredient, line: index + 1, title: entry.ingredient.item, instruction)
            let written = try await run(job) {
                try await changeIngredient(entry, instruction, in: recipe, changes: changes)
            }
            // Only the note is taken. Told to put a note right, the pass has renamed the line
            // after the thing the note was about.
            entries[index].ingredient.note = written.ingredient.note
            recipe.ingredients = Self.sections(entries)
        }

        // The method. Steps are rewritten in place first, then dropped and added from the last
        // step back, so a step added or dropped never moves one a later change was counting on.
        var stepJobs = jobs(.step)
        let removing = Set(jobs(.removeStep).map(\.edit.line))
        for (index, step) in original.steps.enumerated() {
            let number = index + 1
            guard !removing.contains(number), !stepJobs.contains(where: { $0.edit.line == number }),
                  let instruction = Self.following(changes, in: Self.words(of: step))
            else { continue }
            stepJobs.append(followUp(.step, line: number, title: step.title, instruction))
        }
        for job in stepJobs.sorted(by: { $0.edit.line < $1.edit.line }) {
            let index = job.edit.line - 1
            recipe.steps[index] = try await run(job) {
                try await followThrough(changes, in: recipe.steps[index]) { instruction in
                    try await rewriteStep(index, instruction ?? job.edit.instruction, in: recipe, changes: changes)
                }
            }
            progress.show(recipe)
        }
        // At the same number, the step is dropped before the new one takes its place.
        let structural = (jobs(.removeStep) + jobs(.addStep)).sorted {
            $0.edit.line == $1.edit.line
                ? $0.edit.target == .removeStep && $1.edit.target != .removeStep
                : $0.edit.line > $1.edit.line
        }
        for job in structural {
            if job.edit.target == .removeStep {
                // A recipe with no method at all is worse than one step too many.
                let index = job.edit.line - 1
                if recipe.steps.indices.contains(index), recipe.steps.count > 1 {
                    recipe.steps.remove(at: index)
                }
                mark(job, .done)
            } else {
                let index = job.edit.line == 0
                    ? recipe.steps.count
                    : min(max(0, job.edit.line - 1), recipe.steps.count)
                let step = try await run(job) {
                    try await addStep(at: index, job.edit.instruction, in: recipe, changes: changes)
                }
                // A step the method already has is not added again. The plan has asked for a new
                // step to make one shorter, so the change is made to the step that is there.
                let title = Step.comparable(step.title)
                if let existing = recipe.steps.firstIndex(where: { Step.comparable($0.title) == title }) {
                    recipe.steps[existing] = try await rewriteStep(existing, job.edit.instruction, in: recipe, changes: changes)
                    continue
                }
                recipe.steps.insert(step, at: index)
            }
            progress.show(recipe)
        }

        // An ingredient added without a step that uses it is worked into the step it belongs in.
        // Left to the plan, an added ingredient was bought and never cooked.
        for job in jobs(.addIngredient) {
            guard let name = added.first(where: { name in
                Step.mentions(name, in: job.edit.instruction) || added.count == 1
            }), !recipe.steps.contains(where: { Step.mentions(name, in: Self.words(of: $0)) })
            else { continue }
            let index = try await placement(Self.text("Edit.Prompt.Placement.Ask", name), job.edit.instruction, in: recipe)
            guard recipe.steps.indices.contains(index) else { continue }
            let instruction = Self.text("Edit.Prompt.Follow.Add", name, job.edit.instruction)
            let follow = followUp(.step, line: index + 1, title: recipe.steps[index].title, instruction)
            recipe.steps[index] = try await run(follow) {
                // Asked to work an ingredient in, the pass has handed the step back without
                // it, so it is asked once more, and a step that still leaves it out is kept as
                // it was rather than changed for nothing.
                for attempt in [instruction, Self.text("Edit.Prompt.Follow.Again", instruction)] {
                    let step = try await rewriteStep(index, attempt, in: recipe, changes: changes)
                    if Step.mentions(name, in: Self.words(of: step)) { return step }
                }
                return recipe.steps[index]
            }
            progress.show(recipe)
        }

        // The troubleshooting notes, put right the same way.
        var notes = recipe.troubleshooting
        var noteJobs = jobs(.changeNote)
        let removingNotes = Set(jobs(.removeNote).map(\.edit.line))
        for (index, note) in notes.enumerated() {
            let number = index + 1
            guard !removingNotes.contains(number), !noteJobs.contains(where: { $0.edit.line == number }),
                  let instruction = Self.following(changes, in: note.problem + " " + note.solution)
            else { continue }
            noteJobs.append(followUp(.changeNote, line: number, title: note.problem, instruction))
        }
        var droppedNotes = removingNotes
        for job in noteJobs {
            let index = job.edit.line - 1
            let note = notes[index]
            let step = try await run(job) {
                try await followThrough(changes, in: Step(title: note.problem, points: [note.solution])) { instruction in
                    let written = try await changeNote(note, instruction ?? job.edit.instruction, in: recipe, changes: changes)
                    return Step(title: written.problem, points: [written.solution])
                }
            }
            // A note about something the recipe no longer has, that could not be put right, is
            // a note about a problem the cook cannot have.
            if Self.names(changes, step) { droppedNotes.insert(job.edit.line) }
            notes[index] = Troubleshooting(problem: step.title, solution: step.points.joined(separator: " "))
        }
        for job in jobs(.removeNote) { mark(job, .done) }
        var problems: Set<String> = []
        notes = notes.enumerated()
            .filter { !droppedNotes.contains($0.offset + 1) && problems.insert(Step.comparable($0.element.problem)).inserted }
            .map(\.element)
        for job in jobs(.addNote) {
            let note = try await run(job) {
                try await addNote(job.edit.instruction, in: recipe, changes: changes)
            }
            notes.append(note)
        }
        recipe.troubleshooting = notes

        // The title, the time, and last of all the serving count, so an ingredient added for
        // the recipe as it was is scaled with the rest.
        var titleJobs = jobs(.title)
        if titleJobs.isEmpty, let instruction = Self.following(changes, in: recipe.title) {
            titleJobs.append(followUp(.title, line: 0, title: recipe.title, instruction))
        }
        let following = jobs(.title).isEmpty
        for job in titleJobs.prefix(1) {
            recipe.title = try await run(job) {
                try await retitle(recipe, job.edit.instruction, request: request, following: following)
            }
            if following {
                recipe.title = Self.replacing(changes, in: recipe.title)
            }
        }
        // A method that changed may take longer or shorter, so the time is checked whenever it
        // did, and not only when the plan asked.
        var timeJobs = jobs(.time)
        if timeJobs.isEmpty, recipe.steps != original.steps, !jobs(.step, .addStep, .removeStep).isEmpty {
            timeJobs.append((PlannedEdit(target: .time, title: "", instruction: "", line: 0), nil))
        }
        for job in timeJobs.prefix(1) {
            recipe.time = try await run(job) {
                try await retime(recipe, before: original, request: request)
            }
        }
        if let serves, let old = Recipe.servings(in: recipe.serves), let new = Recipe.servings(in: serves) {
            for job in jobs(.serves).prefix(1) { mark(job, .done) }
            recipe.scaleAmounts(by: new / old)
            recipe.serves = serves
        }
        progress.show(recipe)
        return recipe
    }

    /// The plan with the changes it filed under the wrong list put where they belong. A change
    /// to one ingredient or tool that names another is moved to that one, and one that names
    /// none of the list is a change to the method: the plan has filed "soak the bread for five
    /// minutes" as a change to the milk. A step that calls for an ingredient the list does not
    /// carry gets a line for it, since the plan has added melted cheese to the method alone.
    /// A change to the serving count that leaves it as it was is a change to the method too:
    /// the plan has filed a shorter soak as one. The new count, when there is one, comes back
    /// with the plan.
    private func refiled(
        _ jobs: [Job],
        in recipe: Recipe,
        request: String
    ) async throws -> (jobs: [Job], serves: String?) {
        let ingredients = Self.ingredients(of: recipe)
        let carried = Set(ingredients.map(\.icon))
        var refiled: [Job] = []
        var serves: String?
        for var job in jobs {
            let instruction = job.edit.instruction
            switch job.edit.target {
            case .serves:
                guard serves == nil else { continue }
                mark(job, .working)
                serves = try await servings(of: recipe, request: request)
                guard serves == nil else { break }
                let step = try await placement(Self.text("Edit.Prompt.Placement.Change"), instruction, in: recipe)
                guard recipe.steps.indices.contains(step) else {
                    mark(job, .done)
                    continue
                }
                job.edit.target = .step
                job.edit.line = step + 1
            case .changeIngredient, .changeTool:
                let names = job.edit.target == .changeIngredient ? ingredients.map(\.item) : recipe.tools.map(\.name)
                guard !Step.mentions(names[job.edit.line - 1], in: instruction) else { break }
                if let other = names.firstIndex(where: { Step.mentions($0, in: instruction) }) {
                    job.edit.line = other + 1
                } else {
                    let step = try await placement(Self.text("Edit.Prompt.Placement.Change"), instruction, in: recipe)
                    guard recipe.steps.indices.contains(step) else { break }
                    job.edit.target = .step
                    job.edit.line = step + 1
                }
            case .step, .addStep:
                guard !jobs.contains(where: { $0.edit.target == .addIngredient }),
                      let asset = RecipeGenerator.namedIngredient(in: instruction),
                      !carried.contains(IconCatalog.ingredientPath(for: asset))
                else { break }
                refiled.append(followUp(.addIngredient, line: 0, title: IconCatalog.displayName(for: asset), instruction))
            default:
                break
            }
            refiled.append(job)
        }
        return (refiled, serves)
    }

    /// Runs one change, ticking its row on the checklist.
    private func run<Value>(_ job: Job, _ body: () async throws -> Value) async throws -> Value {
        mark(job, .working)
        let value = try await body()
        mark(job, .done)
        return value
    }

    private func mark(_ job: Job, _ state: EditProgress.Change.State) {
        progress.mark(job.row, state)
    }

    /// A change that follows from another, with a row of its own on the checklist named for the
    /// line it puts right.
    private func followUp(_ target: EditTarget, line: Int, title: String, _ instruction: String) -> Job {
        let row = progress.append([title]).first
        return (PlannedEdit(target: target, title: title, instruction: instruction, line: line), row)
    }

    /// A step or note rewritten, checked in code for what changed in the lists. Told to take an
    /// ingredient out, the pass has handed the step back word for word, so a rewrite that still
    /// names something swapped or taken out is asked for once more, more plainly, and then put
    /// right in code: a swap by putting in the new name, and a removal by dropping the sentences
    /// that name it.
    private func followThrough(
        _ changes: [ListChange],
        in original: Step,
        _ write: (String?) async throws -> Step
    ) async throws -> Step {
        let named = changes.filter { Step.mentions($0.old, in: Self.words(of: original)) }
        var step = try await write(nil)
        guard Self.names(named, step) else { return step }
        if let again = Self.following(named, in: Self.words(of: step)) {
            step = try await write(Self.text("Edit.Prompt.Follow.Again", again))
        }
        guard Self.names(named, step) else { return step }
        step.title = Self.replacing(named, in: step.title)
        let points = step.points.map { Self.replacing(named, in: $0) }
        let kept = points.filter { point in
            !named.contains { $0.new == nil && Step.mentions($0.old, in: point) }
        }
        step.points = kept.isEmpty ? points : kept
        return step
    }

    /// Whether a step still names anything that was swapped or taken out. Where the new name
    /// holds the old one, as garlic butter holds butter, the new name does not count.
    private static func names(_ changes: [ListChange], _ step: Step) -> Bool {
        changes.contains { change in
            var text = words(of: step)
            if let new = change.new {
                text = text.replacingOccurrences(of: new, with: " ", options: .caseInsensitive)
            }
            return Step.mentions(change.old, in: text)
        }
    }

    /// Text with every swapped name replaced by the one it was swapped for.
    private static func replacing(_ changes: [ListChange], in text: String) -> String {
        changes.reduce(text) { text, change in
            guard let new = change.new else { return text }
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: change.old) + "(e?s)?\\b"
            guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return text
            }
            // Where the text already says the new name, it is left as it is.
            let written = (try? NSRegularExpression(
                pattern: NSRegularExpression.escapedPattern(for: new),
                options: .caseInsensitive
            ))?.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range) ?? []
            var result = text
            for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                guard !written.contains(where: { NSIntersectionRange($0, match.range).length > 0 }),
                      let range = Range(match.range, in: result) else { continue }
                let upper = result[range].first?.isUppercase ?? false
                let word = upper ? new.prefix(1).uppercased() + new.dropFirst() : new.lowercased()
                result.replaceSubrange(range, with: word)
            }
            return result
        }
    }

    /// What a line has to do about the ingredients and tools that changed, or nil when it names
    /// none of them.
    private static func following(_ changes: [ListChange], in text: String) -> String? {
        let named = changes.filter { Step.mentions($0.old, in: text) }
        guard !named.isEmpty else { return nil }
        return named.map { change in
            change.new.map { self.text("Edit.Prompt.Follow.Swap", change.old.lowercased(), $0.lowercased()) }
                ?? self.text("Edit.Prompt.Follow.Remove", change.old.lowercased())
        }.joined(separator: " ")
    }

    // MARK: - One line at a time

    /// One ingredient, with the section it is listed in.
    private struct Entry {
        var section: IngredientShelf?
        var ingredient: Ingredient
    }

    private func changeIngredient(
        _ entry: Entry,
        _ instruction: String,
        in recipe: Recipe,
        changes: [ListChange]
    ) async throws -> Entry {
        let written = try await line(StructuredIngredient.self, [
            Self.summary(of: recipe),
            Self.listed(changes),
            Self.text("Edit.Prompt.Line.Ingredient", Self.line(for: entry.ingredient)),
            Self.text("Edit.Prompt.Ask", instruction),
            Self.text("Edit.Prompt.Line.Ingredient.Ask"),
        ])
        var ingredient = Self.ingredient(written)
        // The same thing keeps the icon it had, so a change to the amount does not redraw it.
        // Something else does not keep the note it had: bacon swapped in for guanciale came
        // back as "cured pork cheek".
        if Self.sameName(ingredient.item, entry.ingredient.item) {
            ingredient.icon = entry.ingredient.icon
        } else if ingredient.note == entry.ingredient.note {
            ingredient.note = nil
        }
        return Entry(section: entry.section, ingredient: ingredient)
    }

    private func addIngredient(
        _ instruction: String,
        in recipe: Recipe,
        changes: [ListChange]
    ) async throws -> Entry {
        let written = try await line(StructuredIngredient.self, [
            Self.summary(of: recipe),
            Self.listed(changes),
            Self.text("Edit.Prompt.Ask", instruction),
            Self.text("Edit.Prompt.Line.Ingredient.Add"),
        ])
        let ingredient = Self.ingredient(written)
        // Whether it can be skipped is the pass's to say. Otherwise it goes on the shelf its
        // icon sits on, since that is read from the catalog rather than guessed.
        let section: IngredientShelf? = if written.section == "optional" {
            nil
        } else if let asset = IconCatalog.iconName(for: ingredient.icon) {
            IconCatalog.shelf(of: asset)
        } else {
            written.section == "pantry" ? .pantry : .fresh
        }
        return Entry(section: section, ingredient: ingredient)
    }

    private func changeTool(
        _ tool: Tool,
        _ instruction: String,
        in recipe: Recipe,
        changes: [ListChange]
    ) async throws -> Tool {
        let written = try await line(GeneratedTool.self, [
            Self.summary(of: recipe),
            Self.listed(changes),
            Self.text("Edit.Prompt.Line.Tool", Self.line(for: tool)),
            Self.text("Edit.Prompt.Ask", instruction),
            Self.text("Edit.Prompt.Line.Tool.Ask"),
        ])
        var changed = Self.tool(written, required: tool.required)
        if Self.sameName(changed.name, tool.name) {
            changed.icon = tool.icon
        } else if changed.note == tool.note {
            changed.note = nil
        }
        return changed
    }

    private func addTool(
        _ instruction: String,
        in recipe: Recipe,
        changes: [ListChange]
    ) async throws -> Tool {
        let written = try await line(GeneratedTool.self, [
            Self.summary(of: recipe),
            Self.listed(changes),
            Self.text("Edit.Prompt.Ask", instruction),
            Self.text("Edit.Prompt.Line.Tool.Add"),
        ])
        // A tool added for a change is one the change needs. The pass has marked the only pan
        // in a recipe as optional, so its guess is not asked for.
        return Self.tool(written, required: true)
    }

    private func rewriteStep(
        _ index: Int,
        _ instruction: String,
        in recipe: Recipe,
        changes: [ListChange]
    ) async throws -> Step {
        let step = recipe.steps[index]
        let written = try await line(StructuredStep.self, [
            Self.summary(of: recipe),
            Self.listed(changes),
            Self.text("Edit.Prompt.Line.Step", String(index + 1), Self.words(of: step)),
            Self.text("Edit.Prompt.Ask", instruction),
            Self.text("Edit.Prompt.Line.Step.Ask"),
        ])
        return Self.step(written, after: step.title) ?? step
    }

    private func addStep(
        at index: Int,
        _ instruction: String,
        in recipe: Recipe,
        changes: [ListChange]
    ) async throws -> Step {
        var lines = [Self.summary(of: recipe), Self.listed(changes)]
        if recipe.steps.indices.contains(index - 1) {
            lines.append(Self.text("Edit.Prompt.Line.Step.Before", Self.words(of: recipe.steps[index - 1])))
        }
        if recipe.steps.indices.contains(index) {
            lines.append(Self.text("Edit.Prompt.Line.Step.After", Self.words(of: recipe.steps[index])))
        }
        lines.append(Self.text("Edit.Prompt.Ask", instruction))
        lines.append(Self.text("Edit.Prompt.Line.Step.Add"))
        guard let step = Self.step(try await line(StructuredStep.self, lines)) else {
            throw IntelligenceError.empty
        }
        return step
    }

    private func changeNote(
        _ note: Troubleshooting,
        _ instruction: String,
        in recipe: Recipe,
        changes: [ListChange]
    ) async throws -> Troubleshooting {
        let written = try await line(GeneratedTroubleshooting.self, [
            Self.summary(of: recipe),
            Self.listed(changes),
            Self.text("Edit.Prompt.Line.Note", note.problem, note.solution),
            Self.text("Edit.Prompt.Ask", instruction),
            Self.text("Edit.Prompt.Line.Note.Ask"),
        ])
        return Self.note(written) ?? note
    }

    private func addNote(
        _ instruction: String,
        in recipe: Recipe,
        changes: [ListChange]
    ) async throws -> Troubleshooting {
        let written = try await line(GeneratedTroubleshooting.self, [
            Self.summary(of: recipe),
            Self.listed(changes),
            Self.text("Edit.Prompt.Ask", instruction),
            Self.text("Edit.Prompt.Line.Note.Add"),
        ])
        guard let note = Self.note(written) else { throw IntelligenceError.empty }
        return note
    }

    /// The title, kept as it is unless the change calls for another. The plan has asked for a
    /// new title to carry a change that was about a tool.
    private func retitle(_ recipe: Recipe, _ instruction: String, request: String, following: Bool) async throws -> String {
        let written = try await line(GeneratedTitle.self, [
            Self.summary(of: recipe),
            Self.text("Edit.Prompt.Request", request),
            Self.text("Edit.Prompt.Ask", instruction),
            following ? Self.text("Edit.Prompt.Line.Title.Follow") : Self.text("Edit.Prompt.Line.Title.Ask", recipe.title),
        ])
        let title = written.title.withoutLeakedSyntax.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? recipe.title : title
    }

    /// The total time, worked out from the method as it now stands against what it took
    /// before, and read back as a minute count however the pass wrote it. The cook's request is
    /// what it is asked against, since the plan has put a time change under the title and
    /// invented a serving count.
    private func retime(_ recipe: Recipe, before original: Recipe, request: String) async throws -> String {
        func method(_ recipe: Recipe) -> String {
            recipe.steps.enumerated()
                .map { "\($0.offset + 1). \(Self.words(of: $0.element))" }
                .joined(separator: "\n")
        }
        let written = try await line(GeneratedTime.self, [
            Self.text("Edit.Prompt.Line.Time.Before", original.time, method(original)),
            Self.text("Edit.Prompt.Request", request),
            Self.text("Edit.Prompt.Line.Time.Now", method(recipe)),
            Self.text("Edit.Prompt.Line.Time.Ask", original.time),
        ])
        let time = RecipeGenerator.time(from: written.time)
        return time.isEmpty ? recipe.time : time
    }

    /// The serving count the cook asked for, or nil when they did not ask for another. Only the
    /// count is the pass's to say. Every amount is scaled to it in code, since a model asked to
    /// double a list gets the arithmetic wrong, and rewrites the lines while it is at it.
    private func servings(of recipe: Recipe, request: String) async throws -> String? {
        let written = try await line(GeneratedServes.self, [
            Self.text("Edit.Prompt.Line.Serves", recipe.serves),
            Self.text("Edit.Prompt.Request", request),
            Self.text("Edit.Prompt.Line.Serves.Ask", recipe.serves),
        ])
        let serves = RecipeGenerator.serves(from: written.serves)
        guard let new = Recipe.servings(in: serves), let old = Recipe.servings(in: recipe.serves),
              abs(new - old) > 0.001 else {
            return nil
        }
        // A cook who gave a figure gave the count. Asked for two, the pass has answered four.
        let figures = request.matches(of: #/\d+/#).compactMap { Double(request[$0.range]) }
        guard figures.isEmpty || figures.contains(new) else { return nil }
        return serves
    }

    /// The step a change belongs in, counting from 0.
    private func placement(_ question: String, _ instruction: String, in recipe: Recipe) async throws -> Int {
        let written = try await line(GeneratedPlacement.self, [
            Self.text(
                "Generate.Prompt.Line.Method",
                ModelPasses.joined(recipe.steps.enumerated().map { "\($0.offset + 1). \($0.element.title)" })
            ),
            Self.text("Edit.Prompt.Ask", instruction),
            question,
        ])
        return written.step - 1
    }

    /// One line written in a session of its own, from the lines of its prompt.
    private func line<Content: Generable>(_ type: Content.Type, _ prompt: [String]) async throws -> Content {
        try await passes.respond(
            type,
            to: prompt.filter { !$0.isEmpty }.joined(separator: "\n\n"),
            instructions: Self.text("Edit.Prompt.Line"),
            tokenLimit: RecipeGenerator.lineTokenLimit
        )
    }

    // MARK: - Assembly

    private static func ingredientEntries(of recipe: Recipe) -> [Entry] {
        (recipe.ingredients.supermarket ?? []).map { Entry(section: .fresh, ingredient: $0) }
            + (recipe.ingredients.general ?? []).map { Entry(section: .pantry, ingredient: $0) }
            + (recipe.ingredients.optional ?? []).map { Entry(section: nil, ingredient: $0) }
    }

    /// Every ingredient in the order the plan numbers them.
    private static func ingredients(of recipe: Recipe) -> [Ingredient] {
        ingredientEntries(of: recipe).map(\.ingredient)
    }

    private static func sections(_ entries: [Entry]) -> IngredientSections {
        func section(_ shelf: IngredientShelf?) -> [Ingredient]? {
            let list = entries.filter { $0.section == shelf }.map(\.ingredient)
            return list.isEmpty ? nil : list
        }
        return IngredientSections(
            supermarket: section(.fresh),
            general: section(.pantry),
            optional: section(nil)
        )
    }

    /// An ingredient as a pass wrote it, pinned to an icon, with its measure words put right.
    private static func ingredient(_ written: StructuredIngredient) -> Ingredient {
        let item = capitalized(written.item.withoutLeakedSyntax)
        let amount = written.amount.withoutLeakedSyntax
        return Ingredient(
            item: item,
            icon: IconCatalog.ingredientPath(
                for: IconCatalog.resolveIngredient(written.icon, itemName: item)
            ),
            amount: Measures.tidied(Measures.readsJapanese ? Measures.japanese(amount) : amount),
            note: trimmed(written.note.withoutLeakedSyntax)
        )
    }

    private static func tool(_ tool: GeneratedTool, required: Bool) -> Tool {
        let name = capitalized(tool.name.withoutLeakedSyntax)
        return Tool(
            name: name,
            icon: IconCatalog.toolPath(for: IconCatalog.resolveTool(tool.icon, itemName: name)),
            required: required,
            note: trimmed(tool.note.withoutLeakedSyntax)
        )
    }

    /// A step as a pass wrote it, cut into its sentences, or nil when it wrote nothing. A pass
    /// has opened the text with the title again, its own or the one the step had before, as
    /// "Cook the second side: Turn them over", so that is taken off.
    private static func step(_ written: StructuredStep, after previous: String? = nil) -> Step? {
        let title = written.title.withoutLeakedSyntax.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = written.text.withoutLeakedSyntax.trimmingCharacters(in: .whitespacesAndNewlines)
        for heading in [title, previous].compactMap({ $0 }) {
            for separator in [":", "：", "."] where text.hasPrefix(heading + separator) {
                text = String(text.dropFirst(heading.count + 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        let points = RecipeGenerator.sentences(in: Measures.tidied(text))
        guard !title.isEmpty, !points.isEmpty else { return nil }
        return Step(title: title, icons: nil, points: points)
    }

    private static func note(_ written: GeneratedTroubleshooting) -> Troubleshooting? {
        let problem = written.problem.withoutLeakedSyntax.trimmingCharacters(in: .whitespacesAndNewlines)
        let solution = written.solution.withoutLeakedSyntax.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !problem.isEmpty, !solution.isEmpty else { return nil }
        return Troubleshooting(problem: problem, solution: solution)
    }

    /// Two names for the same thing, written with a different case or spacing.
    private static func sameName(_ first: String, _ second: String) -> Bool {
        Step.comparable(first) == Step.comparable(second)
    }

    /// The edited recipe put straight: a step the model rewrote is marked with the icons its
    /// words point at, a step it left alone keeps the icons it had minus anything the recipe no
    /// longer carries, and the file it came from is the file it goes back to.
    private static func tidied(_ edited: Recipe, against original: Recipe) -> Recipe {
        var recipe = edited
        recipe.id = original.id
        let ingredients = ingredients(of: recipe)
        let carried = Set(ingredients.map(\.icon) + recipe.tools.map(\.icon))
        let untouched = Set(original.steps)
        recipe.steps = recipe.steps.map { step in
            var step = step
            if untouched.contains(step), let icons = step.icons {
                step.icons = icons.filter(carried.contains)
            } else {
                step.icons = Step.icons(
                    forText: ([step.title] + step.points).joined(separator: " "),
                    ingredients: ingredients,
                    tools: recipe.tools
                )
            }
            if step.icons?.isEmpty ?? false { step.icons = nil }
            return step
        }
        return recipe
    }

    /// A name with its first letter capitalized, the way the lists write them. A pass writes a
    /// new line as "bacon" in a list of "Egg" and "Pecorino".
    private static func capitalized(_ name: String) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = name.first, first.isLowercase else { return name }
        return first.uppercased() + name.dropFirst()
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private enum EditError: LocalizedError {
        case nothingToChange

        var errorDescription: String? {
            String(culinary: "Edit.Error.NoChanges")
        }
    }

    // MARK: - Prompts

    /// The most the plan may write. Six changes run to a few hundred tokens.
    private static let planTokenLimit = 1200

    private static func text(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(culinary: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    private static func planPrompt(for recipe: Recipe, request: String) -> String {
        [
            numbered(recipe),
            text("Edit.Prompt.Plan.Ask", request),
        ].joined(separator: "\n\n")
    }

    /// The recipe with every line labelled, the way the plan points at one. The method is read
    /// as step titles, which is enough to plan against.
    private static func numbered(_ recipe: Recipe) -> String {
        func list(_ heading: String.LocalizationValue, _ letter: Character, _ lines: [String]) -> String {
            ([text(heading)] + lines.enumerated().map {
                text("Edit.Prompt.List.Item", "\(letter)\($0.offset + 1)", $0.element)
            }).joined(separator: "\n")
        }
        var parts = [
            text("Generate.Prompt.Line.Summary", recipe.title, recipe.time, recipe.serves),
            list("Edit.Prompt.List.Ingredients", "I", ingredientEntries(of: recipe).map { entry in
                entry.section == nil
                    ? text("Edit.Prompt.List.Optional", line(for: entry.ingredient, withNote: false))
                    : line(for: entry.ingredient, withNote: false)
            }),
            list("Edit.Prompt.List.Tools", "T", recipe.tools.map(\.name)),
            list("Edit.Prompt.List.Method", "S", recipe.steps.map(\.title)),
        ]
        if !recipe.troubleshooting.isEmpty {
            parts.append(list("Edit.Prompt.List.Notes", "N", recipe.troubleshooting.map(\.problem)))
        }
        return parts.joined(separator: "\n\n")
    }

    /// The recipe as a line pass reads it: what it is, what goes in it, what it is cooked
    /// with, and the method as numbered titles. Short enough that every pass carries it.
    private static func summary(of recipe: Recipe) -> String {
        [
            text("Generate.Prompt.Line.Summary", recipe.title, recipe.time, recipe.serves),
            text(
                "Generate.Prompt.Line.Ingredients",
                ModelPasses.joined(ingredients(of: recipe).map { line(for: $0, withNote: false) })
            ),
            text("Generate.Prompt.Line.Tools", ModelPasses.joined(recipe.tools.map(\.name))),
            text(
                "Generate.Prompt.Line.Method",
                ModelPasses.joined(recipe.steps.enumerated().map { "\($0.offset + 1). \($0.element.title)" })
            ),
        ].joined(separator: "\n")
    }

    /// What has already changed in the lists, so a step written after a swap uses the new name
    /// rather than the old one.
    private static func listed(_ changes: [ListChange]) -> String {
        guard !changes.isEmpty else { return "" }
        let lines = changes.map { change in
            change.new.map { text("Edit.Prompt.Changed.Swap", change.old.lowercased(), $0.lowercased()) }
                ?? text("Edit.Prompt.Changed.Removed", change.old.lowercased())
        }
        return text("Edit.Prompt.Changed", ModelPasses.joined(lines))
    }

    private static func line(for ingredient: Ingredient, withNote: Bool = true) -> String {
        let line = text("Edit.Prompt.Ingredient", ingredient.item, ingredient.amount)
        guard withNote, let note = ingredient.note else { return line }
        return text("Edit.Prompt.WithNote", line, note)
    }

    private static func line(for tool: Tool) -> String {
        guard let note = tool.note else { return tool.name }
        return text("Edit.Prompt.WithNote", tool.name, note)
    }

    /// A step's title and everything it says, as one line.
    private static func words(of step: Step) -> String {
        text("Edit.Prompt.Step", step.title, step.points.joined(separator: " "))
    }
}
