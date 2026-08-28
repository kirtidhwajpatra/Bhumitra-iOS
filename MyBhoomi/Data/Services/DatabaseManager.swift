import Foundation

public struct User: Codable, Identifiable {
    public let id: String // Stable User Identifier
    public var appAccountToken: String // Permanent UUID token passed to Apple StoreKit 2
    public var name: String
    public var email: String
    public var mobile: String?
    public var selectedState: String?
    public var isPremium: Bool
    public var createdAt: String?
    
    public var appAccountUUID: UUID {
        if let uuid = UUID(uuidString: appAccountToken) {
            return uuid
        }
        return UUID()
    }
}

public struct SubscriptionRecord: Codable {
    public let userId: String
    public var plan: String
    public var productID: String?
    public var status: String
    public var startDate: String
    public var expiryDate: String?
}

public struct UsageRecord: Codable {
    public let userId: String
    public var ownershipPreviewCount: Int
    public var month: String // "2026-06"
}

public final class DatabaseManager {
    public static let shared = DatabaseManager()
    private init() {
        createDirectoryIfNeeded()
    }
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var usersURL: URL { documentsDirectory.appendingPathComponent("users.json") }
    private var subscriptionsURL: URL { documentsDirectory.appendingPathComponent("subscriptions.json") }
    private var usageURL: URL { documentsDirectory.appendingPathComponent("usage.json") }
    
    private func createDirectoryIfNeeded() {
        let path = documentsDirectory.path
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - User Operations
    public func loadUsers() -> [User] {
        guard let data = try? Data(contentsOf: usersURL) else { return [] }
        return (try? JSONDecoder().decode([User].self, from: data)) ?? []
    }
    
    public func saveUsers(_ users: [User]) {
        if let data = try? JSONEncoder().encode(users) {
            try? data.write(to: usersURL)
        }
    }
    
    public func saveUser(_ user: User) {
        var users = loadUsers()
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        } else {
            users.append(user)
        }
        saveUsers(users)
    }
    
    // MARK: - Subscription Operations
    public func loadSubscriptions() -> [SubscriptionRecord] {
        guard let data = try? Data(contentsOf: subscriptionsURL) else { return [] }
        return (try? JSONDecoder().decode([SubscriptionRecord].self, from: data)) ?? []
    }
    
    public func saveSubscriptions(_ subs: [SubscriptionRecord]) {
        if let data = try? JSONEncoder().encode(subs) {
            try? data.write(to: subscriptionsURL)
        }
    }
    
    public func saveSubscription(_ sub: SubscriptionRecord) {
        var subs = loadSubscriptions()
        if let index = subs.firstIndex(where: { $0.userId == sub.userId }) {
            subs[index] = sub
        } else {
            subs.append(sub)
        }
        saveSubscriptions(subs)
        
        // Update corresponding user isPremium flag
        var users = loadUsers()
        if let index = users.firstIndex(where: { $0.id == sub.userId }) {
            users[index].isPremium = (sub.status == "active")
            saveUsers(users)
        }
    }
    
    // MARK: - Usage Operations
    public func loadUsages() -> [UsageRecord] {
        guard let data = try? Data(contentsOf: usageURL) else { return [] }
        return (try? JSONDecoder().decode([UsageRecord].self, from: data)) ?? []
    }
    
    public func saveUsages(_ usages: [UsageRecord]) {
        if let data = try? JSONEncoder().encode(usages) {
            try? data.write(to: usageURL)
        }
    }
    
    public func saveUsage(_ usage: UsageRecord) {
        var usages = loadUsages()
        if let index = usages.firstIndex(where: { $0.userId == usage.userId && $0.month == usage.month }) {
            usages[index] = usage
        } else {
            usages.append(usage)
        }
        saveUsages(usages)
    }
    
    public func getUsage(for userId: String, month: String) -> UsageRecord {
        let usages = loadUsages()
        if let existing = usages.first(where: { $0.userId == userId && $0.month == month }) {
            return existing
        }
        let newRecord = UsageRecord(userId: userId, ownershipPreviewCount: 0, month: month)
        saveUsage(newRecord)
        return newRecord
    }
    
    public func resetUsage(for userId: String, month: String) {
        var usages = loadUsages()
        if let index = usages.firstIndex(where: { $0.userId == userId && $0.month == month }) {
            usages[index].ownershipPreviewCount = 0
            saveUsages(usages)
        }
    }
    
    public func incrementUsage(for userId: String, month: String) {
        var usages = loadUsages()
        if let index = usages.firstIndex(where: { $0.userId == userId && $0.month == month }) {
            usages[index].ownershipPreviewCount += 1
        } else {
            usages.append(UsageRecord(userId: userId, ownershipPreviewCount: 1, month: month))
        }
        saveUsages(usages)
    }
}
