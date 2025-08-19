//
//  VideoView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/4.
//

import Foundation
import OSLog
import SwiftUI
import WebRTC
import WebRTCCore

// MARK: - Video Renderer View

struct VideoView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack?
    private let logger = Logger(subsystem: "foreman", category: "VideoView")

    func makeUIView(context: Context) -> RTCMTLVideoView {
        logger.info("📺 VideoView: Creating RTCMTLVideoView")
        let videoView = RTCMTLVideoView(frame: .zero)
        videoView.videoContentMode = .scaleAspectFill
        videoView.delegate = context.coordinator

        // Ensure the view is ready for rendering
        videoView.backgroundColor = UIColor.black
        videoView.isOpaque = true
        videoView.contentMode = .scaleAspectFill

        logger.info("📺 VideoView: RTCMTLVideoView created successfully")
        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        logger.info(
            "📺 VideoView: updateUIView called with videoTrack: \(videoTrack != nil ? "present" : "nil")"
        )

        // Always remove existing renderers first
        if let track = context.coordinator.currentTrack {
            logger.info("📺 VideoView: Removing existing video track from renderer")
            track.remove(uiView)
            context.coordinator.currentTrack = nil
        }

        if let videoTrack = videoTrack {
            logger.info("📺 VideoView: Adding video track to renderer")
            logger.info("📺 VideoView: Video track enabled: \(videoTrack.isEnabled)")
            logger.info("📺 VideoView: Video track state: \(videoTrack.readyState.rawValue)")
            logger.info("📺 VideoView: Video track kind: \(videoTrack.kind)")

            videoTrack.add(uiView)
            context.coordinator.currentTrack = videoTrack

            // Force a layout update
            DispatchQueue.main.async { [self] in
                uiView.setNeedsLayout()
                uiView.layoutIfNeeded()
                self.logger.info("📺 VideoView: Layout updated for video renderer")
            }

            // Add a debug check to see if frames are being received
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                self.logger.info("📺 VideoView: Video renderer check - bounds: \(uiView.bounds)")
                self.logger.info("📺 VideoView: Video renderer check - isHidden: \(uiView.isHidden)")
                self.logger.info("📺 VideoView: Video renderer check - alpha: \(uiView.alpha)")
            }
        } else {
            logger.info("📺 VideoView: No video track to render")
            uiView.renderFrame(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, RTCVideoViewDelegate {
        var currentTrack: RTCVideoTrack?
        private let logger = Logger(subsystem: "foreman", category: "VideoViewCoordinator")

        func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
            self.logger.info("📺 VideoView: Video size changed to \(size)")
            self.logger.info(
                "📺 VideoView: Video size change - width: \(size.width), height: \(size.height)")

            // Ensure we're on the main thread for UI updates
            DispatchQueue.main.async { [self] in
                if let metalView = videoView as? RTCMTLVideoView {
                    metalView.setNeedsLayout()
                    metalView.layoutIfNeeded()
                    logger.info("📺 VideoView: Metal view layout refreshed after size change")
                }
            }
        }
    }
}

extension CGRect: @retroactive CustomStringConvertible {
    public var description: String {
        "\(self.size)"
    }
}

extension CGSize: @retroactive CustomStringConvertible {
    public var description: String {
        "\(self.width), \(self.height)"
    }
}

// MARK: - Remote Video Viewer

struct RemoteVideoViewer: View {
    let remoteVideoTracks: [VideoTrackInfo]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if remoteVideoTracks.isEmpty {
                    // No remote streams available
                    VStack {
                        Spacer()

                        VStack(spacing: 16) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("No Video Streams")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)

                            Text("Waiting for other participants to start their video...")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Spacer()
                    }
                } else {
                    RemoteVideoGrid(remoteVideoTracks: remoteVideoTracks)
                }

                // Connection status overlay
                VStack {
                    HStack {
                        Spacer()
                        ConnectionStatusOverlay(connectionStates: [])
                    }
                    .padding()

                    Spacer()
                }
            }
        }
    }
}

struct ConnectionStatusOverlay: View {
    let connectionStates: [PeerConnectionInfo]

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(connectionStates, id: \.userId) { connectionInfo in
                HStack(spacing: 8) {
                    Text(connectionInfo.userId)
                        .font(.caption)
                        .foregroundColor(.white)

                    Circle()
                        .fill(connectionStateColor(connectionInfo.connectionState))
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            }
        }
    }

    private func connectionStateColor(_ state: RTCPeerConnectionState) -> Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected, .failed, .closed:
            return .red
        case .new:
            return .blue
        @unknown default:
            return .gray
        }
    }
}

// MARK: - Remote Video Grid

struct RemoteVideoGrid: View {
    let remoteVideoTracks: [VideoTrackInfo]

    private let columns = [
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(remoteVideoTracks) { videoInfo in
                    RemoteVideoCell(videoInfo: videoInfo, connectionStates: [])
                }
            }
            .padding()
        }
    }
}

struct RemoteVideoCell: View {
    let videoInfo: VideoTrackInfo
    let connectionStates: [PeerConnectionInfo]

    private var connectionState: RTCPeerConnectionState? {
        connectionStates.first { $0.userId == videoInfo.userId }?.connectionState
    }

    var body: some View {
        ZStack {
            VideoView(videoTrack: videoInfo.track)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(connectionStateColor, lineWidth: 2)
                )

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(videoInfo.userId)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)

                        if let state = connectionState {
                            Text(connectionStateText(state))
                                .font(.caption2)
                                .foregroundColor(connectionStateColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var connectionStateColor: Color {
        guard let state = connectionState else { return .gray }

        switch state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected, .failed, .closed:
            return .red
        case .new:
            return .blue
        @unknown default:
            return .gray
        }
    }

    private func connectionStateText(_ state: RTCPeerConnectionState) -> String {
        switch state {
        case .new:
            return "New"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Failed"
        case .closed:
            return "Closed"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Video Controls (Receive-only mode)

struct VideoControlsView: View {
    let remoteVideoTracks: [VideoTrackInfo]

    var body: some View {
        VStack(spacing: 16) {
            Text("Receive-Only Mode")
                .font(.caption)
                .foregroundColor(.gray)

            HStack(spacing: 20) {
                // Info about connected streams
                VStack {
                    Text("\(remoteVideoTracks.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Video Streams")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(minWidth: 80)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)

                // Connection status summary
                VStack {
//                    Text(
//                        "\(webRTCEngine.connectionStates.filter { $0.connectionState == .connected }.count)"
//                    )
//                    .font(.title2)
//                    .fontWeight(.bold)
//                    .foregroundColor(.white)
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(minWidth: 80)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(20)
    }
}

#Preview {
    VideoControlsView(remoteVideoTracks: [])
}

// MARK: - Video Viewer App

struct VideoCallView: View {
    let remoteVideoTracks: [VideoTrackInfo]
    let connectionStates: [PeerConnectionInfo]
    private let logger = Logger(subsystem: "foreman", category: "VideoCallView")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Main video viewing area
                RemoteVideoViewer(remoteVideoTracks: remoteVideoTracks)
//
//                // Bottom controls
//                VideoControlsView(remoteVideoTracks: remoteVideoTracks)
//                    .padding()
            }
        }
        .navigationTitle("Video Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .task {
            // No permissions needed for receive-only mode
            logger.info("🎥 Video viewer started in receive-only mode")
        }
    }
}

#Preview {
    VideoCallView(remoteVideoTracks: [], connectionStates: [])
}
