import CoreGraphics
import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let targetWidth = 853
private let targetHeight = 1844
private let differenceAmplification = 4
private let comparisonColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

private struct FrameSpec {
    let id: String
    let slug: String
    let scenario: String
    let referencePath: String
    let referenceSHA256: String

    var attachmentName: String { "\(id)-\(slug)-raw" }
    var outputName: String { "\(id)-\(slug).png" }
}

private let frames = [
    FrameSpec(id: "F01", slug: "welcome-ready", scenario: "welcome-ready", referencePath: "design/approved/welcome-egg-seed-nest-v1.png", referenceSHA256: "857090ea137e94368acd28911537529cdc8250f9da448ee7e71ad0e7566d0eb1"),
    FrameSpec(id: "F02", slug: "hatching", scenario: "hatching", referencePath: "design/approved/hatching-seed-nest-v1.png", referenceSHA256: "79bca47bc1e8d1d05855ed43bf1e2ebeb073828310e3e014644392813df185ee"),
    FrameSpec(id: "F03", slug: "child-comfortable", scenario: "child-comfortable", referencePath: "design/approved/habitat-home-sunny-patio-v1.png", referenceSHA256: "469387ae09cd61d36747f5aa8176c8f65745f8da5e85fbc0706c124211450d6b"),
    FrameSpec(id: "F04", slug: "child-needs-care", scenario: "child-needs-care", referencePath: "design/approved/habitat-child-needs-care-v1.png", referenceSHA256: "6f9ae20db507e8bd4770c710cb8c35053540556269965d3235095252564e208b"),
    FrameSpec(id: "F05", slug: "child-sleeping", scenario: "child-sleeping", referencePath: "design/approved/habitat-child-sleeping-v1.png", referenceSHA256: "aa84adc3401758d20c6796493fe72e7cac76c9e2c3ce40db592b1df02e7b058f"),
    FrameSpec(id: "F06", slug: "child-feed-response", scenario: "child-comfortable", referencePath: "design/approved/habitat-care-response-family-v1.png", referenceSHA256: "22330bb3188ae4b3890a6be04951e0e3d81c1df7616b0676da4f91fc46c35555"),
    FrameSpec(id: "F07", slug: "adult-evolution", scenario: "adult-evolution", referencePath: "design/approved/adult-evolution-b-v1.png", referenceSHA256: "3e55129eda195e13c06d651cab9eee03867c41c06208181215c76ab4915f7778"),
    FrameSpec(id: "F08", slug: "adult-comfortable", scenario: "adult-comfortable", referencePath: "design/approved/habitat-adult-comfortable-b-v1.png", referenceSHA256: "f91ac00be5a25a64cf1d81f197acc26bcd2130e75a2be08cc1c54b977f37b59d"),
    FrameSpec(id: "F09", slug: "adult-needs-care", scenario: "adult-needs-care", referencePath: "design/approved/habitat-adult-needs-care-b-v1.png", referenceSHA256: "d209a6e1abdaf294638211033d64439915ad288a65b6ad6683d75a5b9fbeb549"),
    FrameSpec(id: "F10", slug: "adult-sleeping", scenario: "adult-sleeping", referencePath: "design/approved/habitat-adult-sleeping-b-v1.png", referenceSHA256: "830cb1d5fcad047552cca18b3762441e079a424b7f592ba343c03744dc5ee52b"),
    FrameSpec(id: "F11", slug: "settings-main-off", scenario: "settings-off", referencePath: "design/approved/settings-main-garden-cards-v1.png", referenceSHA256: "eb7c29288295a28c5cad9bc310debf35d99099122a6845671ac3ec667c182b64"),
    FrameSpec(id: "F12", slug: "reminder-pre-permission", scenario: "settings-off", referencePath: "design/approved/reminder-pre-permission-garden-cards-v1.png", referenceSHA256: "b2eba7b326be93fd47f6db785b535a2b80c6eaa3d51f8d54baa1a22b29cf4168"),
    FrameSpec(id: "F13", slug: "reminders-enabled", scenario: "settings-on", referencePath: "design/approved/reminders-enabled-garden-cards-v1.png", referenceSHA256: "2ba477dfd4d4f2b82fa22d62ca6b8a2bd4117e00b4fd36129a80f2595a009ac6"),
    FrameSpec(id: "F14", slug: "reminders-denied", scenario: "settings-denied", referencePath: "design/approved/reminders-denied-garden-cards-v1.png", referenceSHA256: "af271873e1b6185f364d13828d7f2cd2e954fc4334c1be56514abc1d83f20c12"),
    FrameSpec(id: "F15", slug: "support-development", scenario: "settings-off", referencePath: "design/approved/support-development-info-garden-cards-v1.png", referenceSHA256: "d4669efae75d7afab12c198127982a51b66211ff44ae81787f973856157b7324"),
    FrameSpec(id: "F16", slug: "privacy", scenario: "settings-off", referencePath: "design/approved/privacy-info-garden-cards-v1.png", referenceSHA256: "ae0211c2ea1e62b64103fe9b75500adc4f6047b4ab85468c89aba490db918d92"),
    FrameSpec(id: "F17", slug: "support-unavailable", scenario: "settings-off", referencePath: "design/approved/support-unavailable-garden-cards-v1.png", referenceSHA256: "abafbe4673c1de67e33df824f5aed77ae70fba564435b0970645777dc6ad8c85"),
]

