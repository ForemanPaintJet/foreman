//
//  CodableParserFeature.swift
//  foreman
//
//  Created by Claude on 2025/9/3.
//

import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct CodableParserFeature<DataType: Codable & Equatable> {
  @ObservableState
  struct State: Equatable {
    var lastError: String?
  }

  @CasePathable
  enum Action: Equatable {
    case parseData(Data)
    case parseString(String)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case parsed(DataType)
      case parsingFailed(String)
    }
  }

  private let logger = Logger(subsystem: "foreman", category: "CodableParserFeature")

  var body: some ReducerOf<Self> {
    Reduce(core)
  }

  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .parseData(let data):
      return parseDataEffect(data)

    case .parseString(let string):
      guard let data = string.data(using: .utf8) else {
        logger.error("❌ CodableParserFeature: Invalid UTF-8 string")
        return .send(.delegate(.parsingFailed("Invalid UTF-8 string")))
      }
      return parseDataEffect(data)

    case .delegate:
      return .none
    }
  }

  private func parseDataEffect(_ data: Data) -> Effect<Action> {
    return .run { send in
      do {
        let decoder = JSONDecoder()

        let result = try decoder.decode(DataType.self, from: data)
        logger.info("✅ CodableParserFeature: Successfully parsed \(String(describing: DataType.self))")
        await send(.delegate(.parsed(result)))
      } catch {
        logger.error("❌ CodableParserFeature: Parsing failed: \(error)")
        await send(.delegate(.parsingFailed(error.localizedDescription)))
      }
    }
  }
}
