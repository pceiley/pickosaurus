import AppKit

struct PickerRequest: Identifiable {
    let id = UUID()
    let context: RoutingContext
    let location: NSPoint
}

/// Keep distinct clicks in arrival order; repeated deliveries cannot replace an active choice.
struct PickerRequestQueue {
    private(set) var requests: [PickerRequest] = []
    var current: PickerRequest? { requests.first }

    @discardableResult
    mutating func append(_ context: RoutingContext, at location: NSPoint) -> Bool {
        guard requests.count < 100, !requests.contains(where: { $0.context.url == context.url }) else { return false }
        requests.append(PickerRequest(context: context, location: location))
        return true
    }

    @discardableResult
    mutating func finish(_ id: UUID) -> Bool {
        guard current?.id == id else { return false }
        requests.removeFirst()
        return true
    }
}

enum PickerMenuPosition {
    /// Capture the pointer when macOS delivers the URL, not after discovery or queuing.
    static func anchor(at pointer: NSPoint, visibleFrames: [NSRect]) -> NSPoint {
        let screen = visibleFrames.first { $0.contains(pointer) }
            ?? visibleFrames.min { distance(pointer, to: $0) < distance(pointer, to: $1) }
        guard let screen else { return pointer }
        return NSPoint(x: min(max(pointer.x + 6, screen.minX + 4), screen.maxX - 4),
                       y: min(max(pointer.y - 6, screen.minY + 4), screen.maxY - 4))
        // AppKit fits the actual menu (including scrolling) to this screen.
    }

    private static func distance(_ point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