private struct Arguments {
    let attachments: URL
    let output: URL
    let repositoryRoot: URL
    let candidate: String
}

private enum ComparisonError: LocalizedError {
    case usage(String)
    case invalidInput(String)
    case image(String)

    var errorDescription: String? {
        switch self {
        case let .usage(message), let .invalidInput(message), let .image(message):
            return message
        }
    }
}

private struct PixelImage {
    let width: Int
    let height: Int
    var bytes: [UInt8]
}

private struct AttachmentManifestEntry: Decodable {
    let exportedFileName: String
    let suggestedHumanReadableName: String
}

private struct AttachmentManifestGroup: Decodable {
    let attachments: [AttachmentManifestEntry]
}

private struct NamedAttachment {
    let url: URL
    let searchableName: String
}

private struct CropRecord: Codable {
    let sourceWidth: Int
    let sourceHeight: Int
    let uniformScale: Double
    let scaledWidth: Double
    let scaledHeight: Double
    let cropOffsetX: Double
    let cropOffsetY: Double
    let outputWidth: Int
    let outputHeight: Int
}

private struct DifferenceBounds: Codable {
    let xFromRowStart: Int
    let rowFromBufferStart: Int
    let width: Int
    let height: Int
}

private struct FrameMetrics: Codable {
    let frame: String
    let status: String
    let candidateCommit: String
    let scenario: String
    let rawPath: String
    let rawSHA256: String
    let referencePath: String
    let referenceSHA256: String
    let normalization: CropRecord
    let differentPixels: Int
    let differentPixelPercentage: Double
    let meanAbsoluteErrorRGB: Double
    let rootMeanSquareErrorRGB: Double
    let maximumChannelDelta: Int
    let percentile95ChannelDelta: Int
    let differenceBounds: DifferenceBounds?
}

private struct RunSummary: Codable {
    let toolVersion: String
    let candidateCommit: String
    let targetWidth: Int
    let targetHeight: Int
    let normalization: String
    let interpolation: String
    let colorSpace: String
    let alphaPolicy: String
    let overlayFormula: String
    let differenceFormula: String
    let differenceBoundsCoordinates: String
    let frames: [FrameMetrics]
}

private func parseArguments() throws -> Arguments {
    var values: [String: String] = [:]
    var index = 1
    let raw = CommandLine.arguments
    while index < raw.count {
        let key = raw[index]
        guard key.hasPrefix("--"), index + 1 < raw.count else {
            throw ComparisonError.usage("Every option requires a value: \(key)")
        }
        values[key] = raw[index + 1]
        index += 2
    }

    guard let attachments = values["--attachments"],
          let output = values["--output"],
          let repositoryRoot = values["--repository-root"],
          let candidate = values["--candidate"],
          !candidate.isEmpty else {
        throw ComparisonError.usage(
            "Usage: compare-visual-captures.swift --attachments <path> " +
            "--output <path> --repository-root <path> --candidate <commit>"
        )
    }

    return Arguments(
        attachments: URL(fileURLWithPath: attachments).standardizedFileURL,
        output: URL(fileURLWithPath: output).standardizedFileURL,
        repositoryRoot: URL(fileURLWithPath: repositoryRoot).standardizedFileURL,
        candidate: candidate
    )
}

