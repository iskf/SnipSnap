import Cocoa
import SwiftUI

public struct HotkeyRecorderView: View {
    public let title: String
    public let actionId: String
    @Binding public var shortcut: String
    public let config: AppConfig
    public let onChanged: (String) -> Void
    
    @State private var isRecording: Bool = false
    @State private var conflictMessage: String? = nil
    @State private var localMonitor: Any? = nil
    
    public init(
        title: String,
        actionId: String,
        shortcut: Binding<String>,
        config: AppConfig,
        onChanged: @escaping (String) -> Void
    ) {
        self.title = title
        self.actionId = actionId
        self._shortcut = shortcut
        self.config = config
        self.onChanged = onChanged
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                
                Spacer()
                
                // Recorder Button
                Button(action: toggleRecording) {
                    HStack(spacing: 5) {
                        if isRecording {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                            Text("按下新按键...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentColor)
                        } else if shortcut.isEmpty {
                            Text("点击设置快捷键")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            keyCapsView(for: shortcut)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .frame(minHeight: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isRecording ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(
                                conflictMessage != nil ? Color.red : (isRecording ? Color.accentColor : Color.primary.opacity(0.15)),
                                lineWidth: (isRecording || conflictMessage != nil) ? 1.5 : 0.8
                            )
                    )
                }
                .buttonStyle(.plain)
                
                // Clear button
                if !shortcut.isEmpty && !isRecording {
                    Button(action: {
                        shortcut = ""
                        conflictMessage = nil
                        onChanged("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("清除快捷键")
                }
            }
            
            // Conflict Warning Banner
            if let conflict = conflictMessage {
                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text("与「\(conflict)」快捷键冲突，请更换按键")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.red)
                }
                .transition(.opacity)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func keyCapsView(for keyString: String) -> some View {
        HStack(spacing: 3) {
            ForEach(splitKeyString(keyString), id: \.self) { part in
                Text(part)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                    .foregroundColor(.primary)
                    .cornerRadius(3.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            }
        }
    }
    
    private func splitKeyString(_ str: String) -> [String] {
        var parts: [String] = []
        var remaining = str
        
        for modifier in ["⌃", "⌥", "⇧", "⌘"] {
            if remaining.contains(modifier) {
                parts.append(modifier)
                remaining = remaining.replacingOccurrences(of: modifier, with: "")
            }
        }
        if !remaining.isEmpty {
            parts.append(remaining)
        }
        return parts
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        conflictMessage = nil
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            // Escape cancels
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            // Delete / Backspace clears
            if event.keyCode == 51 {
                shortcut = ""
                conflictMessage = nil
                onChanged("")
                stopRecording()
                return nil
            }
            
            if let parsed = parseKeyEvent(event) {
                // Check conflict
                if let conflictingAction = config.checkConflict(for: parsed, actionIdentifier: actionId) {
                    conflictMessage = conflictingAction
                    NSSound(named: "Basso")?.play()
                } else {
                    conflictMessage = nil
                    shortcut = parsed
                    onChanged(parsed)
                    NSSound(named: "Pop")?.play()
                    stopRecording()
                }
                return nil
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func parseKeyEvent(_ event: NSEvent) -> String? {
        var modifierStr = ""
        if event.modifierFlags.contains(.control) { modifierStr += "⌃" }
        if event.modifierFlags.contains(.option) { modifierStr += "⌥" }
        if event.modifierFlags.contains(.shift) { modifierStr += "⇧" }
        if event.modifierFlags.contains(.command) { modifierStr += "⌘" }
        
        let keyStr: String
        switch event.keyCode {
        case 122: keyStr = "F1"
        case 120: keyStr = "F2"
        case 99:  keyStr = "F3"
        case 118: keyStr = "F4"
        case 96:  keyStr = "F5"
        case 97:  keyStr = "F6"
        case 98:  keyStr = "F7"
        case 100: keyStr = "F8"
        case 101: keyStr = "F9"
        case 109: keyStr = "F10"
        case 103: keyStr = "F11"
        case 111: keyStr = "F12"
        case 49:  keyStr = "Space"
        case 123: keyStr = "←"
        case 124: keyStr = "→"
        case 125: keyStr = "↓"
        case 126: keyStr = "↑"
        case 36:  keyStr = "↩"
        default:
            guard let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty else {
                return nil
            }
            keyStr = chars
        }
        
        // Single letter without modifier not allowed as global hotkey
        let isFunctionKey = keyStr.hasPrefix("F") && keyStr.count >= 2
        if modifierStr.isEmpty && !isFunctionKey {
            return nil
        }
        
        return modifierStr + keyStr
    }
}
