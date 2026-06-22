import Foundation
import SnapshotTesting

enum SnapshotRecord {
    static var mode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil
            ? .all : .missing
    }
}