private func regularFiles(below root: URL) throws -> [URL] {
    let manager = FileManager.default
    guard manager.fileExists(atPath: root.path) else {
        throw ComparisonError.invalidInput("Attachment directory is missing: \(root.path)")
    }
    guard let enumerator = manager.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw ComparisonError.invalidInput("Cannot enumerate attachments: \(root.path)")
    }

    var files: [URL] = []
    for case let url as URL in enumerator {
        if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            files.append(url)
        }
    }
    return files.sorted { $0.path < $1.path }
}

private func namedAttachments(below root: URL) throws -> [NamedAttachment] {
    let manager = FileManager.default
    let manifest = root.appendingPathComponent("manifest.json")
    guard manager.fileExists(atPath: manifest.path) else {
        return try regularFiles(below: root).map {
            NamedAttachment(url: $0, searchableName: $0.lastPathComponent)
        }
    }

    let groups: [AttachmentManifestGroup]
    do {
        groups = try JSONDecoder().decode(
            [AttachmentManifestGroup].self,
            from: Data(contentsOf: manifest)
        )
    } catch {
        throw ComparisonError.invalidInput(
            "Cannot decode Xcode attachment manifest: \(error.localizedDescription)"
        )
    }

    let entries = groups.flatMap(\.attachments)
    let exportedNames = entries.map(\.exportedFileName)
    guard Set(exportedNames).count == exportedNames.count else {
        throw ComparisonError.invalidInput(
            "Attachment manifest contains duplicate exported file names"
        )
    }

    return try entries.map { entry in
        guard !entry.exportedFileName.isEmpty,
              !entry.suggestedHumanReadableName.isEmpty else {
            throw ComparisonError.invalidInput(
                "Attachment manifest contains an empty file or suggested name"
            )
        }
        guard URL(fileURLWithPath: entry.exportedFileName).lastPathComponent ==
                entry.exportedFileName else {
            throw ComparisonError.invalidInput(
                "Attachment manifest contains an unsafe exported file name"
            )
        }
        let url = root.appendingPathComponent(entry.exportedFileName)
        guard manager.fileExists(atPath: url.path),
              try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw ComparisonError.invalidInput(
                "Attachment manifest references a missing file: \(entry.exportedFileName)"
            )
        }
        return NamedAttachment(
            url: url,
            searchableName: entry.suggestedHumanReadableName
        )
    }
}

private func uniqueNamedFile(
    containing token: String,
    extensions: Set<String>,
    among files: [NamedAttachment]
) throws -> URL {
    let loweredToken = token.lowercased()
    let matches = files.filter {
        extensions.contains($0.url.pathExtension.lowercased()) &&
        $0.searchableName.lowercased().contains(loweredToken)
    }
    guard matches.count == 1, let match = matches.first else {
        let paths = matches.map(\.url.path).joined(separator: "\n  ")
        throw ComparisonError.invalidInput(
            "Expected exactly one exported attachment containing '\(token)', " +
            "found \(matches.count).\(paths.isEmpty ? "" : "\n  \(paths)")"
        )
    }
    return match.url
}

private func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func loadCGImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw ComparisonError.image("Cannot decode PNG: \(url.path)")
    }
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
        as? [CFString: Any]
    let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?
        .intValue ?? 1
    guard orientation == 1 else {
        throw ComparisonError.image(
            "PNG orientation must be baked upright (1), found \(orientation): \(url.path)"
        )
    }
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ComparisonError.image("Cannot decode PNG pixels: \(url.path)")
    }
    return image
}

