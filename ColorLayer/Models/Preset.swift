import Foundation

struct Preset: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var parameters: FilterParameters
    let isLocked: Bool
}
