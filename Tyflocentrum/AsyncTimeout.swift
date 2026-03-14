import Foundation

enum AsyncTimeoutError: Error {
	case timedOut
}

func withTimeout<T>(
	_ seconds: TimeInterval,
	operation: @escaping @Sendable () async throws -> T
) async throws -> T {
	guard seconds > 0 else { return try await operation() }

	return try await withThrowingTaskGroup(of: T.self) { group in
		group.addTask {
			try await operation()
		}

		group.addTask {
			try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
			throw AsyncTimeoutError.timedOut
		}

		guard let result = try await group.next() else {
			throw CancellationError()
		}

		group.cancelAll()
		return result
	}
}