private func renderAspectFill(_ image: CGImage) throws -> (PixelImage, CropRecord) {
    let sourceWidth = image.width
    let sourceHeight = image.height
    guard sourceWidth > 0, sourceHeight > 0 else {
        throw ComparisonError.image("Image has invalid dimensions")
    }

    let scale = max(
        Double(targetWidth) / Double(sourceWidth),
        Double(targetHeight) / Double(sourceHeight)
    )
    let scaledWidth = Double(sourceWidth) * scale
    let scaledHeight = Double(sourceHeight) * scale
    let offsetX = (Double(targetWidth) - scaledWidth) / 2
    let offsetY = (Double(targetHeight) - scaledHeight) / 2
    var pixels = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)

    try pixels.withUnsafeMutableBytes { buffer in
        guard let base = buffer.baseAddress,
              let context = CGContext(
                  data: base,
                  width: targetWidth,
                  height: targetHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: targetWidth * 4,
                  space: comparisonColorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                      CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            throw ComparisonError.image("Cannot create the normalization context")
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        )
    }

    return (
        PixelImage(width: targetWidth, height: targetHeight, bytes: pixels),
        CropRecord(
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            uniformScale: scale,
            scaledWidth: scaledWidth,
            scaledHeight: scaledHeight,
            cropOffsetX: -offsetX,
            cropOffsetY: -offsetY,
            outputWidth: targetWidth,
            outputHeight: targetHeight
        )
    )
}

private func writePNG(_ image: PixelImage, to url: URL) throws {
    let data = Data(image.bytes)
    guard let provider = CGDataProvider(data: data as CFData),
          let cgImage = CGImage(
              width: image.width,
              height: image.height,
              bitsPerComponent: 8,
              bitsPerPixel: 32,
              bytesPerRow: image.width * 4,
              space: comparisonColorSpace,
              bitmapInfo: CGBitmapInfo(
                  rawValue: CGImageAlphaInfo.premultipliedLast.rawValue |
                      CGBitmapInfo.byteOrder32Big.rawValue
              ),
              provider: provider,
              decode: nil,
              shouldInterpolate: false,
              intent: .defaultIntent
          ),
          let destination = CGImageDestinationCreateWithURL(
              url as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          ) else {
        throw ComparisonError.image("Cannot encode PNG: \(url.path)")
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ComparisonError.image("Cannot finalize PNG: \(url.path)")
    }
}

private func overlay(reference: PixelImage, candidate: PixelImage) -> PixelImage {
    var result = reference
    for index in stride(from: 0, to: result.bytes.count, by: 4) {
        for channel in 0..<3 {
            result.bytes[index + channel] = UInt8(
                (Int(reference.bytes[index + channel]) +
                    Int(candidate.bytes[index + channel])) / 2
            )
        }
        result.bytes[index + 3] = 255
    }
    return result
}

private func compare(
    reference: PixelImage,
    candidate: PixelImage
) -> (
    diff: PixelImage,
    differentPixels: Int,
    mae: Double,
    rmse: Double,
    maxDelta: Int,
    percentile95: Int,
    bounds: DifferenceBounds?
) {
    var result = reference
    var differentPixels = 0
    var absoluteSum: UInt64 = 0
    var squaredSum: UInt64 = 0
    var maximumDelta = 0
    var histogram = [Int](repeating: 0, count: 256)
    var minimumX = targetWidth
    var minimumY = targetHeight
    var maximumX = -1
    var maximumY = -1

    for pixel in 0..<(targetWidth * targetHeight) {
        let offset = pixel * 4
        var pixelChanged = false
        for channel in 0..<3 {
            let delta = abs(
                Int(reference.bytes[offset + channel]) -
                    Int(candidate.bytes[offset + channel])
            )
            absoluteSum += UInt64(delta)
            squaredSum += UInt64(delta * delta)
            maximumDelta = max(maximumDelta, delta)
            histogram[delta] += 1
            result.bytes[offset + channel] = UInt8(delta)
            pixelChanged = pixelChanged || delta > 0
        }
        result.bytes[offset + 3] = 255

        if pixelChanged {
            differentPixels += 1
            let x = pixel % targetWidth
            let y = pixel / targetWidth
            minimumX = min(minimumX, x)
            minimumY = min(minimumY, y)
            maximumX = max(maximumX, x)
            maximumY = max(maximumY, y)
        }
    }

    let channelCount = Double(targetWidth * targetHeight * 3)
    let mae = Double(absoluteSum) / channelCount
    let rmse = sqrt(Double(squaredSum) / channelCount)
    let percentileTarget = Int(ceil(channelCount * 0.95))
    var cumulative = 0
    var percentile95 = 0
    for delta in 0..<histogram.count {
        cumulative += histogram[delta]
        if cumulative >= percentileTarget {
            percentile95 = delta
            break
        }
    }
    let bounds: DifferenceBounds? = differentPixels == 0 ? nil : DifferenceBounds(
        xFromRowStart: minimumX,
        rowFromBufferStart: minimumY,
        width: maximumX - minimumX + 1,
        height: maximumY - minimumY + 1
    )

    return (
        result,
        differentPixels,
        mae,
        rmse,
        maximumDelta,
        percentile95,
        bounds
    )
}

