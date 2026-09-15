import ServiceManagement
import Combine

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var isChanging = false
    @Published var errorMessage: String?

    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () async throws -> Void

    init(readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
         register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
         unregister: @escaping () async throws -> Void = { try await SMAppService.mainApp.unregister() }) {
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        status = readStatus()
    }

    var isRequested: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = readStatus() }

    func setEnabled(_ enabled: Bool) async {
        guard !isChanging else { return }
        refresh()
        guard enabled != isRequested else { return }
        isChanging = true
        errorMessage = nil
        defer { refresh(); isChanging = false }
        do {
            if enabled { try register() }
            else { try await unregister() }
        } catch { errorMessage = error.localizedDescription }
    }
}
