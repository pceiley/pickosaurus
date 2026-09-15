import Foundation

enum BuildConfiguration {
    static var isDebugPreview: Bool {
        #if PICKOSAURUS_DEBUG
        true
        #else
        false
        #endif
    }

    static var settingsDirectoryName: String {
        isDebugPreview ? "Pickosaurus Debug" : "Pickosaurus"
    }
}
