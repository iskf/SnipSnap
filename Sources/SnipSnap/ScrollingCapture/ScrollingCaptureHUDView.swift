import Cocoa
import SwiftUI

public class ScrollingCaptureViewModel: ObservableObject, @unchecked Sendable {
    @Published public var totalPixels: Int = 0
    @Published public var frameCount: Int = 0
    @Published public var thumbnail: NSImage? = nil
    @Published public var isCompleted: Bool = false
    @Published public var statusMessage: String = "请手动滑动页面..."
    @Published public var segmentCount: Int = 1
    
    // Bidirectional & Viewport Tracking
    @Published public var scrollDirection: ScrollDirection = .idle
    @Published public var viewportProgress: Double = 0.0 // 0.0 (top) ... 1.0 (bottom)
    @Published public var viewportRatio: Double = 1.0    // Viewport height relative to canvas height
    
    // Adaptive Theme Sensing
    @Published public var isLightBackground: Bool = false
    
    public var onFinish: (() -> Void)?
    public var onCancel: (() -> Void)?
    
    public init() {}
}

public struct ScrollingCaptureHUDView: View {
    @ObservedObject public var viewModel: ScrollingCaptureViewModel
    
    public init(viewModel: ScrollingCaptureViewModel) {
        self.viewModel = viewModel
    }
    
    private var isLight: Bool {
        viewModel.isLightBackground
    }
    
    // Adaptive theme tokens
    private var primaryTextColor: Color {
        isLight ? Color(white: 0.12) : .white
    }
    
    private var secondaryTextColor: Color {
        isLight ? Color(white: 0.45) : Color.white.opacity(0.6)
    }
    
    private var accentColor: Color {
        isLight ? Color(red: 0.0, green: 0.45, blue: 0.90) : .cyan
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header: Status indicator & Pixel Counter & Direction
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isCompleted ? Color.green : (viewModel.scrollDirection == .up ? Color.purple : accentColor))
                    .frame(width: 7, height: 7)
                    .shadow(color: (viewModel.isCompleted ? Color.green : accentColor).opacity(0.4), radius: 2)
                
                Text(L10n("scroll.hud.title"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                
                // Direction Badge
                if !viewModel.isCompleted {
                    directionBadge
                }
                
                Spacer()
                
                Text("\(viewModel.totalPixels) px")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.isCompleted ? .green : accentColor)
            }
            .padding(.horizontal, 2)
            
