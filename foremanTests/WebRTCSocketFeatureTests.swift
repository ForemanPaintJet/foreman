//
//  WebRTCSocketFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/13.
//

import ComposableArchitecture
import Testing

@testable import foreman

@Suite("WebRTCSocketFeature")
@MainActor
struct WebRTCSocketFeatureTests {
  @Test("generateDefaultUserId sets userId")
  func testGenerateDefaultUserId() async throws {
    var state = WebRTCSocketFeature.State()
    state.generateDefaultUserId()
    #expect(state.userId.hasPrefix("user_"))
  }

  @Test("binding updates work correctly")
  func testBindingUpdates() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    await store.send(.binding(.set(\.serverURL, "ws://192.168.1.200:8080"))) {
      $0.serverURL = "ws://192.168.1.200:8080"
    }

    await store.send(.binding(.set(\.roomId, "test-room"))) {
      $0.roomId = "test-room"
    }

    await store.send(.binding(.set(\.userId, "test-user"))) {
      $0.userId = "test-user"
    }
  }

  @Test("connection status changes")
  func testConnectionStatusChanged() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(connectionStatus: .disconnected),
      reducer: { WebRTCSocketFeature() })

    await store.send(._internal(.connectionStatusChanged(.connecting))) {
      $0.connectionStatus = .connecting
    }

    await store.send(._internal(.connectionStatusChanged(.connected))) {
      $0.connectionStatus = .connected
    }

    await store.send(._internal(.connectionStatusChanged(.error))) {
      $0.connectionStatus = .error
    }
  }

  @Test("loading state management")
  func testLoadingStateManagement() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    // Test connecting loading state
    await store.send(._internal(.setLoading(.connecting, true))) {
      $0.loadingItems.insert(.connecting)
    }

    await store.send(._internal(.setLoading(.connecting, false))) {
      $0.loadingItems.remove(.connecting)
    }

    // Test multiple loading states
    await store.send(._internal(.setLoading(.joiningRoom, true))) {
      $0.loadingItems.insert(.joiningRoom)
    }

    await store.send(._internal(.setLoading(.sendingOffer, true))) {
      $0.loadingItems.insert(.sendingOffer)
      #expect($0.loadingItems.count == 2)
    }

    await store.send(._internal(.setLoading(.joiningRoom, false))) {
      $0.loadingItems.remove(.joiningRoom)
      #expect($0.loadingItems.count == 1)
    }
  }

  @Test("socket message received")
  func testSocketMessageReceived() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    let message = SocketMessage(type: "test", data: ["key": "value"])

    await store.send(._internal(.socketMessageReceived(message))) {
      $0.messages.append(message)
    }

    // Test message limit (50)
    let messages = (0..<49).map { SocketMessage(type: "test\($0)", data: nil) }
    var stateWithMessages = WebRTCSocketFeature.State()
    stateWithMessages.messages = [message] + messages

    let storeWithMessages = TestStore(
      initialState: stateWithMessages, reducer: { WebRTCSocketFeature() })

    let newMessage = SocketMessage(type: "new", data: nil)
    await storeWithMessages.send(._internal(.socketMessageReceived(newMessage))) {
      $0.messages.removeFirst()
      $0.messages.append(newMessage)
      #expect($0.messages.count == 50)
    }
  }

  @Test("offer received")
  func testOfferReceived() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    let offer = WebRTCOffer(sdp: "test-sdp", type: "offer", clientId: "client1", videoSource: "")

    await store.send(._internal(.offerReceived(offer))) {
      $0.pendingOffers.append(offer)
    }
  }

  @Test("answer received")
  func testAnswerReceived() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    let answer = WebRTCAnswer(sdp: "test-sdp", type: "answer", clientId: "client1", videoSource: "")

    await store.send(._internal(.answerReceived(answer))) {
      $0.pendingAnswers.append(answer)
    }
  }

  @Test("ice candidate received")
  func testIceCandidateReceived() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    let iceCandidate = ICECandidate(
      type: "ice", clientId: "client1",
      candidate: .init(candidate: "test-candidate", sdpMLineIndex: 0, sdpMid: "0"))

    await store.send(._internal(.iceCandidateReceived(iceCandidate))) {
      $0.pendingIceCandidates.append(iceCandidate)
    }
  }

  @Test("room update received")
  func testRoomUpdateReceived() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    let roomInfo = RoomInfo(roomId: "test-room", userCount: 3, users: ["user1", "user2", "user3"])

    await store.send(._internal(.roomUpdateReceived(roomInfo))) {
      $0.connectedUsers = roomInfo.users
    }
  }

  @Test("error occurred")
  func testErrorOccurred() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    await store.send(._internal(.errorOccurred("Connection failed"))) {
      $0.lastError = "Connection failed"
    }
    await store.send(.delegate(.connectionError("Connection failed")))
  }

  @Test("socket connection lifecycle")
  func testSocketConnectionLifecycle() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    await store.send(._internal(.socketConnected)) {
      $0.connectionStatus = .connected
      $0.lastError = nil
    }

    await store.send(._internal(.socketDisconnected)) {
      $0.connectionStatus = .disconnected
      $0.isJoinedToRoom = false
      $0.connectedUsers = []
    }
  }

  @Test("room lifecycle")
  func testRoomLifecycle() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    await store.send(._internal(.roomJoined)) {
      $0.isJoinedToRoom = true
    }

    await store.send(._internal(.roomLeft)) {
      $0.isJoinedToRoom = false
      $0.connectedUsers = []
    }
  }

  @Test("peer connection lifecycle")
  func testPeerConnectionLifecycle() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    await store.send(._internal(.peerConnectionCreated("user1")))
    await store.send(._internal(.peerConnectionRemoved("user1")))
  }

  @Test("view actions clear data")
  func testViewActionsClearData() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(
        lastError: "Test error",
        messages: [SocketMessage(type: "test", data: nil)]
      ), reducer: { WebRTCSocketFeature() })

    await store.send(.view(.clearMessages)) {
      $0.messages = []
    }

    await store.send(.view(.clearError)) {
      $0.lastError = nil
    }
  }

<<<<<<< HEAD
=======
  @Test("alert actions")
  func testAlertActions() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(lastError: "Test error"),
      reducer: { WebRTCSocketFeature() })

    await store.send(.alert(.presented(.confirmDisconnect)))
    await store.send(.alert(.presented(.confirmLeaveRoom)))
    await store.send(.alert(.presented(.dismissError))) {
      $0.lastError = nil
    }
    await store.send(.alert(.dismiss))
  }

>>>>>>> 1413385 (feat: Add comprehensive unit tests and improve TCA binding patterns)
  @Test("delegate actions do not change state")
  func testDelegateActions() async throws {
    let store = TestStore(
      initialState: WebRTCSocketFeature.State(), reducer: { WebRTCSocketFeature() })

    await store.send(.delegate(.didConnect))
    await store.send(.delegate(.didDisconnect))
    await store.send(.delegate(.didJoinRoom("test-room")))
    await store.send(.delegate(.didLeaveRoom))
    await store.send(.delegate(.connectionError("test error")))
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 1413385 (feat: Add comprehensive unit tests and improve TCA binding patterns)
