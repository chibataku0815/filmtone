import AVFoundation
import Foundation

#if os(iOS)

enum CaptureSessionPermissions {
    static func requestCapturePermissions() async -> (
        video: AVAuthorizationStatus,
        audio: AVAuthorizationStatus
    ) {
        async let video = requestPermission(for: .video)
        async let audio = requestPermission(for: .audio)
        return await (video, audio)
    }

    private static func requestPermission(for mediaType: AVMediaType) async -> AVAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: mediaType)
            return granted ? .authorized : .denied
        }
        return status
    }
}

enum CaptureAudioSessionGraph {
    static func addMicrophoneInput(to session: AVCaptureSession) throws {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw FilmtoneCaptureFailure.writerSetupFailed(
                stage: "AUDIO_DEVICE",
                reason: "No audio capture device is available."
            )
        }
        let audioInput: AVCaptureDeviceInput
        do {
            audioInput = try AVCaptureDeviceInput(device: audioDevice)
        } catch {
            throw FilmtoneCaptureFailure.writerSetupFailed(
                stage: "AUDIO_INPUT_CREATE",
                reason: error.localizedDescription
            )
        }
        guard session.canAddInput(audioInput) else {
            throw FilmtoneCaptureFailure.writerSetupFailed(
                stage: "AUDIO_INPUT_ADD",
                reason: "session.canAddInput(audioInput) returned false"
            )
        }
        session.addInput(audioInput)
    }

    static func validateAudioConnection(on output: AVCaptureMovieFileOutput) throws {
        guard output.connection(with: .audio) != nil else {
            throw FilmtoneCaptureFailure.writerSetupFailed(
                stage: "AUDIO_CONNECTION",
                reason: "AVCaptureMovieFileOutput did not attach an audio connection."
            )
        }
    }
}

enum CaptureMasterAudioValidator {
    static func validateMasterAudioTrackCount(at url: URL) -> Result<Int, FilmtoneCaptureFailure> {
        let count = AVURLAsset(url: url).tracks(withMediaType: .audio).count
        guard count > 0 else {
            return .failure(.masterAudioTrackMissing)
        }
        return .success(count)
    }
}

#endif