            // Limit warning badge if approaching 16k px
            if viewModel.totalPixels >= 14000 && !viewModel.isCompleted {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text(L10n("scroll.hud.segment_warn"))
                        .font(.system(size: 9))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
            
            // Mini-Map Preview Box with Live Viewport Navigator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isLight ? Color(white: 0.93) : Color.black.opacity(0.50))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                if let thumb = viewModel.thumbnail {
                    ZStack(alignment: .top) {
                        Image(nsImage: thumb)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                        
                        // Minimap Viewport Navigator Box
                        if !viewModel.isCompleted {
                            GeometryReader { geo in
                                let totalH = geo.size.height
                                let boxY = totalH * CGFloat(viewModel.viewportProgress)
                                let boxH = max(16.0, totalH * CGFloat(viewModel.viewportRatio))
                                
                                let strokeCol = isLight ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.cyan.opacity(0.9)
                                let fillCol = isLight ? Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.22) : Color.cyan.opacity(0.20)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(strokeCol, lineWidth: 1.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(fillCol)
                                    )
                                    .shadow(color: Color.black.opacity(isLight ? 0.15 : 0.3), radius: 2, y: 1)
                                    .frame(width: geo.size.width - 4, height: min(boxH, totalH))
                                    .offset(x: 2, y: min(boxY, max(0, totalH - boxH)))
                                    .animation(.easeOut(duration: 0.08), value: viewModel.viewportProgress)
                            }
                        }
                    }
                    .frame(height: 180)
                    .cornerRadius(6)
                    .padding(3)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 18))
                            .foregroundColor(secondaryTextColor)
                        Text("上下滑动页面拼接")
                            .font(.system(size: 10))
                            .foregroundColor(secondaryTextColor)
                    }
                    .frame(height: 140)
                }
                
                // Completed Badge
                if viewModel.isCompleted {
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text(viewModel.segmentCount > 1 ? L10n("scroll.hud.copied_segments") : L10n("scroll.hud.copied"))
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Color.green.opacity(0.9)))
                        .shadow(radius: 4)
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(width: 146)
            
            // Frame info & Segment indicator
            HStack {
                Text("已拼接 \(viewModel.frameCount) 帧")
                    .font(.system(size: 10))
                    .foregroundColor(secondaryTextColor)
                Spacer()
                if viewModel.totalPixels > 16000 {
                    Text("分段: \(max(1, (viewModel.totalPixels + 15999) / 16000))")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(accentColor)
                }
            }
            .padding(.horizontal, 2)
            
            Divider().opacity(isLight ? 0.15 : 0.3)
            
            // Actions: Finish (Enter) & Cancel (Esc)
            HStack(spacing: 6) {
                // Finish Button (Primary, Emerald Green, No Blue Focus Halo)
                HUDActionButton(
                    icon: "checkmark",
                    text: L10n("scroll.hud.finish"),
                    isPrimary: true,
                    isLightMode: isLight,
                    action: { viewModel.onFinish?() }
                )
                .help("完成并复制 (Enter)")
                
                // Cancel Button (Adaptive Gray, No Blue Focus Halo)
                HUDActionButton(
                    icon: "xmark",
                    text: nil,
                    isPrimary: false,
                    isLightMode: isLight,
                    action: { viewModel.onCancel?() }
                )
                .help(L10n("scroll.hud.cancel"))
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isLight ? Color.white.opacity(0.96) : Color(white: 0.14).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(isLight ? 0.12 : 0.45),
                    radius: 14,
                    x: 0,
                    y: isLight ? 5 : 6
                )
        )
        .frame(width: 164)
    }
    
    @ViewBuilder
    private var directionBadge: some View {
        switch viewModel.scrollDirection {
        case .down:
            HStack(spacing: 1.5) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .bold))
                Text("向下")
                    .font(.system(size: 8.5, weight: .medium))
            }
            .foregroundColor(isLight ? Color(red: 0.0, green: 0.45, blue: 0.90) : .cyan)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                Capsule().fill((isLight ? Color(red: 0.0, green: 0.45, blue: 0.90) : Color.cyan).opacity(isLight ? 0.12 : 0.25))
            )
        case .up:
            HStack(spacing: 1.5) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8, weight: .bold))
                Text("向上")
                    .font(.system(size: 8.5, weight: .medium))
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(Color.purple.opacity(isLight ? 0.12 : 0.3)))
        case .idle:
            HStack(spacing: 1.5) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 7.5))
                Text("视口")
                    .font(.system(size: 8.5))
            }
            .foregroundColor(secondaryTextColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.12)))
        }
    }
}

// MARK: - Custom Glassmorphic HUD Action Button (No Focus Halo)

private struct HUDActionButton: View {
    let icon: String
    let text: String?
    let isPrimary: Bool
    let isLightMode: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                if let t = text {
                    Text(t)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, text != nil ? 10 : 7)
            .frame(height: 25)
            .frame(maxWidth: text != nil ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 0.8)
            )
            .shadow(color: isPrimary ? Color.black.opacity(0.2) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
    }
    
    private var foregroundColor: Color {
        if isPrimary {
            return .white
        } else {
            return isLightMode ? Color(white: 0.25) : .white
        }
    }
    
    private var backgroundColor: Color {
        if isPrimary {
            return isHovered ? Color(red: 0.16, green: 0.74, blue: 0.46) : Color(red: 0.14, green: 0.65, blue: 0.40)
        } else {
            if isLightMode {
                return isHovered ? Color(white: 0.82) : Color(white: 0.89)
            } else {
                return isHovered ? Color.white.opacity(0.22) : Color.white.opacity(0.12)
            }
        }
    }
    
    private var borderColor: Color {
        if isPrimary {
            return Color.white.opacity(0.25)
        } else {
            return isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.15)
        }
    }
}
