import Foundation
import FoundationModels

@Generable
struct WorldLoreDraft {
    @Guide(description: "Short lore title")
    let title: String

    @Guide(description: "1-3 sentence lore summary")
    let summary: String

    @Guide(description: "Short tags for filtering")
    let tags: [String]
}