private func amplifiedHeatmap(from difference: PixelImage) -> PixelImage {
    var result = difference
    for index in stride(from: 0, to: result.bytes.count, by: 4) {
        for channel in 0..<3 {
            result.bytes[index + channel] = UInt8(
                min(255, Int(difference.bytes[index + channel]) *
                    differenceAmplification)
            )
        }
        result.bytes[index + 3] = 255
    }
    return result
}

private func metadataValues(from url: URL) throws -> [String: String] {
    let content = try String(contentsOf: url, encoding: .utf8)
    var result: [String: String] = [:]
    for line in content.split(whereSeparator: \.isNewline) {
        guard let separator = line.firstIndex(of: "=") else { continue }
        result[String(line[..<separator])] = String(line[line.index(after: separator)...])
    }
    return result
}

private func requireMetadata(
    _ metadata: [String: String],
    frame: FrameSpec,
    candidate: String
) throws {
    let expected: [String: String] = [
        "frame": frame.attachmentName,
        "scenario": frame.scenario,
        "candidateCommit": candidate,
        "orientation": "portrait",
        "language": "en",
        "locale": "en_US",
        "appearance": "light",
        "visualStatic": "true",
        "fixtureClock": "2025-01-01T00:00:00Z",
    ]
    for (key, value) in expected where metadata[key] != value {
        throw ComparisonError.invalidInput(
            "\(frame.id) metadata mismatch for \(key): expected '\(value)', " +
            "found '\(metadata[key] ?? "missing")'"
        )
    }
    guard let arguments = metadata["launchArguments"],
          arguments.contains("--visual-state \(frame.scenario)"),
          arguments.contains("--visual-static") else {
        throw ComparisonError.invalidInput(
            "\(frame.id) does not record the required deterministic launch arguments"
        )
    }
    for key in ["device", "udid", "runtime", "nativePixels", "pngBytes"] {
        guard let value = metadata[key], !value.isEmpty, value != "unknown" else {
            throw ComparisonError.invalidInput("\(frame.id) metadata is missing \(key)")
        }
    }
}

private func prepareDirectories(_ root: URL) throws -> [String: URL] {
    let manager = FileManager.default
    let names = [
        "raw", "metadata", "normalized", "overlays", "diffs", "heatmaps",
        "metrics",
    ]
    var result: [String: URL] = [:]
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    for name in names {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        result[name] = url
    }
    return result
}

private func relativePath(_ url: URL, from root: URL) -> String {
    let rootPath = root.standardizedFileURL.path
    let path = url.standardizedFileURL.path
    guard path.hasPrefix(rootPath + "/") else { return path }
    return String(path.dropFirst(rootPath.count + 1))
}

