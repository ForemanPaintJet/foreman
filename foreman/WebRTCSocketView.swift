//
//  WebRTCSocketView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/3.
//

import ComposableArchitecture
import SwiftUI

struct WebRTCSocketView: View {
    @Bindable var store: StoreOf<WebRTCSocketFeature>

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        connectionSection
                        roomSection
                        if store.isJoinedToRoom {
                            connectedUsersSection
                        }
                        messagesSection
                        webRTCControlsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("WebRTC Socket")
            .navigationBarTitleDisplayMode(.large)
            .alert($store.scope(state: \.alert, action: \.alert))
            .onAppear {
                store.send(.view(.onAppear))
            }
            .onDisappear {
                store.send(.view(.onDisappear))
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Server Connection", icon: "network")

            VStack(spacing: 12) {
                // Server URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField(
                        "ws://192.168.1.105:4000",
                        text: $store.serverURL.sending(\.view.updateServerURL)
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(store.connectionStatus != .disconnected)
                }

                // Connection Status
                ConnectionStatusCard(
                    status: store.connectionStatus,
                    lastError: store.lastError
                ) {
                    store.send(.view(.clearError))
                }

                // Connection Buttons
                HStack(spacing: 12) {
                    OperationButton(
                        title: "Connect",
                        icon: "network",
                        color: .green,
                        isExecuting: store.loadingItems.contains(.connecting),
                        isEnabled: store.canConnect
                    ) {
                        store.send(.view(.connectToServer))
                    }

                    OperationButton(
                        title: "Disconnect",
                        icon: "network.slash",
                        color: .red,
                        isExecuting: false,
                        isEnabled: store.connectionStatus == .connected
                    ) {
                        store.send(.view(.disconnect))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - Room Section

    private var roomSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Room Management", icon: "person.2")

            VStack(spacing: 12) {
                // Room ID Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room ID")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("Enter room ID", text: $store.roomId.sending(\.view.updateRoomId))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(store.isJoinedToRoom)
                }

                // User ID Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("User ID")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("Your user ID", text: $store.userId.sending(\.view.updateUserId))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(store.isJoinedToRoom)
                }

                // Room Buttons
                HStack(spacing: 12) {
                    OperationButton(
                        title: "Join Room",
                        icon: "plus.circle",
                        color: .blue,
                        isExecuting: store.loadingItems.contains(.joiningRoom),
                        isEnabled: store.canJoinRoom
                    ) {
                        store.send(.view(.joinRoom))
                    }

                    OperationButton(
                        title: "Leave Room",
                        icon: "minus.circle",
                        color: .orange,
                        isExecuting: store.loadingItems.contains(.leavingRoom),
                        isEnabled: store.canLeaveRoom
                    ) {
                        store.send(.view(.leaveRoom))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - Connected Users Section

    private var connectedUsersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Connected Users", icon: "person.3")

            if store.connectedUsers.isEmpty {
                Text("No other users in the room")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(store.connectedUsers, id: \.self) { user in
                        UserRow(
                            userId: user,
                            isCurrentUser: user == store.userId,
                            onSendOffer: {
                                // Mock WebRTC offer for demo
                                store.send(.view(.sendOffer(to: user, sdp: "mock-sdp-offer")))
                            },
                            onSendAnswer: {
                                // Mock WebRTC answer for demo
                                store.send(.view(.sendAnswer(to: user, sdp: "mock-sdp-answer")))
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Socket Messages", icon: "message")

                Spacer()

                Button("Clear") {
                    store.send(.view(.clearMessages))
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if store.messages.isEmpty {
                        Text("No messages yet")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(Array(store.messages.enumerated()), id: \.offset) { _, message in
                            MessageRow(message: message)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - WebRTC Controls Section

    private var webRTCControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "WebRTC Controls", icon: "video")

            VStack(spacing: 12) {
                InfoRow(
                    title: "Pending Offers",
                    value: "\(store.pendingOffers.count)",
                    color: .blue
                )

                InfoRow(
                    title: "Pending Answers",
                    value: "\(store.pendingAnswers.count)",
                    color: .green
                )

                InfoRow(
                    title: "Pending ICE Candidates",
                    value: "\(store.pendingIceCandidates.count)",
                    color: .purple
                )

                if !store.pendingOffers.isEmpty || !store.pendingAnswers.isEmpty
                    || !store.pendingIceCandidates.isEmpty
                {
                    Text(
                        "This is a demo implementation. In a real app, you would integrate with WebRTC framework to handle these offers, answers, and ICE candidates."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

struct ConnectionStatusCard: View {
    let status: ConnectionStatus
    let lastError: String?
    let onClearError: () -> Void

    var statusColor: Color {
        switch status {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    var statusText: String {
        switch status {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()
            }

            if let error = lastError {
                HStack {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)

                    Spacer()

                    Button("Dismiss") {
                        onClearError()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct OperationButton: View {
    let title: String
    let icon: String
    let color: Color
    let isExecuting: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                }

                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? color : Color.gray)
            )
            .foregroundColor(.white)
        }
        .disabled(!isEnabled || isExecuting)
    }
}

struct UserRow: View {
    let userId: String
    let isCurrentUser: Bool
    let onSendOffer: () -> Void
    let onSendAnswer: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(userId)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if isCurrentUser {
                    Text("(You)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !isCurrentUser {
                HStack(spacing: 8) {
                    Button("Offer") {
                        onSendOffer()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)

                    Button("Answer") {
                        onSendAnswer()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentUser ? Color.blue.opacity(0.05) : Color.gray.opacity(0.05))
        )
    }
}

struct MessageRow: View {
    let message: SocketMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.type)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)

                Spacer()

                Text(Date().formatted(.dateTime.hour().minute().second()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let data = message.data, !data.isEmpty {
                ForEach(Array(data.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text("\(key):")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(data[key] ?? "")
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Computed Properties Extension

extension WebRTCSocketFeature.State {
    var canConnect: Bool {
        !serverURL.isEmpty && connectionStatus == .disconnected
            && !loadingItems.contains(.connecting)
    }

    var canJoinRoom: Bool {
        connectionStatus == .connected && !roomId.isEmpty && !userId.isEmpty && !isJoinedToRoom
            && !loadingItems.contains(.joiningRoom)
    }

    var canLeaveRoom: Bool {
        isJoinedToRoom && !loadingItems.contains(.leavingRoom)
    }
}

#Preview {
    WebRTCSocketView(
        store: Store(
            initialState: WebRTCSocketFeature.State(),
            reducer: { WebRTCSocketFeature() }
        )
    )
}
