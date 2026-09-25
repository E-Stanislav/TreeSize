import Foundation

/// Информация о смонтированном томе (ТЗ 2.1.1)
nonisolated struct VolumeInfo: Identifiable, Hashable {
    let url: URL
    let name: String
    let totalCapacity: Int64
    let availableCapacity: Int64
    let isInternal: Bool

    var id: String { url.path }
    var usedCapacity: Int64 { totalCapacity - availableCapacity }
    var usedFraction: Double {
        totalCapacity > 0 ? Double(usedCapacity) / Double(totalCapacity) : 0
    }
}

nonisolated enum VolumeService {
    private static let keys: [URLResourceKey] = [
        .volumeNameKey, .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey, .volumeIsBrowsableKey,
        .volumeIsInternalKey, .isVolumeKey,
    ]

    /// Список browsable томов (внутренние, внешние, сетевые)
    static func mountedVolumes() -> [VolumeInfo] {
        let fm = FileManager.default
        guard let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys) else {
            return []
        }
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isVolume == true,
                  values.volumeIsBrowsable == true
            else { return nil }
            return VolumeInfo(
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                totalCapacity: Int64(values.volumeTotalCapacity ?? 0),
                availableCapacity: Int64(values.volumeAvailableCapacity ?? 0),
                isInternal: values.volumeIsInternal ?? false
            )
        }
    }
}