private func run() throws {
    let arguments = try parseArguments()
    let manager = FileManager.default
    let files = try namedAttachments(below: arguments.attachments)
    let outputFolders = try prepareDirectories(arguments.output)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var allMetrics: [FrameMetrics] = []
    var sharedDevice: String?
    var sharedUDID: String?
    var sharedRuntime: String?

    for frame in frames {
        let screenshot = try uniqueNamedFile(
            containing: frame.attachmentName,
            extensions: ["png"],
            among: files
        )
        let metadataFile = try uniqueNamedFile(
            containing: "\(frame.attachmentName)-metadata",
            extensions: ["txt", "text", "log", ""],
            among: files
        )
        let metadata = try metadataValues(from: metadataFile)
        try requireMetadata(metadata, frame: frame, candidate: arguments.candidate)

        let rawImage = try loadCGImage(screenshot)
        let recordedPixels = "\(rawImage.width)x\(rawImage.height)"
        guard metadata["nativePixels"] == recordedPixels else {
            throw ComparisonError.invalidInput(
                "\(frame.id) metadata pixels \(metadata["nativePixels"] ?? "missing") " +
                "do not match PNG pixels \(recordedPixels)"
            )
        }
        let actualByteCount = try screenshot.resourceValues(forKeys: [.fileSizeKey])
            .fileSize ?? -1
        guard metadata["pngBytes"] == String(actualByteCount) else {
            throw ComparisonError.invalidInput(
                "\(frame.id) metadata byte count \(metadata["pngBytes"] ?? "missing") " +
                "does not match PNG bytes \(actualByteCount)"
            )
        }

        if let known = sharedDevice, known != metadata["device"] {
            throw ComparisonError.invalidInput("F01-F17 must use one simulator device")
        }
        if let known = sharedUDID, known != metadata["udid"] {
            throw ComparisonError.invalidInput("F01-F17 must use one simulator UDID")
        }
        if let known = sharedRuntime, known != metadata["runtime"] {
            throw ComparisonError.invalidInput("F01-F17 must use one iOS runtime")
        }
        sharedDevice = metadata["device"]
        sharedUDID = metadata["udid"]
        sharedRuntime = metadata["runtime"]

        let reference = arguments.repositoryRoot.appendingPathComponent(frame.referencePath)
        guard manager.fileExists(atPath: reference.path) else {
            throw ComparisonError.invalidInput("Missing approved reference: \(frame.referencePath)")
        }
        let actualReferenceHash = try sha256(of: reference)
        guard actualReferenceHash == frame.referenceSHA256 else {
            throw ComparisonError.invalidInput(
                "Approved reference hash mismatch for \(frame.id): \(actualReferenceHash)"
            )
        }
        let referenceImage = try loadCGImage(reference)
        guard referenceImage.width == targetWidth,
              referenceImage.height == targetHeight else {
            throw ComparisonError.invalidInput(
                "Approved reference \(frame.id) must be \(targetWidth)x\(targetHeight), " +
                "found \(referenceImage.width)x\(referenceImage.height)"
            )
        }

        let rawDestination = outputFolders["raw"]!.appendingPathComponent(frame.outputName)
        let metadataDestination = outputFolders["metadata"]!
            .appendingPathComponent("\(frame.id)-\(frame.slug).txt")
        try manager.copyItem(at: screenshot, to: rawDestination)
        try manager.copyItem(at: metadataFile, to: metadataDestination)

        let rawHash = try sha256(of: screenshot)
        let (normalized, normalization) = try renderAspectFill(rawImage)
        let (referencePixels, _) = try renderAspectFill(referenceImage)
        let overlayImage = overlay(reference: referencePixels, candidate: normalized)
        let result = compare(reference: referencePixels, candidate: normalized)
        let status = result.differentPixels == 0 ? "PIXEL_IDENTICAL" : "REVIEW_REQUIRED"

        try writePNG(
            normalized,
            to: outputFolders["normalized"]!.appendingPathComponent(frame.outputName)
        )
        try writePNG(
            overlayImage,
            to: outputFolders["overlays"]!.appendingPathComponent(frame.outputName)
        )
        try writePNG(
            result.diff,
            to: outputFolders["diffs"]!.appendingPathComponent(frame.outputName)
        )
        try writePNG(
            amplifiedHeatmap(from: result.diff),
            to: outputFolders["heatmaps"]!.appendingPathComponent(frame.outputName)
        )

        let metrics = FrameMetrics(
            frame: frame.id,
            status: status,
            candidateCommit: arguments.candidate,
            scenario: frame.scenario,
            rawPath: relativePath(rawDestination, from: arguments.output),
            rawSHA256: rawHash,
            referencePath: frame.referencePath,
            referenceSHA256: actualReferenceHash,
            normalization: normalization,
            differentPixels: result.differentPixels,
            differentPixelPercentage: Double(result.differentPixels) /
                Double(targetWidth * targetHeight) * 100,
            meanAbsoluteErrorRGB: result.mae,
            rootMeanSquareErrorRGB: result.rmse,
            maximumChannelDelta: result.maxDelta,
            percentile95ChannelDelta: result.percentile95,
            differenceBounds: result.bounds
        )
        allMetrics.append(metrics)
        try encoder.encode(metrics).write(
            to: outputFolders["metrics"]!.appendingPathComponent("\(frame.id).json")
        )
        print("\(frame.id): \(status), different pixels \(result.differentPixels)")
    }

    let summary = RunSummary(
        toolVersion: "PocketPetVisualCompare/1",
        candidateCommit: arguments.candidate,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        normalization: "uniform aspect-fill scale, centered crop; no stretch or registration",
        interpolation: "CoreGraphics high quality",
        colorSpace: "sRGB IEC 61966-2-1, 8-bit premultiplied RGBA",
        alphaPolicy: "reference and candidate composited over opaque sRGB white",
        overlayFormula: "floor((reference RGB + candidate RGB) / 2)",
        differenceFormula: "exact absolute per-channel RGB; separate 4x heatmap; zero tolerance",
        differenceBoundsCoordinates: "x and row counted from the first RGBA buffer byte",
        frames: allMetrics
    )
    try encoder.encode(summary).write(to: arguments.output.appendingPathComponent("metrics.json"))

    let runDocument = """
    # Pocket Pet visual comparison run

    - Candidate commit: `\(arguments.candidate)`
    - Device: `\(sharedDevice ?? "missing")`
    - Simulator UDID: `\(sharedUDID ?? "missing")`
    - iOS runtime: `\(sharedRuntime ?? "missing")`
    - Frames: F01-F17 (17/17)
    - Target: \(targetWidth) × \(targetHeight), English, light, portrait
    - Normalization: one uniform aspect-fill scale and centered crop per raw image
    - Interpolation: CoreGraphics high quality
    - Color space: sRGB IEC 61966-2-1, 8-bit premultiplied RGBA
    - Alpha: reference and candidate composited over opaque sRGB white
    - Overlay: floor((reference RGB + candidate RGB) / 2)
    - Difference: exact RGB absolute delta plus a separate heatmap amplified \(differenceAmplification)×
    - Difference bounds: x and row counted from the first RGBA buffer byte

    `PIXEL_IDENTICAL` closes only the still-image comparison for that frame.
    Every nonzero delta is `REVIEW_REQUIRED`; no tolerance, mask, automatic
    registration or metric can approve a visible difference. Motion,
    interaction, persistence and accessibility remain separate gates.
    """
    try runDocument.write(
        to: arguments.output.appendingPathComponent("run.md"),
        atomically: true,
        encoding: .utf8
    )

    var differences = """
    # Pocket Pet visual differences

    Candidate: `\(arguments.candidate)`

    Every frame starts open until a human reviews its normalized image, 50%
    overlay and absolute diff. Record the region, observed difference, action,
    authority and date. Do not accept differences automatically from metrics.

    | Frame | Machine status | Human status | Difference/action | Authority/date |
    |---|---|---|---|---|
    """
    for metrics in allMetrics {
        differences += "\n| \(metrics.frame) | \(metrics.status) | OPEN | — | — |"
    }
    differences += "\n"
    try differences.write(
        to: arguments.output.appendingPathComponent("differences.md"),
        atomically: true,
        encoding: .utf8
    )
}

do {
    try run()
} catch {
    fputs("Visual comparison failed: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}
