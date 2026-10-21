import Foundation

/// Where recipe JSON lives. The user picks one in the ellipsis menu.
enum StorageLocation: String, CaseIterable, Identifiable, Sendable {
    case onMyIPhone
    case iCloudDrive

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .onMyIPhone: "Storage.OnMyDevice"
        case .iCloudDrive: "Storage.ICloudDrive"
        }
    }

    var symbol: String {
        switch self {
        case .onMyIPhone: "iphone"
        case .iCloudDrive: "icloud"
        }
    }

    /// The folder recipes are read from and written to, or nil when iCloud Drive is signed out.
    var directory: URL? {
        switch self {
        case .onMyIPhone:
            return try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        case .iCloudDrive:
            guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                return nil
            }
            return container.appending(path: "Documents", directoryHint: .isDirectory)
        }
    }

    var isAvailable: Bool { directory != nil }
}
