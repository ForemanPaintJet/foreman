//
//  VideoView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/4.
//

import SwiftUI
import WebRTC

// MARK: - Video Renderer View

struct VideoView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        print("📺 VideoView: Creating RTCMTLVideoView")
        let videoView = RTCMTLVideoView(frame: .zero)
        videoView.videoContentMode = .scaleAspectFill
        videoView.delegate = context.coordinator

        // Ensure the view is ready for rendering
        videoView.backgroundColor = UIColor.black
        videoView.isOpaque = true
        videoView.contentMode = .scaleAspectFill

        print("📺 VideoView: RTCMTLVideoView created successfully")
        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        print(
            "📺 VideoView: updateUIView called with videoTrack: \(videoTrack != nil ? "present" : "nil")"
        )

        // Always remove existing renderers first
        if let track = context.coordinator.currentTrack {
            print("📺 VideoView: Removing existing video track from renderer")
            track.remove(uiView)
            context.coordinator.currentTrack = nil
        }

        if let videoTrack = videoTrack {
            print("📺 VideoView: Adding video track to renderer")
            print("📺 VideoView: Video track enabled: \(videoTrack.isEnabled)")
            print("📺 VideoView: Video track state: \(videoTrack.readyState.rawValue)")
            print("📺 VideoView: Video track kind: \(videoTrack.kind)")

            videoTrack.add(uiView)
            context.coordinator.currentTrack = videoTrack

            // Force a layout update
            DispatchQueue.main.async {
                uiView.setNeedsLayout()
                uiView.layoutIfNeeded()
                print("📺 VideoView: Layout updated for video renderer")
            }

            // Add a debug check to see if frames are being received
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("📺 VideoView: Video renderer check - bounds: \(uiView.bounds)")
                print("📺 VideoView: Video renderer check - isHidden: \(uiView.isHidden)")
                print("📺 VideoView: Video renderer check - alpha: \(uiView.alpha)")
            }
        } else {
            print("📺 VideoView: No video track to render")
            uiView.renderFrame(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, RTCVideoViewDelegate {
        var currentTrack: RTCVideoTrack?

        func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
            print("📺 VideoView: Video size changed to \(size)")
            print("📺 VideoView: Video size change - width: \(size.width), height: \(size.height)")

            // Ensure we're on the main thread for UI updates
            DispatchQueue.main.async {
                if let metalView = videoView as? RTCMTLVideoView {
                    metalView.setNeedsLayout()
                    metalView.layoutIfNeeded()
                    print("📺 VideoView: Metal view layout refreshed after size change")
                }
            }
        }
    }
}

// MARK: - Remote Video Viewer

struct RemoteVideoViewer: View {
    @ObservedObject var webRTCClient: WebRTCClient

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if webRTCClient.remoteVideoTracks.isEmpty {
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
                    // Display remote video streams
                    RemoteVideoGrid(webRTCClient: webRTCClient)
                }

                // Connection status overlay
                VStack {
                    HStack {
                        Spacer()
                        ConnectionStatusOverlay(webRTCClient: webRTCClient)
                    }
                    .padding()

                    Spacer()
                }
            }
        }
    }
}

struct ConnectionStatusOverlay: View {
    @ObservedObject var webRTCClient: WebRTCClient

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(webRTCClient.connectionStates, id: \.userId) { connectionInfo in
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
    @ObservedObject var webRTCClient: WebRTCClient

    private let columns = [
        GridItem(.flexible()),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(webRTCClient.remoteVideoTracks) { videoInfo in
                    RemoteVideoCell(videoInfo: videoInfo, webRTCClient: webRTCClient)
                }
            }
            .padding()
        }
    }
}

struct RemoteVideoCell: View {
    let videoInfo: VideoTrackInfo
    @ObservedObject var webRTCClient: WebRTCClient

    private var connectionState: RTCPeerConnectionState? {
        webRTCClient.connectionStates.first { $0.userId == videoInfo.userId }?.connectionState
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
    @ObservedObject var webRTCClient: WebRTCClient

    var body: some View {
        VStack(spacing: 16) {
            Text("Receive-Only Mode")
                .font(.caption)
                .foregroundColor(.gray)

            HStack(spacing: 20) {
                // Info about connected streams
                VStack {
                    Text("\(webRTCClient.remoteVideoTracks.count)")
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
                    Text(
                        "\(webRTCClient.connectionStates.filter { $0.connectionState == .connected }.count)"
                    )
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
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

// MARK: - Video Viewer App

struct VideoCallView: View {
    @ObservedObject var webRTCClient: WebRTCClient

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Main video viewing area
                RemoteVideoViewer(webRTCClient: webRTCClient)

                // Bottom controls
                VideoControlsView(webRTCClient: webRTCClient)
                    .padding()
            }
        }
        .navigationTitle("Video Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .onAppear {
            // No permissions needed for receive-only mode
            print("🎥 Video viewer started in receive-only mode")
        }
    }
}

#Preview {
    VideoCallView(webRTCClient: WebRTCClient())
}
