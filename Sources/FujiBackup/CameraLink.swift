import Foundation
@preconcurrency import ImageCaptureCore
import FujiBackupCore

/// Finds a Fujifilm camera on USB and talks PTP to it through ImageCaptureCore.
/// Each operation runs in its own session: the camera refuses a read and a write in one session.
@MainActor @Observable
final class CameraLink: NSObject {
    enum State: Equatable {
        case searching
        case connecting(name: String)
        case wrongMode(name: String)
        case ready(DeviceInfo)
        case unavailable(name: String, reason: String)
    }

    private(set) var state: State = .searching
    private let browser = ICDeviceBrowser()
    private var camera: ICCameraDevice?
    private var transaction: UInt32 = 0
    private var openWaiter: CheckedContinuation<Void, Error>?
    private var closeWaiter: CheckedContinuation<Void, Never>?

    static let fujifilmVendorID = 0x04CB

    /// `watchUSB: false` never looks for cameras (debug demo mode), so it can't send anything to one.
    init(watchUSB: Bool = true) {
        super.init()
        browser.delegate = self
        browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: ICDeviceTypeMask.camera.rawValue | ICDeviceLocationTypeMask.local.rawValue)!
        if watchUSB { browser.start() }
    }

    var info: DeviceInfo? {
        if case let .ready(info) = state { info } else { nil }
    }

    #if DEBUG
    /// For screenshots: show a state without a camera.
    func demo(_ state: State) { self.state = state }
    #endif

    // MARK: Operations

    /// The camera's current settings backup, plus its device info.
    func readBackup() async throws -> (DeviceInfo, SettingsBackup) {
        try await withSession {
            let info = try await self.checkedInfo()
            _ = try await self.send(.getObjectInfo, params: [0])
            let data = try await self.send(.getObject, params: [0])
            return (info, try SettingsBackup(data))
        }
    }

    /// Writes a backup to the camera. The caller has already checked it against the camera's own backup.
    func writeBackup(_ backup: SettingsBackup) async throws {
        try await withSession {
            _ = try await self.checkedInfo()
            _ = try await self.send(.sendObjectInfo, params: [0, 0], out: PTP.backupObjectInfo(size: backup.data.count))
            _ = try await self.send(.sendObject, out: backup.data)
        }
    }

    /// Reads device info and USB mode, and updates `state`.
    func refresh() async {
        guard let camera else { state = .searching; return }
        let name = camera.name ?? "Camera"
        state = .connecting(name: name)
        do {
            _ = try await withSession { try await self.checkedInfo() }
        } catch LinkError.wrongMode {
            state = .wrongMode(name: name)
        } catch {
            state = .unavailable(name: name, reason: error.localizedDescription)
        }
    }

    // MARK: PTP

    private func checkedInfo() async throws -> DeviceInfo {
        guard let info = DeviceInfo(try await send(.getDeviceInfo)) else { throw LinkError.badReply }
        let mode = PTP.integerValue(try await send(.getDevicePropValue, params: [PTP.fujiUSBModeProperty]))
        guard mode == PTP.fujiUSBModeBackupRestore else { throw LinkError.wrongMode }
        state = .ready(info)
        return info
    }

    private func send(_ op: PTP.Op, params: [UInt32] = [], out: Data? = nil) async throws -> Data {
        guard let camera else { throw LinkError.noCamera }
        transaction &+= 1
        let command = PTP.command(op, transaction: transaction, params: params)
        let (data, response): (Data, Data) = try await withCheckedThrowingContinuation { c in
            camera.requestSendPTPCommand(command, outData: out) { data, response, error in
                if let error { c.resume(throwing: error) } else { c.resume(returning: (data, response)) }
            }
        }
        let code = PTP.responseCode(response)
        guard code == PTP.responseOK else { throw LinkError.refused(op: op, code: code) }
        return PTP.payload(data)
    }

    private func withSession<T>(_ body: () async throws -> T) async throws -> T {
        guard let camera else { throw LinkError.noCamera }
        if camera.hasOpenSession { await closeSession(camera) }
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            openWaiter = c
            camera.requestOpenSession()
        }
        transaction = 0
        do {
            let result = try await body()
            await closeSession(camera)
            return result
        } catch {
            await closeSession(camera)
            throw error
        }
    }

    private func closeSession(_ camera: ICCameraDevice) async {
        guard self.camera === camera, camera.hasOpenSession else { return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            closeWaiter = c
            camera.requestCloseSession()
        }
    }
}

enum LinkError: LocalizedError {
    case noCamera, wrongMode, badReply
    case refused(op: PTP.Op, code: UInt16?)

    var errorDescription: String? {
        switch self {
        case .noCamera: "The camera was disconnected."
        case .wrongMode: "The camera isn’t in backup mode."
        case .badReply: "The camera sent a reply this app doesn’t understand."
        case let .refused(op, code):
            switch code {
            case 0x200F: "The camera refused the request."
            case 0x2019: "The camera is busy."
            default: "The camera returned an error (\(String(describing: op)), code \(code.map { String(format: "0x%04X", $0) } ?? "none"))."
            }
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .wrongMode: "On the camera, choose SET UP › CONNECTION SETTING › PC CONNECTION MODE › USB RAW CONV./BACKUP RESTORE."
        case .refused(_, 0x200F): "Check the file is an unchanged backup from this camera. Then turn the camera off and on, and try again."
        default: "Make sure the camera is on and connected, then try again."
        }
    }
}

// MARK: ImageCaptureCore delegates (called on the main thread)

extension CameraLink: ICDeviceBrowserDelegate {
    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        MainActor.assumeIsolated {
            guard camera == nil, let cam = device as? ICCameraDevice, cam.usbVendorID == Self.fujifilmVendorID else { return }
            camera = cam
            cam.delegate = self
            Task { await refresh() }
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        MainActor.assumeIsolated {
            guard device === camera else { return }
            camera = nil
            openWaiter?.resume(throwing: LinkError.noCamera)
            openWaiter = nil
            closeWaiter?.resume()
            closeWaiter = nil
            state = .searching
        }
    }
}

extension CameraLink: ICCameraDeviceDelegate {
    nonisolated func device(_ device: ICDevice, didOpenSessionWithError error: (any Error)?) {
        MainActor.assumeIsolated {
            if let error { openWaiter?.resume(throwing: error) } else { openWaiter?.resume() }
            openWaiter = nil
        }
    }

    nonisolated func device(_ device: ICDevice, didCloseSessionWithError error: (any Error)?) {
        MainActor.assumeIsolated {
            closeWaiter?.resume()
            closeWaiter = nil
        }
    }
    nonisolated func didRemove(_ device: ICDevice) {}
    nonisolated func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {}
    nonisolated func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {}
    nonisolated func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem, error: (any Error)?) {}
    nonisolated func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable: Any]?, for item: ICCameraItem, error: (any Error)?) {}
    nonisolated func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}
    nonisolated func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}
    nonisolated func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {}
    nonisolated func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {}
    nonisolated func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {}
    nonisolated func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {}
}
