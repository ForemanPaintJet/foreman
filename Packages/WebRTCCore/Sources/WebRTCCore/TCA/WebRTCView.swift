//
//  WebRTCView.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/20.
//

import ComposableArchitecture
import SwiftUI
import WebRTC

// MARK: - WebRTC View

@ViewAction(for: WebRTCFeature.self)
package struct WebRTCView: View {
    @Bindable package var store: StoreOf<WebRTCFeature>

    package init(store: StoreOf<WebRTCFeature>) {
        self.store = store
    }

    package var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("WebRTC Connections")
                    .font(.headline)

                Spacer()

                Text("\(store.connectedPeers.count) connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Error Display
            if let error = store.error {
                ErrorView(error: error) {
                    send(.dismissError)
                }
            }

            // Connection Status
            ConnectionStatusView(
                connectionState: store.localConnectionState,
                isListening: store.isListening
            )

            // Peers List
            if store.connectedPeers.isEmpty {
                EmptyStateView()
            } else {
                PeersList(peers: store.connectedPeers)
            }

            Spacer()

            // Quick Actions
            QuickActionsView(store: store)
        }
        .task {
            send(.task)
        }
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let error: WebRTCError
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.red)

            Spacer()

            Button("Dismiss") {
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding()
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

// MARK: - Connection Status View

private struct ConnectionStatusView: View {
    let connectionState: WebRTCFeature.ConnectionState
    let isListening: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal)
    }

    private var statusColor: Color {
        if !isListening {
            return .gray
        }

        switch connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .failed:
            return .red
        case .disconnected, .closed:
            return .gray
        }
    }

    private var statusText: String {
        if !isListening {
            return "Not listening"
        }

        switch connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .failed:
            return "Connection failed"
        case .disconnected:
            return "Disconnected"
        case .closed:
            return "Connection closed"
        }
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No active connections")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Peers will appear here when they connect")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Peers List

private struct PeersList: View {
    let peers: IdentifiedArrayOf<WebRTCFeature.PeerState>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(peers) { peer in
                    PeerRowView(peer: peer)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Peer Row View

private struct PeerRowView: View {
    let peer: WebRTCFeature.PeerState

    var body: some View {
        HStack {
            // Peer ID
            VStack(alignment: .leading, spacing: 4) {
                Text(peer.id)
                    .font(.body)
                    .fontWeight(.medium)

                Text(peer.connectionState.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Video Track Status
            VStack(alignment: .trailing, spacing: 4) {
                if peer.videoTrack != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .foregroundStyle(.green)
                        Text("Video")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "video.slash")
                            .foregroundStyle(.gray)
                        Text("No video")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }

                // Connection indicator
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var connectionColor: Color {
        switch peer.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .failed:
            return .red
        case .disconnected, .closed:
            return .gray
        }
    }
}

// MARK: - Quick Actions View

private struct QuickActionsView: View {
    let store: StoreOf<WebRTCFeature>

    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Create Connection") {
                    // Example action - in real usage, you'd get userId from somewhere
                    store.send(
                        .view(.createPeerConnection(userId: "demo-user-\(Int.random(in: 1...999))"))
                    )
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Clear All") {
                    for peer in store.connectedPeers {
                        store.send(.view(.removePeerConnection(userId: peer.id)))
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(store.connectedPeers.isEmpty)
            }
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Empty State") {
    WebRTCView(
        store: Store(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        }
    )
}

#Preview("With Connections") {
    WebRTCView(
        store: Store(
            initialState: WebRTCFeature.State(
                connectedPeers: [
                    WebRTCFeature.PeerState(
                        id: "user123",
                        videoTrack: VideoTrackInfo(id: "track1", userId: "user123", track: nil),
                        connectionState: .connected
                    ),
                    WebRTCFeature.PeerState(
                        id: "user456",
                        connectionState: .connecting
                    ),
                ],
                localConnectionState: .connected,
                isListening: true
            )
        ) {
            WebRTCFeature()
        }
    )
}

#Preview("With Error") {
    WebRTCView(
        store: Store(
            initialState: WebRTCFeature.State(
                error: .peerConnectionNotFound,
                isListening: true
            )
        ) {
            WebRTCFeature()
        }
    )
}
