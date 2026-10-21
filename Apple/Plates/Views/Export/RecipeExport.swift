import CulinaryIntelligence
import SwiftUI
import UIKit

/// Writes a recipe out in whichever format is being shared. Every file lands in the temporary
/// folder under the recipe's own id, so sharing the same recipe twice does not pile up copies.
enum RecipeExport {
    /// The page a printed or pictured recipe is laid out on, in points.
    static let pageWidth: CGFloat = 612
    static let pageHeight: CGFloat = 792
    static let margin: CGFloat = 48
    private static let spacing: CGFloat = 12

    @MainActor
    static func file(_ format: ShareFormat, for recipe: Recipe) throws -> URL {
        switch format {
        case .plate: try plate(recipe)
        case .image: try image(recipe)
        case .pdf: try pdf(recipe)
        }
    }

    /// The recipe as the app stores it. A `.plate` file is the recipe's JSON under a name the
    /// app recognises.
    static func plate(_ recipe: Recipe) throws -> URL {
        let url = destination(for: recipe, extension: "plate")
        try recipe.fileContents().write(to: url, options: .atomic)
        return url
    }

    /// The whole recipe in one tall picture. A long recipe is drawn at a lower scale, as the
    /// renderer gives nothing back for a picture much over eight thousand pixels tall.
    @MainActor
    static func image(_ recipe: Recipe) throws -> URL {
        let renderer = ImageRenderer(content: RecipePage(recipe: recipe))
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        renderer.scale = min(3, 8000 / max(height, 1))
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw ExportError.renderFailed
        }
        let url = destination(for: recipe, extension: "png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The recipe as pages. The content is drawn rather than photographed, so the text stays
    /// text and can be selected, searched, and edited in a reader.
    @MainActor
    static func pdf(_ recipe: Recipe) throws -> URL {
        let pages = paginate(blocks(for: recipe), title: recipe.title)
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw ExportError.renderFailed
        }
        for page in pages {
            ImageRenderer(content: page).render { size, draw in
                var mediaBox = CGRect(origin: .zero, size: size)
                let info = [
                    kCGPDFContextMediaBox as String: Data(
                        bytes: &mediaBox,
                        count: MemoryLayout<CGRect>.size
                    ),
                ]
                context.beginPDFPage(info as CFDictionary)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        let url = destination(for: recipe, extension: "pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The blocks a recipe is broken into, each one small enough to keep together on a page.
    /// A heading travels with what it introduces, so no page ends on a title with nothing
    /// under it.
    @MainActor
    private static func blocks(for recipe: Recipe) -> [AnyView] {
        var blocks: [AnyView] = [AnyView(RecipeHeader(recipe: recipe))]
        for list in RecipeList.allCases {
            for (index, pair) in PaperItemPair.pairs(recipe.items(in: list)).enumerated() {
                blocks.append(heading(list.title, over: PaperItemPair(items: pair), first: index == 0))
            }
        }
        for (index, step) in recipe.steps.enumerated() {
            blocks.append(heading(
                "Recipe.Detail.Steps",
                over: PaperStepRow(number: index + 1, step: step),
                first: index == 0
            ))
        }
        for (index, note) in recipe.troubleshooting.enumerated() {
            blocks.append(heading(
                "Recipe.Detail.Troubleshooting",
                over: PaperNoteRow(note: note),
                first: index == 0
            ))
        }
        return blocks
    }

    /// A row on its own, or under the heading of the section it opens.
    private static func heading(
        _ title: LocalizedStringResource,
        over row: some View,
        first: Bool
    ) -> AnyView {
        first ? AnyView(PaperSection(title: title) { row }) : AnyView(row)
    }

    /// The blocks packed into pages, measured one at a time so nothing is cut in half. A block
    /// taller than a page keeps a page of its own.
    @MainActor
    private static func paginate(_ blocks: [AnyView], title: String) -> [AnyView] {
        // A little is kept back, so a block measured a hair short of how it draws is never
        // squeezed into what is left of a page and cut short.
        let available = pageHeight - margin * 2 - 12
        let width = pageWidth - margin * 2
        var sheets: [(blocks: [AnyView], used: CGFloat)] = []
        var current: [AnyView] = []
        var used: CGFloat = 0

        func close() {
            guard !current.isEmpty else { return }
            sheets.append((current, used))
            current = []
            used = 0
        }

        for block in blocks {
            let height = measure(block, width: width)
            if !current.isEmpty, used + spacing + height > available {
                close()
            }
            used += current.isEmpty ? height : spacing + height
            current.append(block)
        }
        close()
        return sheets.enumerated().map { index, sheet in
            AnyView(PaperPage(
                title: title,
                blocks: sheet.blocks,
                height: max(pageHeight, sheet.used + margin * 2),
                number: index + 1,
                count: sheets.count
            ))
        }
    }

    /// How tall a block draws at the page's text width.
    @MainActor
    private static func measure(_ block: AnyView, width: CGFloat) -> CGFloat {
        let controller = UIHostingController(rootView: block.frame(width: width))
        controller.view.backgroundColor = .clear
        return controller.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height.rounded(.up)
    }

    private static func destination(for recipe: Recipe, extension suffix: String) -> URL {
        let name = recipe.id.isEmpty ? Recipe.makeID(from: recipe.title) : recipe.id
        return FileManager.default.temporaryDirectory
            .appending(path: "\(name).\(suffix)", directoryHint: .notDirectory)
    }

    enum ExportError: Error {
        case renderFailed
    }
}
