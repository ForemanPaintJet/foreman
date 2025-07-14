//
//  WebRTCSocketView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/3.
//

import ComposableArchitecture
import SwiftUI
import ForemanThemeCore

struct WebRTCSocketView: View {
    @Bindable var store: StoreOf<WebRTCSocketFeature>
    @Dependency(\.themeService) var themeService
    
    // Orange theme configuration
    private var themeConfig: ThemeConfiguration<DynamicTheme> {
        themeService.themeConfiguration(for: .orange, variant: .vibrant)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Orange themed background
                themeConfig.colorTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        connectionSection
                        if store.isJoinedToRoom {
                            connectedUsersSection
                        }
                        messagesSection
                        webRTCControlsSection
                    }
                    .padding()
                }
                
                if store.isJoinedToRoom {
                    // Video Viewer View
                    VideoCallViewWrapper(store: store)
                }
            }
            .navigationTitle("WebRTC Socket")
            .navigationBarTitleDisplayMode(.large)
        }
        .frame(maxWidth: 1000, maxHeight: 800) // Limit the view size instead of taking whole screen
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Add rounded corners for better visual containment
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear {
            store.send(.view(.onAppear))
        }
        .onDisappear {
            store.send(.view(.onDisappear))
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Server Connection", icon: "network", themeConfig: themeConfig)

            VStack(spacing: 12) {
                // Server URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(themeConfig.colorTheme.secondary)

                    TextField(
                        "ws://192.168.1.105:4000",
                        text: $store.serverURL.sending(\.view.updateServerURL)
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(store.connectionStatus != .disconnected)
                }

                // Room ID Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room ID")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(themeConfig.colorTheme.secondary)

                    TextField("Enter room ID", text: $store.roomId.sending(\.view.updateRoomId))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(store.connectionStatus != .disconnected)
                }

                // User ID Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("User ID")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(themeConfig.colorTheme.secondary)

                    TextField("Your user ID", text: $store.userId.sending(\.view.updateUserId))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(store.connectionStatus != .disconnected)
                }

                // Connection Status
                ConnectionStatusCard(
                    status: store.connectionStatus,
                    lastError: store.lastError,
                    themeConfig: themeConfig
                ) {
                    store.send(.view(.clearError))
                }

                // Connection Buttons
                HStack(spacing: 12) {
                    OperationButton(
                        title: "Connect & Join Room",
                        icon: "network",
                        color: themeConfig.colorTheme.goldenColor,
                        isExecuting: store.loadingItems.contains(.connecting) || store.loadingItems.contains(.joiningRoom),
                        isEnabled: store.canConnect
                    ) {
                        store.send(.view(.connectToServer))
                    }

                    OperationButton(
                        title: "Disconnect",
                        icon: "network.slash",
                        color: Color.red,
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
                .fill(themeConfig.colorTheme.lightColor)
                .shadow(color: themeConfig.colorTheme.primary.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - Connected Users Section

    private var connectedUsersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Connected Users", icon: "person.3", themeConfig: themeConfig)

            if store.connectedUsers.isEmpty {
                Text("No other users in the room")
                    .foregroundColor(themeConfig.colorTheme.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(store.connectedUsers, id: \.self) { user in
                        UserRow(
                            userId: user,
                            isCurrentUser: user == store.userId,
                            themeConfig: themeConfig,
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
                .fill(themeConfig.colorTheme.lightColor)
                .shadow(color: themeConfig.colorTheme.primary.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Socket Messages", icon: "message", themeConfig: themeConfig)

                Spacer()

                Button("Clear") {
                    store.send(.view(.clearMessages))
                }
                .font(.caption)
                .foregroundColor(themeConfig.colorTheme.primary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if store.messages.isEmpty {
                        Text("No messages yet")
                            .foregroundColor(themeConfig.colorTheme.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(Array(store.messages.enumerated()), id: \.offset) { _, message in
                            MessageRow(message: message, themeConfig: themeConfig)
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
                .fill(themeConfig.colorTheme.lightColor)
                .shadow(color: themeConfig.colorTheme.primary.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - WebRTC Controls Section

    private var webRTCControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Video Viewer", icon: "tv", themeConfig: themeConfig)

            if store.isJoinedToRoom {
                // Video Viewer Interface (Receive-only)
                VStack(spacing: 16) {
                    // Info about receive-only mode
                    HStack {
                        Image(systemName: "eye")
                            .foregroundColor(themeConfig.colorTheme.primary)
                        Text("Receive-Only Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeConfig.colorTheme.darkColor)
                        Spacer()
                        Text("You can view others' video streams")
                            .font(.caption)
                            .foregroundColor(themeConfig.colorTheme.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeConfig.colorTheme.primary.opacity(0.1))
                    )

                    // Connected Users with Call Buttons
                    if !store.connectedUsers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Streams")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeConfig.colorTheme.darkColor)

                            ForEach(store.connectedUsers.filter { $0 != store.userId }, id: \.self)
                            { user in
                                HStack {
                                    Image(systemName: "person.circle")
                                        .foregroundColor(themeConfig.colorTheme.primary)

                                    Text(user)
                                        .font(.body)
                                        .foregroundColor(themeConfig.colorTheme.darkColor)

                                    Spacer()

                                    Button("Watch") {
                                        store.send(.view(.createOfferForUser(user)))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.capsule)
                                    .tint(themeConfig.colorTheme.goldenColor)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // WebRTC Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Status")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeConfig.colorTheme.darkColor)

                        HStack {
                            VStack(alignment: .leading) {
                                InfoRow(
                                    title: "Incoming Offers",
                                    value: "\(store.pendingOffers.count)",
                                    color: themeConfig.colorTheme.primary,
                                    themeConfig: themeConfig
                                )
                                InfoRow(
                                    title: "Responses Sent",
                                    value: "\(store.pendingAnswers.count)",
                                    color: themeConfig.colorTheme.warmColor,
                                    themeConfig: themeConfig
                                )
                            }

                            Spacer()

                            InfoRow(
                                title: "ICE Candidates",
                                value: "\(store.pendingIceCandidates.count)",
                                color: themeConfig.colorTheme.secondary,
                                themeConfig: themeConfig
                            )
                        }
                    }
                }
            } else {
                Text("Join a room to start watching video streams")
                    .font(.body)
                    .foregroundColor(themeConfig.colorTheme.secondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeConfig.colorTheme.lightColor.opacity(0.5))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeConfig.colorTheme.lightColor)
                .shadow(color: themeConfig.colorTheme.primary.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    let themeConfig: ThemeConfiguration<DynamicTheme>

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(themeConfig.colorTheme.primary)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeConfig.colorTheme.darkColor)
        }
    }
}

struct ConnectionStatusCard: View {
    let status: ConnectionStatus
    let lastError: String?
    let themeConfig: ThemeConfiguration<DynamicTheme>
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
                    .foregroundColor(themeConfig.colorTheme.darkColor)

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
                    .foregroundColor(themeConfig.colorTheme.primary)
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
            .foregroundColor(isEnabled ? .white : .gray)
        }
        .disabled(!isEnabled || isExecuting)
    }
}

struct UserRow: View {
    let userId: String
    let isCurrentUser: Bool
    let themeConfig: ThemeConfiguration<DynamicTheme>
    let onSendOffer: () -> Void
    let onSendAnswer: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(userId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeConfig.colorTheme.darkColor)

                if isCurrentUser {
                    Text("(You)")
                        .font(.caption)
                        .foregroundColor(themeConfig.colorTheme.secondary)
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
                    .background(themeConfig.colorTheme.primary.opacity(0.1))
                    .foregroundColor(themeConfig.colorTheme.primary)
                    .cornerRadius(6)

                    Button("Answer") {
                        onSendAnswer()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeConfig.colorTheme.goldenColor.opacity(0.1))
                    .foregroundColor(themeConfig.colorTheme.goldenColor)
                    .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentUser ? themeConfig.colorTheme.primary.opacity(0.05) : themeConfig.colorTheme.lightColor.opacity(0.5))
        )
    }
}

struct MessageRow: View {
    let message: SocketMessage
    let themeConfig: ThemeConfiguration<DynamicTheme>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.type)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(themeConfig.colorTheme.primary.opacity(0.1))
                    .foregroundColor(themeConfig.colorTheme.primary)
                    .cornerRadius(4)

                Spacer()

                Text(Date().formatted(.dateTime.hour().minute().second()))
                    .font(.caption)
                    .foregroundColor(themeConfig.colorTheme.secondary)
            }

            if let data = message.data, !data.isEmpty {
                ForEach(Array(data.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text("\(key):")
                            .font(.caption)
                            .foregroundColor(themeConfig.colorTheme.secondary)

                        Text(data[key] ?? "")
                            .font(.caption)
                            .foregroundColor(themeConfig.colorTheme.darkColor)
                            .lineLimit(1)

                        Spacer()
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(themeConfig.colorTheme.lightColor.opacity(0.5))
        )
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let color: Color
    let themeConfig: ThemeConfiguration<DynamicTheme>

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(themeConfig.colorTheme.secondary)

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
        !serverURL.isEmpty && !roomId.isEmpty && !userId.isEmpty && connectionStatus == .disconnected
            && !loadingItems.contains(.connecting) && !loadingItems.contains(.joiningRoom)
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

// MARK: - Video Call View Wrapper

struct VideoCallViewWrapper: View {
    let store: StoreOf<WebRTCSocketFeature>

    var body: some View {
        VStack {
            if store.isJoinedToRoom {
                DirectVideoCallView()
                    .navigationBarHidden(true)
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Connecting to video session...")
                        .foregroundColor(.white)
                    if !store.isJoinedToRoom {
                        Text("Please join a room first")
                            .foregroundColor(.orange)
                    }

                    Button("Back") {
                        // Navigation will handle this
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            }
        }
    }
}

// MARK: - Direct Video Call View

struct DirectVideoCallView: View {
    @Dependency(\.webRTCClient) var webRTCClientDependency

    var body: some View {
        VideoCallView(webRTCClient: WebRTCClientLive.shared.getClient())
            .onAppear {
                print("🎥 DirectVideoCallView: Video viewer started with WebRTC client")

                // Debug: Print current video tracks
                let client = WebRTCClientLive.shared.getClient()
                print(
                    "🎥 DirectVideoCallView: Current video tracks count: \(client.remoteVideoTracks.count)"
                )
                for (index, track) in client.remoteVideoTracks.enumerated() {
                    print(
                        "🎥 Track \(index): User \(track.userId), Enabled: \(track.track?.isEnabled ?? false)"
                    )
                }
            }
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
