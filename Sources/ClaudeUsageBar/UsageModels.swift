import Foundation

struct UsageResponse: Decodable {
    let five_hour: Bucket?
    let seven_day: Bucket?
    let seven_day_sonnet: Bucket?
    let seven_day_opus: Bucket?
}

struct Bucket: Decodable {
    let utilization: Int?
    let resets_at: Date?
}

struct ProfileResponse: Decodable {
    let subscription_type: String?
    let plan: String?
    let tier: String?

    var displayTier: String? {
        subscription_type ?? plan ?? tier
    }
}

struct TokenRefreshResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

extension JSONDecoder {
    static let flexible: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = f1.date(from: s) { return d }
                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                if let d = f2.date(from: s) { return d }
                if let n = Double(s) {
                    return decodeEpoch(n)
                }
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unrecognized date string: \(s)")
            }
            if let n = try? c.decode(Double.self) {
                return decodeEpoch(n)
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Date must be string or number")
        }
        return d
    }()

    private static func decodeEpoch(_ n: Double) -> Date {
        n > 10_000_000_000 ? Date(timeIntervalSince1970: n / 1000) : Date(timeIntervalSince1970: n)
    }
}
