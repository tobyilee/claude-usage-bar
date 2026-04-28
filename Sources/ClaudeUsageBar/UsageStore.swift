import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class UsageStore {
    enum MenubarState {
        case loading
        case ok(percent: Int)
        case stale(percent: Int)
        case authBad
    }

    var usage: UsageResponse?
    var tier: String?
    var lastUpdated: Date?
    var lastError: String?
    var menubarState: MenubarState = .loading

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var wakeup: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var wakeupGeneration: UInt64 = 0
    @ObservationIgnored private var nextAllowedFetch: Date?

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.tickOnce()
                await self.waitForNext(seconds: 60)
            }
        }
    }

    func refreshNow() {
        wakeupGeneration &+= 1
        if let cont = wakeup {
            wakeup = nil
            cont.resume()
        }
    }

    func quit() {
        pollTask?.cancel()
        NSApp.terminate(nil)
    }

    /// Parks until either 60s passes OR `refreshNow()` is called. A generation counter
    /// guards against a stale timer resuming the next cycle's continuation.
    private func waitForNext(seconds: Int) async {
        wakeupGeneration &+= 1
        let myGen = wakeupGeneration
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.wakeup = cont
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                await MainActor.run {
                    guard let s = self, s.wakeupGeneration == myGen, let c = s.wakeup else { return }
                    s.wakeupGeneration &+= 1
                    s.wakeup = nil
                    c.resume()
                }
            }
        }
    }

    private func tickOnce() async {
        if let nx = nextAllowedFetch, Date() < nx { return }
        do {
            try await tickOnceCore()
        } catch {
            handleError(error)
        }
    }

    private func tickOnceCore() async throws {
        var creds = try KeychainCredentials.read()
        if let exp = creds.expiresAt, exp.timeIntervalSinceNow < 300 {
            creds = try await refreshAndPersist(creds)
        }

        let usageResp: UsageResponse
        do {
            usageResp = try await AnthropicClient.shared.fetchUsage(token: creds.accessToken)
        } catch AnthropicError.unauthorized {
            creds = try await refreshAndPersist(creds)
            usageResp = try await AnthropicClient.shared.fetchUsage(token: creds.accessToken)
        }

        self.usage = usageResp
        self.lastUpdated = Date()
        self.lastError = nil
        self.nextAllowedFetch = nil
        self.menubarState = .ok(percent: highestPercent(usageResp))

        if self.tier == nil {
            if let t = creds.subscriptionType, !t.isEmpty {
                self.tier = t
            } else if let p = try? await AnthropicClient.shared.fetchProfile(token: creds.accessToken) {
                self.tier = p.displayTier
            }
        }
    }

    private func handleError(_ error: Error) {
        if let kc = error as? KeychainError, case .notFound = kc {
            self.lastError = kc.errorDescription
            self.menubarState = .authBad
            return
        }
        if let ae = error as? AnthropicError {
            switch ae {
            case .unauthorized:
                self.lastError = "Token refresh failed — run `claude` to re-login"
                self.menubarState = .authBad
                return
            case .rateLimited(let retryAfter):
                let cooldown = retryAfter ?? 300
                self.nextAllowedFetch = Date().addingTimeInterval(cooldown)
                self.lastError = ae.errorDescription
                if case .ok(let pct) = self.menubarState {
                    self.menubarState = .stale(percent: pct)
                }
                return
            default:
                break
            }
        }
        self.lastError = error.localizedDescription
        if case .ok(let pct) = self.menubarState {
            self.menubarState = .stale(percent: pct)
        }
    }

    private func refreshAndPersist(_ creds: StoredCreds) async throws -> StoredCreds {
        let resp = try await AnthropicClient.shared.refreshTokens(refreshToken: creds.refreshToken)
        let newRefresh = resp.refresh_token ?? creds.refreshToken
        let newExpires = Date().addingTimeInterval(TimeInterval(resp.expires_in))
        try KeychainCredentials.update(
            accessToken: resp.access_token,
            refreshToken: newRefresh,
            expiresAt: newExpires,
            account: creds.account
        )
        var updated = creds
        updated.accessToken = resp.access_token
        updated.refreshToken = newRefresh
        updated.expiresAt = newExpires
        return updated
    }

    private func highestPercent(_ u: UsageResponse) -> Int {
        max(u.five_hour?.utilization ?? 0, u.seven_day?.utilization ?? 0)
    }
}
