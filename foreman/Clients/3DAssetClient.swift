//
//  3DAssetClient.swift
//  foreman
//
//  Created by Claude on 2025/10/14.
//

import Dependencies
import Foundation
import UniformTypeIdentifiers
import OSLog

struct ThreeDAssetClient {
  var loadModel: @Sendable (URL) async throws -> ThreeDModel
  var loadBundleModel: @Sendable (String) async throws -> ThreeDModel
  var loadModelUSDZ: @Sendable (URL) async throws -> ThreeDModel
  var loadBundleModelUSDZ: @Sendable (String) async throws -> ThreeDModel
  var validateFile: @Sendable (URL) -> Bool
  var validateFileUSDZ: @Sendable (URL) -> Bool
  var getSupportedTypes: @Sendable () -> [UTType]
  var getSupportedTypesUSDZ: @Sendable () -> [UTType]
}

struct ThreeDModel: Equatable, Sendable {
  let id = UUID()
  let name: String
  let url: URL
  let fileSize: Int64
  let createdDate: Date
  
  static func == (lhs: ThreeDModel, rhs: ThreeDModel) -> Bool {
    lhs.id == rhs.id
  }
}

extension ThreeDAssetClient: DependencyKey {
  static let liveValue = ThreeDAssetClient(
    loadModel: { url in
      let logger = Logger(subsystem: "foreman", category: "3DAssetClient")

      guard url.startAccessingSecurityScopedResource() else {
        logger.error("🚫 Failed to access security scoped resource: \(url.path)")
        throw ThreeDAssetError.accessDenied
      }
      defer { url.stopAccessingSecurityScopedResource() }

      guard FileManager.default.fileExists(atPath: url.path) else {
        logger.error("📁 File does not exist: \(url.path)")
        throw ThreeDAssetError.fileNotFound
      }

      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      let fileSize = attributes[.size] as? Int64 ?? 0
      let createdDate = attributes[.creationDate] as? Date ?? Date()

      logger.info("📦 Loading 3D model (DAE): \(url.lastPathComponent) (\(fileSize) bytes)")

      return ThreeDModel(
        name: url.deletingPathExtension().lastPathComponent,
        url: url,
        fileSize: fileSize,
        createdDate: createdDate
      )
    },

    loadBundleModel: { filename in
      let logger = Logger(subsystem: "foreman", category: "3DAssetClient")

      guard let url = Bundle.main.url(forResource: filename, withExtension: "dae") else {
        logger.error("🚫 Bundle model not found: \(filename).dae")
        throw ThreeDAssetError.fileNotFound
      }

      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      let fileSize = attributes[.size] as? Int64 ?? 0
      let createdDate = attributes[.creationDate] as? Date ?? Date()

      logger.info("📦 Loading bundle 3D model (DAE): \(filename).dae")

      return ThreeDModel(
        name: filename,
        url: url,
        fileSize: fileSize,
        createdDate: createdDate
      )
    },

    loadModelUSDZ: { url in
      let logger = Logger(subsystem: "foreman", category: "3DAssetClient")

      guard url.startAccessingSecurityScopedResource() else {
        logger.error("🚫 Failed to access security scoped resource: \(url.path)")
        throw ThreeDAssetError.accessDenied
      }
      defer { url.stopAccessingSecurityScopedResource() }

      guard FileManager.default.fileExists(atPath: url.path) else {
        logger.error("📁 File does not exist: \(url.path)")
        throw ThreeDAssetError.fileNotFound
      }

      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      let fileSize = attributes[.size] as? Int64 ?? 0
      let createdDate = attributes[.creationDate] as? Date ?? Date()

      logger.info("📦 Loading 3D model (USDZ): \(url.lastPathComponent) (\(fileSize) bytes)")

      return ThreeDModel(
        name: url.deletingPathExtension().lastPathComponent,
        url: url,
        fileSize: fileSize,
        createdDate: createdDate
      )
    },

    loadBundleModelUSDZ: { filename in
      let logger = Logger(subsystem: "foreman", category: "3DAssetClient")

      guard let url = Bundle.main.url(forResource: filename, withExtension: "usdz") else {
        logger.error("🚫 Bundle model not found: \(filename).usdz")
        throw ThreeDAssetError.fileNotFound
      }

      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      let fileSize = attributes[.size] as? Int64 ?? 0
      let createdDate = attributes[.creationDate] as? Date ?? Date()

      logger.info("📦 Loading bundle 3D model (USDZ): \(filename).usdz")

      return ThreeDModel(
        name: filename,
        url: url,
        fileSize: fileSize,
        createdDate: createdDate
      )
    },

    validateFile: { url in
      let supportedExtensions = ["dae", "DAE"]
      let fileExtension = url.pathExtension
      return supportedExtensions.contains(fileExtension)
    },

    validateFileUSDZ: { url in
      let supportedExtensions = ["usdz", "USDZ"]
      let fileExtension = url.pathExtension
      return supportedExtensions.contains(fileExtension)
    },

    getSupportedTypes: {
      [UTType(filenameExtension: "dae") ?? UTType.data]
    },

    getSupportedTypesUSDZ: {
      [.usdz]
    }
  )
  
  static let testValue = ThreeDAssetClient(
    loadModel: { url in
      ThreeDModel(
        name: "TestModel",
        url: url,
        fileSize: 1024,
        createdDate: Date()
      )
    },
    loadBundleModel: { filename in
      ThreeDModel(
        name: filename,
        url: Bundle.main.bundleURL,
        fileSize: 2048,
        createdDate: Date()
      )
    },
    loadModelUSDZ: { url in
      ThreeDModel(
        name: "TestModelUSDZ",
        url: url,
        fileSize: 1024,
        createdDate: Date()
      )
    },
    loadBundleModelUSDZ: { filename in
      ThreeDModel(
        name: filename,
        url: Bundle.main.bundleURL,
        fileSize: 2048,
        createdDate: Date()
      )
    },
    validateFile: { _ in true },
    validateFileUSDZ: { _ in true },
    getSupportedTypes: { [UTType.data] },
    getSupportedTypesUSDZ: { [.usdz] }
  )
}

enum ThreeDAssetError: Error, LocalizedError, Equatable {
  case fileNotFound
  case invalidFormat
  case accessDenied
  case loadingFailed(String)
  
  var errorDescription: String? {
    switch self {
    case .fileNotFound:
      return "3D model file not found"
    case .invalidFormat:
      return "Unsupported 3D model format"
    case .accessDenied:
      return "Access to 3D model file denied"
    case .loadingFailed(let reason):
      return "Failed to load 3D model: \(reason)"
    }
  }
}

extension DependencyValues {
  var threeDAssetClient: ThreeDAssetClient {
    get { self[ThreeDAssetClient.self] }
    set { self[ThreeDAssetClient.self] = newValue }
  }
}