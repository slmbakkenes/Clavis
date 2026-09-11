//  https://mczachurski.dev
//  Copyright © 2021 Marcin Czachurski and the repository contributors.
//  Licensed under the MIT License.

enum MetadataExtractorError: Error {
  case imageSourceNotCreated
  case imageMetadataNotCreated

  var message: String {
    switch self {
    case .imageSourceNotCreated: return "CGImageSource object cannot be created."
    case .imageMetadataNotCreated: return "CGImageMetadata object cannot be created."
    }
  }
}
