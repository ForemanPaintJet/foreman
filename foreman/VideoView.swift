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
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        view.delegate = context.coordinator
        view.backgroundColor = .black
        view.isOpaque = true
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        context.coordinator.bind(track: videoTrack, to: uiView)
    }

    func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: Coordinator) {
        coordinator.bind(track: nil, to: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, RTCVideoViewDelegate {
        var currentTrack: RTCVideoTrack?
        private let logger = Logger(subsystem: "foreman", category: "VideoViewCoordinator")

        func bind(track: RTCVideoTrack?, to view: RTCMTLVideoView) {
            if let oldTrack = currentTrack {
                oldTrack.remove(view)
            }
            currentTrack = track
            if let track = track {
                logger.info("📺 Binding new video track")
                track.add(view)
            } else {
                view.renderFrame(nil)
            }
        }

        @MainActor
        func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
            logger.info("📺 Video size changed to \(size)")
            (videoView as? RTCMTLVideoView)?.setNeedsLayout()
        }
    }
}

extension CGRect: @retroactive CustomStringConvertible {
    public var description: String {
        "\(size)"
    }
}

extension CGSize: @retroactive CustomStringConvertible {
    public var description: String {
        "\(width), \(height)"
    }
}

// MARK: - Remote Video Viewer

struct RemoteVideoViewer: View {
    let remoteVideoTracks: [VideoTrackInfo]

    var body: some View {
        if remoteVideoTracks.isEmpty {
            EmptyVideoState()
        } else {
            ForEach(remoteVideoTracks) { videoInfo in
                RemoteVideoCell(videoInfo: videoInfo)
            }
            .padding()
        }
    }
}

struct EmptyVideoState: View {
    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RemoteVideoCell: View {
    let videoInfo: VideoTrackInfo

    var body: some View {
        VideoView(videoTrack: videoInfo.track)
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(Color.black)
            .cornerRadius(12)
            .overlay(
                UserLabel(userId: videoInfo.userId),
                alignment: .bottomTrailing
            )
    }
}

struct UserLabel: View {
    let userId: String

    var body: some View {
        Text(userId)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .padding()
    }
}

// MARK: - Video Viewer App

struct VideoCallView: View {
    let remoteVideoTracks: [VideoTrackInfo]
    private let logger = Logger(subsystem: "foreman", category: "VideoCallView")

    var body: some View {
        RemoteVideoViewer(remoteVideoTracks: remoteVideoTracks)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Video Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .task {
                logger.info("🎥 Video viewer started in receive-only mode")
            }
    }
}

#Preview {
    VideoCallView(remoteVideoTracks: [])
}
