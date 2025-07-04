//
//  SocketClient.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/3.
//

import Combine
import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - Socket Models

struct SocketMessage: Codable, Equatable {
    let type: String
    let data: [String: String]?
}

struct RoomInfo: Codable, Equatable {
    let roomId: String
    let userCount: Int
    let users: [String]
}

struct WebRTCOffer: Codable, Equatable {
    let sdp: String
    let type: String
    let from: String
    let to: String
}

struct WebRTCAnswer: Codable, Equatable {
    let sdp: String
    let type: String
    let from: String
    let to: String
}

struct ICECandidate: Codable, Equatable {
    let candidate: String
    let sdpMLineIndex: Int
    let sdpMid: String?
    let from: String
    let to: String
}

enum ConnectionStatus: String, CaseIterable, Equatable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case error = "Error"
}

// MARK: - Socket Client

@MainActor
class SocketClient: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    @Published var currentRoom: String?
    @Published var connectedUsers: [String] = []

    private var urlSessionWebSocketTask: URLSessionWebSocketTask?
    private var currentUserId: String?

    // Publishers for different message types
    let messageSubject = PassthroughSubject<SocketMessage, Never>()
    let offerSubject = PassthroughSubject<WebRTCOffer, Never>()
    let answerSubject = PassthroughSubject<WebRTCAnswer, Never>()
    let iceCandidateSubject = PassthroughSubject<ICECandidate, Never>()
    let roomUpdateSubject = PassthroughSubject<RoomInfo, Never>()

    func connect(to url: URL) async {
        guard urlSessionWebSocketTask == nil else {
            print("🔌 SocketClient: Already connected or connecting")
            return
        }

        print("🔌 SocketClient: Starting connection to \(url)")
        connectionStatus = .connecting
        lastError = nil

        // Convert HTTP URL to WebSocket URL
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = url.scheme == "https" ? "wss" : "ws"

        guard let socketURL = components?.url else {
            print("❌ SocketClient: Invalid URL - \(url)")
            connectionStatus = .error
            lastError = "Invalid URL"
            return
        }

        print("🔗 SocketClient: Connecting to WebSocket URL: \(socketURL)")
        let session = URLSession(configuration: .default)
        urlSessionWebSocketTask = session.webSocketTask(with: socketURL)

        urlSessionWebSocketTask?.resume()
        connectionStatus = .connected
        print("✅ SocketClient: Connection established successfully")

        // Start listening for messages
        await listenForMessages()
    }

    func disconnect() async {
        print("🔌 SocketClient: Disconnecting from socket")
        urlSessionWebSocketTask?.cancel()
        urlSessionWebSocketTask = nil
        connectionStatus = .disconnected
        currentUserId = nil
        currentRoom = nil
        connectedUsers = []
        print("✅ SocketClient: Successfully disconnected")
    }

    func send(event: String, data: [String: Any]?) async throws {
        guard let task = urlSessionWebSocketTask else {
            print("❌ SocketClient: Cannot send '\(event)' - not connected")
            throw SocketError.notConnected
        }

        print("📤 SocketClient: Sending event '\(event)' with data: \(data ?? [:])")

        // Format as flat WebSocket JSON message: {"type": "event", "room": "...", "user_id": "..."}
        var webSocketMessage: [String: Any] = ["type": event]

        // Merge the data directly into the message (no nested "data" field)
        if let data = data {
            for (key, value) in data {
                webSocketMessage[key] = value
            }
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: webSocketMessage, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            print("📤 SocketClient: Sending WebSocket message: \(jsonString)")
            try await task.send(.string(jsonString))
            print("✅ SocketClient: Successfully sent event '\(event)'")
        } catch {
            print("❌ SocketClient: Failed to serialize JSON for event '\(event)': \(error)")
            throw error
        }
    }

    func joinRoom(roomId: String, userId: String) async throws {
        print("🏠 SocketClient: Joining room '\(roomId)' as user '\(userId)'")
        currentRoom = roomId
        currentUserId = userId
        try await send(event: "join_room", data: ["room": roomId, "user_id": userId])
        print("✅ SocketClient: Successfully sent join room request")
    }

    func leaveRoom(roomId: String) async throws {
        print("🏠 SocketClient: Leaving room '\(roomId)'")
        try await send(event: "leave_room", data: ["room": roomId])
        currentRoom = nil
        connectedUsers = []
        print("✅ SocketClient: Successfully left room")
    }

    func sendOffer(_ offer: WebRTCOffer) async throws {
        print("📞 SocketClient: Sending WebRTC offer to '\(offer.to)'")
        let data: [String: Any] = [
            "room": currentRoom ?? "",
            "sdp": offer.sdp,
            "type": offer.type,
            "to": offer.to,
        ]
        try await send(event: "offer", data: data)
        print("✅ SocketClient: Successfully sent offer")
    }

    func sendAnswer(_ answer: WebRTCAnswer) async throws {
        print("📞 SocketClient: Sending WebRTC answer to '\(answer.to)'")
        let data: [String: Any] = [
            "room": currentRoom ?? "",
            "sdp": answer.sdp,
            "type": answer.type,
            "to": answer.to,
        ]
        try await send(event: "answer", data: data)
        print("✅ SocketClient: Successfully sent answer")
    }

    func sendICECandidate(_ candidate: ICECandidate) async throws {
        print("🧊 SocketClient: Sending ICE candidate to '\(candidate.to)'")
        let data: [String: Any] = [
            "room": currentRoom ?? "",
            "candidate": candidate.candidate,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid ?? "",
            "to": candidate.to,
        ]
        try await send(event: "ice_candidate", data: data)
        print("✅ SocketClient: Successfully sent ICE candidate")
    }

    private func listenForMessages() async {
        guard let task = urlSessionWebSocketTask else { return }

        do {
            while task.state == .running {
                let message = try await task.receive()
                await handleMessage(message)
            }
        } catch {
            print("❌ SocketClient: Connection error - \(error.localizedDescription)")
            connectionStatus = .error
            lastError = error.localizedDescription
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await parseWebSocketMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                await parseWebSocketMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func parseWebSocketMessage(_ text: String) async {
        // Parse WebSocket JSON message format
        guard let data = text.data(using: .utf8) else {
            print("❌ SocketClient: Failed to convert message to data")
            return
        }

        do {
            if let messageObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let event = messageObject["type"] as? String
            {
                print("📨 SocketClient: Parsed WebSocket message - event: '\(event)'")

                // Remove the "type" field and pass the rest as event data
                var eventData = messageObject
                eventData.removeValue(forKey: "type")

                await handleSocketEvent(event: event, data: eventData)
            } else {
                print("❌ SocketClient: Invalid WebSocket message format: \(text)")
            }
        } catch {
            print("❌ SocketClient: Failed to parse WebSocket message - \(error)")
        }
    }

    private func handleSocketEvent(event: String, data: [String: Any]) async {
        print("📨 SocketClient: Received socket event '\(event)'")

        let stringData = data.compactMapValues { value in
            if let string = value as? String {
                return string
            } else if let number = value as? NSNumber {
                return number.stringValue
            } else {
                return String(describing: value)
            }
        }

        let socketMessage = SocketMessage(type: event, data: stringData)
        messageSubject.send(socketMessage)

        switch event {
        case "offer":
            if let sdp = data["sdp"] as? String,
                let type = data["type"] as? String,
                let from = data["from"] as? String,
                let to = data["to"] as? String
            {
                print("📞 SocketClient: Received WebRTC offer from '\(from)' to '\(to)'")
                let offer = WebRTCOffer(sdp: sdp, type: type, from: from, to: to)
                offerSubject.send(offer)
            }

        case "answer":
            if let sdp = data["sdp"] as? String,
                let type = data["type"] as? String,
                let from = data["from"] as? String,
                let to = data["to"] as? String
            {
                print("📞 SocketClient: Received WebRTC answer from '\(from)' to '\(to)'")
                let answer = WebRTCAnswer(sdp: sdp, type: type, from: from, to: to)
                answerSubject.send(answer)
            }

        case "ice_candidate":
            if let candidate = data["candidate"] as? String,
                let sdpMLineIndex = data["sdpMLineIndex"] as? Int,
                let from = data["from"] as? String,
                let to = data["to"] as? String
            {
                print("🧊 SocketClient: Received ICE candidate from '\(from)' to '\(to)'")
                let iceCandidate = ICECandidate(
                    candidate: candidate,
                    sdpMLineIndex: sdpMLineIndex,
                    sdpMid: data["sdpMid"] as? String,
                    from: from,
                    to: to
                )
                iceCandidateSubject.send(iceCandidate)
            }

        case "room_update", "user_joined", "user_left":
            if let roomId = data["room"] as? String,
                let userCount = data["user_count"] as? Int,
                let users = data["users"] as? [String]
            {
                print("🏠 SocketClient: Room update for '\(roomId)' - \(userCount) users: \(users)")
                let roomInfo = RoomInfo(roomId: roomId, userCount: userCount, users: users)
                connectedUsers = users
                roomUpdateSubject.send(roomInfo)
            }

        default:
            print("❓ SocketClient: Unhandled socket event: '\(event)'")
        }
    }
}

// MARK: - TCA Dependency

struct SocketClientDependency {
    var connect: @Sendable (URL) async throws -> Void
    var disconnect: @Sendable () async throws -> Void
    var joinRoom: @Sendable (String, String) async throws -> Void
    var leaveRoom: @Sendable (String) async throws -> Void
    var sendOffer: @Sendable (WebRTCOffer) async throws -> Void
    var sendAnswer: @Sendable (WebRTCAnswer) async throws -> Void
    var sendIceCandidate: @Sendable (ICECandidate) async throws -> Void
    var connectionStatusStream: @Sendable () -> AsyncStream<ConnectionStatus>
    var messageStream: @Sendable () -> AsyncStream<SocketMessage>
    var offerStream: @Sendable () -> AsyncStream<WebRTCOffer>
    var answerStream: @Sendable () -> AsyncStream<WebRTCAnswer>
    var iceCandidateStream: @Sendable () -> AsyncStream<ICECandidate>
    var roomUpdateStream: @Sendable () -> AsyncStream<RoomInfo>
}

extension SocketClientDependency: DependencyKey {
    static let liveValue = SocketClientDependency(
        connect: { url in
            await SocketClientLive.shared.connect(to: url)
        },
        disconnect: {
            await SocketClientLive.shared.disconnect()
        },
        joinRoom: { roomId, userId in
            try await SocketClientLive.shared.joinRoom(roomId: roomId, userId: userId)
        },
        leaveRoom: { roomId in
            try await SocketClientLive.shared.leaveRoom(roomId: roomId)
        },
        sendOffer: { offer in
            try await SocketClientLive.shared.sendOffer(offer)
        },
        sendAnswer: { answer in
            try await SocketClientLive.shared.sendAnswer(answer)
        },
        sendIceCandidate: { candidate in
            try await SocketClientLive.shared.sendICECandidate(candidate)
        },
        connectionStatusStream: {
            SocketClientLive.shared.connectionStatusStream
        },
        messageStream: {
            SocketClientLive.shared.messageStream
        },
        offerStream: {
            SocketClientLive.shared.offerStream
        },
        answerStream: {
            SocketClientLive.shared.answerStream
        },
        iceCandidateStream: {
            SocketClientLive.shared.iceCandidateStream
        },
        roomUpdateStream: {
            SocketClientLive.shared.roomUpdateStream
        }
    )
}

extension DependencyValues {
    var socketClient: SocketClientDependency {
        get { self[SocketClientDependency.self] }
        set { self[SocketClientDependency.self] = newValue }
    }
}

// MARK: - Live Implementation for TCA

@MainActor
private class SocketClientLive {
    static let shared = SocketClientLive()

    private let socketClient = SocketClient()

    // Async streams for TCA
    let connectionStatusStream: AsyncStream<ConnectionStatus>
    let messageStream: AsyncStream<SocketMessage>
    let offerStream: AsyncStream<WebRTCOffer>
    let answerStream: AsyncStream<WebRTCAnswer>
    let iceCandidateStream: AsyncStream<ICECandidate>
    let roomUpdateStream: AsyncStream<RoomInfo>

    private let connectionStatusContinuation: AsyncStream<ConnectionStatus>.Continuation
    private let messageContinuation: AsyncStream<SocketMessage>.Continuation
    private let offerContinuation: AsyncStream<WebRTCOffer>.Continuation
    private let answerContinuation: AsyncStream<WebRTCAnswer>.Continuation
    private let iceCandidateContinuation: AsyncStream<ICECandidate>.Continuation
    private let roomUpdateContinuation: AsyncStream<RoomInfo>.Continuation

    private var cancellables = Set<AnyCancellable>()

    init() {
        let (connectionStream, connectionCont) = AsyncStream.makeStream(of: ConnectionStatus.self)
        let (messageStream, messageCont) = AsyncStream.makeStream(of: SocketMessage.self)
        let (offerStream, offerCont) = AsyncStream.makeStream(of: WebRTCOffer.self)
        let (answerStream, answerCont) = AsyncStream.makeStream(of: WebRTCAnswer.self)
        let (iceCandidateStream, iceCandidateCont) = AsyncStream.makeStream(of: ICECandidate.self)
        let (roomUpdateStream, roomUpdateCont) = AsyncStream.makeStream(of: RoomInfo.self)

        self.connectionStatusStream = connectionStream
        self.messageStream = messageStream
        self.offerStream = offerStream
        self.answerStream = answerStream
        self.iceCandidateStream = iceCandidateStream
        self.roomUpdateStream = roomUpdateStream

        self.connectionStatusContinuation = connectionCont
        self.messageContinuation = messageCont
        self.offerContinuation = offerCont
        self.answerContinuation = answerCont
        self.iceCandidateContinuation = iceCandidateCont
        self.roomUpdateContinuation = roomUpdateCont

        setupBindings()
    }

    private func setupBindings() {
        // Forward socket client events to async streams
        socketClient.$connectionStatus
            .sink { [weak self] status in
                self?.connectionStatusContinuation.yield(status)
            }
            .store(in: &cancellables)

        socketClient.messageSubject
            .sink { [weak self] message in
                self?.messageContinuation.yield(message)
            }
            .store(in: &cancellables)

        socketClient.offerSubject
            .sink { [weak self] offer in
                self?.offerContinuation.yield(offer)
            }
            .store(in: &cancellables)

        socketClient.answerSubject
            .sink { [weak self] answer in
                self?.answerContinuation.yield(answer)
            }
            .store(in: &cancellables)

        socketClient.iceCandidateSubject
            .sink { [weak self] candidate in
                self?.iceCandidateContinuation.yield(candidate)
            }
            .store(in: &cancellables)

        socketClient.roomUpdateSubject
            .sink { [weak self] roomInfo in
                self?.roomUpdateContinuation.yield(roomInfo)
            }
            .store(in: &cancellables)
    }

    func connect(to url: URL) async {
        await socketClient.connect(to: url)
    }

    func disconnect() async {
        await socketClient.disconnect()
    }

    func joinRoom(roomId: String, userId: String) async throws {
        try await socketClient.joinRoom(roomId: roomId, userId: userId)
    }

    func leaveRoom(roomId: String) async throws {
        try await socketClient.leaveRoom(roomId: roomId)
    }

    func sendOffer(_ offer: WebRTCOffer) async throws {
        try await socketClient.sendOffer(offer)
    }

    func sendAnswer(_ answer: WebRTCAnswer) async throws {
        try await socketClient.sendAnswer(answer)
    }

    func sendICECandidate(_ candidate: ICECandidate) async throws {
        try await socketClient.sendICECandidate(candidate)
    }
}

enum SocketError: Error, LocalizedError {
    case notConnected
    case invalidURL
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Socket not connected"
        case .invalidURL:
            return "Invalid URL"
        case .connectionFailed:
            return "Connection failed"
        }
    }
}
