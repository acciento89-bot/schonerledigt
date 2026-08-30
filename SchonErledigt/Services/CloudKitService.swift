import CloudKit
import Foundation
import UIKit

actor CloudKitService {
    static let shared = CloudKitService()
    static let containerIdentifier = "iCloud.com.kamilunavo.schon-erledigt"
    private static let recordType = "Household"
    private static let snapshotKey = "snapshot"
    private static let nameKey = "name"
    private let container = CKContainer(identifier: CloudKitService.containerIdentifier)
    private let privateZoneID = CKRecordZone.ID(zoneName: "SchonErledigtHousehold", ownerName: CKCurrentUserDefaultName)

    func accountAvailable() async -> Bool { (try? await container.accountStatus()) == .available }

    func synchronize(localData: Data, householdName: String, localModifiedAt: Date) async throws -> Data {
        guard await accountAvailable() else { throw CloudError.accountUnavailable }
        if let shared = try await firstSharedHousehold() {
            return try await reconcile(database: container.sharedCloudDatabase, record: shared, localData: localData, householdName: householdName, localModifiedAt: localModifiedAt)
        }
        let record = try await ensurePrivateHousehold(named: householdName)
        return try await reconcile(database: container.privateCloudDatabase, record: record, localData: localData, householdName: householdName, localModifiedAt: localModifiedAt)
    }

    @MainActor static func sharingController(householdName: String, localData: Data) -> UICloudSharingController {
        let service = CloudKitService.shared
        let controller = UICloudSharingController { _, completion in
            Task {
                do {
                    let result = try await service.prepareShare(householdName: householdName, localData: localData)
                    completion(result.share, result.container, nil)
                } catch { completion(nil, nil, error) }
            }
        }
        controller.availablePermissions = [.allowReadWrite]
        return controller
    }

    func accept(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.acceptShareInvitations(from: [metadata]) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func ensurePrivateHousehold(named name: String) async throws -> CKRecord {
        let database = container.privateCloudDatabase
        do { _ = try await database.save(CKRecordZone(zoneID: privateZoneID)) }
        catch { /* Existing zones are safe to reuse; record operations below surface real failures. */ }
        let recordID = CKRecord.ID(recordName: "primary-household", zoneID: privateZoneID)
        if let existing = try? await database.record(for: recordID) { return existing }
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[Self.nameKey] = name as CKRecordValue
        return try await database.save(record)
    }

    private func firstSharedHousehold() async throws -> CKRecord? {
        let database = container.sharedCloudDatabase
        for zone in try await database.allRecordZones() {
            let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
            let result = try await database.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 1)
            for (_, recordResult) in result.matchResults {
                if case .success(let record) = recordResult { return record }
            }
        }
        return nil
    }

    private func reconcile(database: CKDatabase, record: CKRecord, localData: Data, householdName: String, localModifiedAt: Date) async throws -> Data {
        if (record.modificationDate ?? .distantPast) > localModifiedAt {
            if let asset = record[Self.snapshotKey] as? CKAsset, let url = asset.fileURL, let remote = try? Data(contentsOf: url) { return remote }
            if let remote = record[Self.snapshotKey] as? Data { return remote }
        }
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-snapshot-\(UUID().uuidString).json")
        try localData.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        record[Self.snapshotKey] = CKAsset(fileURL: temporaryURL)
        record[Self.nameKey] = householdName as CKRecordValue
        _ = try await database.save(record)
        return localData
    }

    private func prepareShare(householdName: String, localData: Data) async throws -> (share: CKShare, container: CKContainer) {
        let database = container.privateCloudDatabase
        let root = try await ensurePrivateHousehold(named: householdName)
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-share-\(UUID().uuidString).json")
        try localData.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        root[Self.snapshotKey] = CKAsset(fileURL: temporaryURL)
        root[Self.nameKey] = householdName as CKRecordValue
        if let reference = root.share,
           let existingRecord = try? await database.record(for: reference.recordID),
           let existing = existingRecord as? CKShare { return (existing, container) }
        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = householdName as CKRecordValue
        share.publicPermission = .none
        let operation = CKModifyRecordsOperation(recordsToSave: [root, share])
        operation.savePolicy = .changedKeys
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { continuation.resume(with: $0) }
            database.add(operation)
        }
        return (share, container)
    }
}

enum CloudError: LocalizedError {
    case accountUnavailable
    var errorDescription: String? { String(localized: "Bitte melde dich auf dem iPhone bei iCloud an.") }
}
