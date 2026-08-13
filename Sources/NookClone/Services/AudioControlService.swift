import AppKit
import AudioToolbox
import CoreAudio
import Observation

struct AudioOutputDevice: Identifiable, Equatable, Sendable {
    let id: AudioDeviceID
    let name: String
}

@MainActor
@Observable
final class AudioControlService {
    private(set) var devices: [AudioOutputDevice] = []
    private(set) var selectedDeviceID: AudioDeviceID = 0
    private(set) var volume: Double = 0
    private(set) var isMuted = false
    private(set) var errorMessage: String?

    init() { refresh() }

    func refresh() {
        guard let defaultID = defaultOutputDevice() else { errorMessage = "Audio output is unavailable."; return }
        selectedDeviceID = defaultID
        devices = allOutputDevices()
        volume = Double(readVolume(device: defaultID) ?? 0)
        isMuted = readMute(device: defaultID) ?? false
        errorMessage = nil
    }

    func select(_ id: AudioDeviceID) {
        var mutableID = id
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let outputResult = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout.size(ofValue: mutableID)), &mutableID)
        address.mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice
        let systemResult = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout.size(ofValue: mutableID)), &mutableID)
        if outputResult == noErr || systemResult == noErr { refresh() } else { errorMessage = "The audio output could not be changed." }
    }

    func setVolume(_ value: Double) {
        var scalar = Float32(min(max(value, 0), 1))
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        let result = AudioObjectSetPropertyData(selectedDeviceID, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: scalar)), &scalar)
        if result == noErr { volume = Double(scalar); errorMessage = nil } else { errorMessage = "This device did not accept the volume command." }
    }

    func toggleMute() {
        var mute: UInt32 = isMuted ? 0 : 1
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        let result = AudioObjectSetPropertyData(selectedDeviceID, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: mute)), &mute)
        if result == noErr { isMuted = mute != 0; errorMessage = nil } else { errorMessage = "This device did not accept the mute command." }
    }

    func openSoundSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!)
    }

    private func defaultOutputDevice() -> AudioDeviceID? {
        var id = AudioDeviceID(0), size = UInt32(MemoryLayout.size(ofValue: id))
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr ? id : nil
    }

    private func allOutputDevices() -> [AudioOutputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var streamsAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streamsAddress, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
            return deviceName(id).map { AudioOutputDevice(id: id, name: $0) }
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func deviceName(_ id: AudioDeviceID) -> String? {
        var name: Unmanaged<CFString>?, size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeUnretainedValue() as String?
    }

    private func readVolume(device: AudioDeviceID) -> Float32? {
        var value: Float32 = 0, size = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private func readMute(device: AudioDeviceID) -> Bool? {
        var value: UInt32 = 0, size = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value != 0 : nil
    }
}
