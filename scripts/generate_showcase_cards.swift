import Cocoa
import SwiftUI

let canvasWidth: CGFloat = 960
let canvasHeight: CGFloat = 600
let retinaScale: CGFloat = 2.0
let targetSize = CGSize(width: canvasWidth, height: canvasHeight)

// MARK: - Common Styles & Components

struct CardContainer<Content: View>: View {
    let category: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            // Dark Studio Gradient Background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.085, blue: 0.10),
                    Color(red: 0.05, green: 0.055, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Ambient glow
            RadialGradient(
                colors: [accentColor.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 40,
                endRadius: 460
            )

            VStack(spacing: 0) {
                // Top Header Pill
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accentColor)
                    Text(category)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("·")
                        .foregroundColor(Color.white.opacity(0.3))
                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.70))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color(white: 0.14).opacity(0.85))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
                .padding(.top, 22)

                Spacer(minLength: 10)

                // Main Showcase Stage
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 28)

            // Outer Card Border
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }
}

// MARK: - Card 1: Annotation Toolbar & Precision Loupe

struct Card1_AnnotationToolbar: View {
    var body: some View {
        CardContainer(
            category: "精准截图与放大镜取色",
            subtitle: "发丝级十字准星 · 8× 像素网格 · HEX/RGB 实时监视",
            iconName: "viewfinder",
            accentColor: Color(red: 0.25, green: 0.55, blue: 1.0)
        ) {
            ZStack {
                // Mock Browser / Code Window in Background
                VStack(alignment: .leading, spacing: 10) {
                    // Window title bar
                    HStack(spacing: 6) {
                        Circle().fill(Color.red.opacity(0.8)).frame(width: 10, height: 10)
                        Circle().fill(Color.yellow.opacity(0.8)).frame(width: 10, height: 10)
                        Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                        Spacer()
                        Text("developer.apple.com/documentation")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.35))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                    Divider().opacity(0.15)

                    // Mock page content
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay(Image(systemName: "sparkles").foregroundColor(.blue).font(.system(size: 20)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vision & Translation Frameworks")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("High-performance on-device machine intelligence for macOS")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.5))
                            }
                        }

                        // Code snippet block
                        VStack(alignment: .leading, spacing: 6) {
                            Text("func captureAndAnalyze(in region: CGRect) async throws -> Result {")
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundColor(Color(red: 0.9, green: 0.5, blue: 0.6))
                            Text("    let sample = try await ScreenCaptureKit.captureRegion(region)")
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.9))
                            Text("    let text = try await VisionOCR.recognizeText(sample)")
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundColor(Color(red: 0.6, green: 0.9, blue: 0.5))
                            Text("    return .success(text)")
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.4))
                            Text("}")
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.35))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .background(Color(white: 0.12).opacity(0.6))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 30)
                .offset(y: -25)

                // Selection Box over the code snippet
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.3, green: 0.65, blue: 1.0), lineWidth: 2)
                    .frame(width: 480, height: 160)
                    .offset(x: -40, y: -20)
                    .overlay(
                        // Dimensions tag
                        Text("480 × 160")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.15, green: 0.45, blue: 0.95))
                            .cornerRadius(4)
                            .offset(x: -280, y: -105)
                    )

                // Hairline Crosshair
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 1, height: 380)
                    Rectangle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 720, height: 1)
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                }
                .offset(x: 100, y: -40)

                // 8x Pixel Loupe Magnifier
                VStack(spacing: 6) {
                    // Pixel grid (11 x 11)
                    Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                        ForEach(0..<9) { row in
                            GridRow {
                                ForEach(0..<9) { col in
                                    Rectangle()
                                        .fill(
                                            row == 4 && col == 4 ? Color(red: 0.04, green: 0.52, blue: 1.0) :
                                            (row >= 3 && row <= 5 && col >= 3 && col <= 5 ? Color(red: 0.1, green: 0.4, blue: 0.85).opacity(0.85) :
                                            (row < 3 ? Color(white: 0.22) : Color(white: 0.15)))
                                        )
                                        .frame(width: 11, height: 11)
                                }
                            }
                        }
                    }
                    .overlay(
                        // Red center reticle
                        Rectangle()
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 13, height: 13)
                    )
                    .padding(5)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)

                    // Color inspection tag
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.04, green: 0.52, blue: 1.0))
                            .frame(width: 14, height: 14)
                        Text("#0A84FF")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Text("C: 复制色值 · Shift: 格式")
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.12).opacity(0.95))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.4), radius: 12, y: 6)
                )
                .offset(x: 230, y: -80)

                // Bottom Compact Annotation Toolbar
                HStack(spacing: 8) {
                    Image(systemName: "circle.grid.2x2.fill").font(.system(size: 11)).foregroundColor(Color.white.opacity(0.4))
                    Divider().frame(height: 16).opacity(0.2)

                    Group {
                        Image(systemName: "rectangle").foregroundColor(.white)
                        Image(systemName: "oval").foregroundColor(.white.opacity(0.7))
                        Image(systemName: "arrow.up.right").foregroundColor(.white.opacity(0.7))
                        Image(systemName: "line.diagonal").foregroundColor(.white.opacity(0.7))
                        Image(systemName: "pencil.tip").foregroundColor(.white.opacity(0.7))
                        Image(systemName: "highlighter").foregroundColor(.white.opacity(0.7))
                        Text("Aa").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.7))
                        Image(systemName: "checkerboard.rectangle").foregroundColor(.white.opacity(0.7))
                        Image(systemName: "1.circle").foregroundColor(.white.opacity(0.7))
                    }
                    .font(.system(size: 13))

                    Divider().frame(height: 16).opacity(0.2)
                    Image(systemName: "arrow.uturn.backward").foregroundColor(.white.opacity(0.7))
                    Image(systemName: "arrow.uturn.forward").foregroundColor(.white.opacity(0.7))

                    Divider().frame(height: 16).opacity(0.2)
                    Image(systemName: "xmark").foregroundColor(.white.opacity(0.7))
                    Image(systemName: "square.and.arrow.down").foregroundColor(.white.opacity(0.7))
                    Image(systemName: "pin").foregroundColor(.white.opacity(0.7))

                    // Emerald green Done button
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 28, height: 24)
                    .background(Color(red: 0.16, green: 0.65, blue: 0.40))
                    .cornerRadius(5)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.14).opacity(0.96))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.45), radius: 16, y: 8)
                )
                .offset(y: 155)
            }
        }
    }
}

// MARK: - Card 2: Vector Annotation Arsenal & Secondary Palette

struct Card2_AnnotationShowcase: View {
    var body: some View {
        CardContainer(
            category: "丰富矢量标注实战",
            subtitle: "箭头 · 矩形 · 荧光笔 · 敏感信息马赛克 · 步骤印章 ① ② ③",
            iconName: "pencil.and.outline",
            accentColor: Color(red: 0.95, green: 0.55, blue: 0.20)
        ) {
            ZStack {
                // Background Document / Design Spec
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "doc.text.fill").foregroundColor(.orange)
                        Text("Release_v1.2.0_Spec.md")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("Draft Approved")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    }

                    Divider().opacity(0.15)

                    // Text contents with integrated live annotations
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. Heading with Red Rectangle and Step 1 Badge and Arrow
                        HStack(spacing: 8) {
                            ZStack {
                                Circle().fill(Color.orange).frame(width: 20, height: 20)
                                Text("1").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            }
                            Text("Architecture Refactoring Overview")
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.red, lineWidth: 2)
                                )

                            Spacer()

                            HStack(spacing: 5) {
                                Image(systemName: "arrow.turn.right.up")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("核心架构")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }

                        Text("The text input replacement engine coordinates with WindowServer directly via localized event posting.")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.65))

                        // 2. Token Row with Step 2 Badge and Mosaic Desensitization
                        HStack(spacing: 8) {
                            ZStack {
                                Circle().fill(Color.orange).frame(width: 20, height: 20)
                                Text("2").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Token Authorization (马赛克脱敏):")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Color.white.opacity(0.5))

                                HStack(spacing: 3) {
                                    ForEach(0..<15) { idx in
                                        Rectangle()
                                            .fill(idx % 2 == 0 ? Color.white.opacity(0.5) : Color.white.opacity(0.3))
                                            .frame(width: 14, height: 14)
                                    }
                                }
                                .padding(4)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(4)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)

                        // 3. Highlighted sentence with Step 3 Badge
                        HStack(spacing: 8) {
                            ZStack {
                                Circle().fill(Color.orange).frame(width: 20, height: 20)
                                Text("3").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            }

                            Text("Pipeline performance improved by 320ms across Chromium and AppKit instances.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.yellow.opacity(0.35))
                                .cornerRadius(3)

                            Spacer()
                        }
                    }
                }
                .padding(20)
                .background(Color(white: 0.12).opacity(0.65))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .frame(width: 720)
                .offset(y: -40)

                // Floating Toolbar + Secondary Palette
                VStack(spacing: 8) {
                    // Primary Toolbar
                    HStack(spacing: 8) {
                        Image(systemName: "circle.grid.2x2.fill").font(.system(size: 11)).foregroundColor(Color.white.opacity(0.4))
                        Divider().frame(height: 16).opacity(0.2)

                        // Rectangle active
                        Image(systemName: "rectangle")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 24)
                            .background(Color.blue)
                            .cornerRadius(5)

                        Group {
                            Image(systemName: "oval")
                            Image(systemName: "arrow.up.right")
                            Image(systemName: "line.diagonal")
                            Image(systemName: "pencil.tip")
                            Image(systemName: "highlighter")
                            Text("Aa").font(.system(size: 12, weight: .bold))
                            Image(systemName: "checkerboard.rectangle")
                            Image(systemName: "1.circle")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.7))

                        Divider().frame(height: 16).opacity(0.2)
                        Image(systemName: "arrow.uturn.backward").foregroundColor(.white.opacity(0.7))
                        Image(systemName: "arrow.uturn.forward").foregroundColor(.white.opacity(0.7))
                        Divider().frame(height: 16).opacity(0.2)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .frame(width: 26, height: 24).background(Color(red: 0.16, green: 0.65, blue: 0.40)).cornerRadius(5)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.14).opacity(0.96))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 5)
                    )

                    // Secondary Color & Thickness Palette
                    HStack(spacing: 12) {
                        // Stroke thickness
                        HStack(spacing: 6) {
                            Circle().fill(Color.white.opacity(0.4)).frame(width: 3, height: 3)
                            Circle().fill(Color.white).frame(width: 6, height: 6)
                            Circle().fill(Color.white.opacity(0.4)).frame(width: 9, height: 9)
                        }

                        Divider().frame(height: 14).opacity(0.2)

                        // Color swatches
                        HStack(spacing: 8) {
                            Circle().fill(Color.red).frame(width: 14, height: 14)
                            Circle().fill(Color.orange).frame(width: 14, height: 14)
                            Circle().fill(Color.yellow).frame(width: 14, height: 14)
                            Circle().fill(Color.green).frame(width: 14, height: 14)
                            Circle().fill(Color.cyan).frame(width: 14, height: 14)
                            Circle().fill(Color.blue).frame(width: 14, height: 14).overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            Circle().fill(Color.purple).frame(width: 14, height: 14)
                            Circle().fill(Color.white).frame(width: 14, height: 14)
                        }

                        Divider().frame(height: 14).opacity(0.2)

                        Text("描边").font(.system(size: 10.5, weight: .semibold)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.16).opacity(0.96))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
                    )
                }
                .offset(y: 135)
            }
        }
    }
}

// MARK: - Card 3: Intelligent Scrolling Capture

struct Card3_ScrollingCapture: View {
    var body: some View {
        CardContainer(
            category: "长截图智能无缝拼接",
            subtitle: "向下滚动即拼 · 紧凑胶囊指示器 · 全景画卷高清预览",
            iconName: "arrow.up.and.down.and.sparkles",
            accentColor: Color(red: 0.35, green: 0.85, blue: 0.55)
        ) {
            ZStack {
                HStack(spacing: 24) {
                    // Left: Active Scrolling Capture Viewport
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text("网页与代码长幅连续截取")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("平滑捕获中...")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.06))

                        Divider().opacity(0.15)

                        // Scrolling content stream
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(1...5, id: \.self) { idx in
                                HStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: 28, height: 28)
                                        .overlay(Text("#\(idx)").font(.system(size: 10, weight: .bold)).foregroundColor(.cyan))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Section Block #\(idx): Continuous Flow Integration")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Sampling stripe correlation algorithm precisely calculates overlapping pixel rows.")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color.white.opacity(0.5))
                                    }
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(6)
                            }
                        }
                        .padding(14)

                        Spacer()

                        // Downward scroll pulse
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.compact.down")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.green.opacity(0.8))
                            Spacer()
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(width: 480, height: 350)
                    .background(Color(white: 0.12).opacity(0.75))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.5), lineWidth: 1.5)
                    )

                    // Right: Panorama Preview Roll (Full tall image preview)
                    VStack(spacing: 8) {
                        Text("全景微缩画卷预览")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.7))

                        // Tall preview roll
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(white: 0.15).opacity(0.9))
                                .frame(width: 140, height: 280)

                            VStack(spacing: 4) {
                                ForEach(0..<14) { _ in
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color.white.opacity(0.18))
                                        .frame(width: 120, height: 14)
                                }
                            }
                            .padding(.top, 8)

                            // Current active view indicator box
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.green, lineWidth: 2)
                                .frame(width: 128, height: 60)
                                .offset(y: 120)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )

                        Text("4,280 × 960 px")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(12)
                    .background(Color(white: 0.10).opacity(0.85))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .offset(y: -25)

                // Bottom Floating Status Capsule
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))
                        Text("长截图自动拼接中")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Divider().frame(height: 14).opacity(0.25)

                    Text("高度: 4,280 px · 18 帧")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.75))

                    // Emerald green Finish button
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("完成拼接")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.16, green: 0.65, blue: 0.40))
                    .cornerRadius(6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(white: 0.14).opacity(0.98))
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.45), radius: 14, y: 6)
                )
                .offset(x: -80, y: 155)
            }
        }
    }
}

// MARK: - Card 4: Safari-Style In-Place Screen Translation

struct Card4_InPlaceTranslation: View {
    var body: some View {
        CardContainer(
            category: "Safari 风格原地屏幕翻译",
            subtitle: "原地覆盖排版 · Apple / DeepSeek 引擎 · 原文/译文秒级无缝切换",
            iconName: "character.bubble",
            accentColor: Color(red: 0.65, green: 0.45, blue: 1.0)
        ) {
            ZStack {
                // Background Document Snippet
                VStack(alignment: .leading, spacing: 10) {
                    Text("Artificial Intelligence & Machine Vision")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Offline on-device inference delivers extreme privacy and low-latency interaction.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.5))

                    Divider().opacity(0.15)

                    // English Original Paragraph
                    Text("The translation engine leverages Apple Neural Engine hardware acceleration. It executes completely offline without network requests, ensuring enterprise compliance and absolute confidentiality.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.35))
                        .lineSpacing(4)
                }
                .padding(20)
                .background(Color(white: 0.11).opacity(0.6))
                .cornerRadius(12)
                .frame(width: 720)
                .offset(y: -40)

                // In-Situ Translation Floating HUD
                VStack(spacing: 0) {
                    // Top Toolbar
                    HStack(spacing: 8) {
                        // Segmented control [原文 | 译文]
                        HStack(spacing: 2) {
                            Text("原文")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.55))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                            Text("译文")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(5)

                        Divider().frame(height: 14).opacity(0.25)

                        // Language pair
                        HStack(spacing: 5) {
                            Text("自动 (英)")
                            Image(systemName: "arrow.left.arrow.right").font(.system(size: 9))
                            Text("中 (简体)")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(5)

                        Divider().frame(height: 14).opacity(0.25)

                        // Engine selector
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles").foregroundColor(.purple)
                            Text("DeepSeek AI")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(5)

                        Spacer()

                        // Copy button
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc").font(.system(size: 10.5))
                            Text("复制").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(5)

                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .padding(10)
                    .background(Color(white: 0.15).opacity(0.98))

                    Divider().opacity(0.2)

                    // Translated Content with Apple Intelligence Neon Glow Border
                    VStack(alignment: .leading, spacing: 8) {
                        Text("该翻译引擎深度调用 Apple 神经引擎（ANE）硬件加速。完全在本地离线运行，无需发起任何网络请求，全面保障企业级合规性与极致数据私密性。")
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundColor(.white)
                            .lineSpacing(5)

                        Divider().opacity(0.15)

                        HStack {
                            Text("↵ 替换 · Space 原文/译文 · Tab 换引擎 · ⌘C 复制 · ⎋ 关闭")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color.white.opacity(0.45))
                            Spacer()
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.12).opacity(0.96))
                }
                .frame(width: 580)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue, Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.purple.opacity(0.25), radius: 24, y: 10)
                .offset(y: 40)
            }
        }
    }
}

// MARK: - Card 5: Input Field Translation & Replacement

struct Card5_InputTranslate: View {
    var body: some View {
        CardContainer(
            category: "输入框就地翻译与替换",
            subtitle: "光标聚焦即译 · Enter 一键覆写替换 · 剪贴板自动保护还原",
            iconName: "character.cursor.ibeam",
            accentColor: Color(red: 0.20, green: 0.80, blue: 0.50)
        ) {
            ZStack {
                // Background Chat / Editor Environment
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Circle().fill(Color.blue).frame(width: 28, height: 28)
                            .overlay(Text("Alex").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alex Rivera (Product Manager)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text("Hey team, how is the internationalization feature progressing?")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)

                    // Target input box container
                    VStack(alignment: .leading, spacing: 6) {
                        Text("消息回复输入框 (聚焦中):")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.4))

                        HStack {
                            Text("这个功能我们已经在最新版本中优化完毕，请随时测试。")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                            Rectangle().fill(Color.blue).frame(width: 2, height: 16)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.5), lineWidth: 1.5))
                    }
                }
                .padding(24)
                .background(Color(white: 0.12).opacity(0.65))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .frame(width: 720)
                .offset(y: 40)

                // Floating Translation HUD positioned directly above the input field
                VStack(spacing: 0) {
                    // Top Toolbar
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("原文")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.55))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                            Text("译文")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(5)

                        Divider().frame(height: 14).opacity(0.25)

                        HStack(spacing: 4) {
                            Text("自动 (中)")
                            Image(systemName: "arrow.left.arrow.right").font(.system(size: 9))
                            Text("英 (English)")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(5)

                        Divider().frame(height: 14).opacity(0.25)

                        HStack(spacing: 4) {
                            Image(systemName: "sparkles").foregroundColor(.cyan)
                            Text("DeepSeek").font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                        }

                        Spacer()

                        // Emerald Green Replace Action Button
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.down.left")
                                .font(.system(size: 10, weight: .bold))
                            Text("替换 (↵)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(Color(red: 0.16, green: 0.65, blue: 0.40))
                        .cornerRadius(6)

                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .padding(9)
                    .background(Color(white: 0.15).opacity(0.98))

                    Divider().opacity(0.2)

                    // Content card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("We have already optimized this feature in the latest release, please feel free to test.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white)
                            .lineSpacing(4)

                        Divider().opacity(0.15)

                        HStack {
                            Text("↵ 替换输入框 · Space 原文/译文 · ⌘C 复制 · ⎋ 关闭")
                                .font(.system(size: 10))
                                .foregroundColor(Color.white.opacity(0.45))
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(Color(white: 0.12).opacity(0.96))
                }
                .frame(width: 560)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
                .offset(y: -85)
            }
        }
    }
}

// MARK: - Card 6: Desktop Floating Pin & Tactile Controls

struct Card6_HeroPin: View {
    var body: some View {
        CardContainer(
            category: "桌面贴图与多手势穿透",
            subtitle: "独立悬浮置顶 · 无级缩放透明度 · 鼠标穿透 (⌘L) · 文本代码卡片化",
            iconName: "pin.fill",
            accentColor: Color(red: 0.95, green: 0.40, blue: 0.65)
        ) {
            ZStack {
                // Pin #1: Syntax Highlighted Code Card (F3 文本卡片化)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Circle().fill(Color.yellow).frame(width: 8, height: 8)
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Spacer()
                        Text("Hotkeys.swift (置顶贴图)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    Divider().opacity(0.15)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("import Cocoa\nimport SwiftUI")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.pink)
                        Text("\npublic final class PinWindowManager {")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.cyan)
                        Text("    public static let shared = PinWindowManager()")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.green)
                        Text("    // ⌘L 开启鼠标事件穿透")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.gray)
                        Text("    self.ignoresMouseEvents = true")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.yellow)
                        Text("}")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.cyan)
                    }
                }
                .padding(14)
                .frame(width: 320, height: 210)
                .background(Color(white: 0.13).opacity(0.92))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.35), radius: 14, y: 6)
                .offset(x: -240, y: -20)

                // Pin #2: Pinned Image with Cascading Right-Click Context Menu
                ZStack(alignment: .topTrailing) {
                    // Pinned image background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 360, height: 240)
                        .overlay(
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Color.white.opacity(0.4))
                                Text("SnipSnap 置顶参考图")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                                Text("置顶悬浮在任意全屏工作区\n快捷右键唤起属性与图像变换")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineSpacing(2)
                            }
                            .padding(.leading, 22),
                            alignment: .leading
                        )
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                        .shadow(color: Color.blue.opacity(0.2), radius: 20, y: 8)

                    // Native-style Context Menu
                    VStack(alignment: .leading, spacing: 4) {
                        Text("翻译").font(.system(size: 11.5)).foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 3)
                        Text("标注贴图").font(.system(size: 11.5)).foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 3)
                        
                        // Active item: 图像变换
                        HStack {
                            Text("图像变换")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 9))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3.5)
                        .background(Color.blue)
                        .cornerRadius(4)

                        HStack {
                            Text("窗口透明度")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 9))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)

                        HStack {
                            Text("鼠标点击穿透")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white)
                            Spacer()
                            Text("⌘L").font(.system(size: 10, design: .monospaced)).foregroundColor(Color.white.opacity(0.5))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)

                        Divider().opacity(0.2)

                        HStack {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                            Text("切换悬浮阴影")
                        }
                        .font(.system(size: 11.5))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)

                        Divider().opacity(0.2)

                        HStack {
                            Text("复制图片")
                            Spacer()
                            Text("⌘C").font(.system(size: 10, design: .monospaced)).foregroundColor(Color.white.opacity(0.5))
                        }
                        .font(.system(size: 11.5))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)

                        HStack {
                            Text("关闭贴图")
                            Spacer()
                            Text("⌘W").font(.system(size: 10, design: .monospaced)).foregroundColor(Color.white.opacity(0.5))
                        }
                        .font(.system(size: 11.5))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                    }
                    .padding(6)
                    .frame(width: 175)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.18).opacity(0.98))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.4), radius: 14, y: 6)
                    )
                    .offset(x: 35, y: 15)
                }
                .offset(x: 150, y: -20)

                // Bottom gesture hints
                HStack(spacing: 16) {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.draw").foregroundColor(.pink)
                        Text("双指捏合 / 滚轮: 10%–800% 缩放")
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3").foregroundColor(.cyan)
                        Text("数字键 1–9: 调节透明度")
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "cursorarrow.rays").foregroundColor(.green)
                        Text("⌘L: 鼠标穿透锁定")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(white: 0.12).opacity(0.85))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
                .offset(y: 155)
            }
        }
    }
}

// MARK: - Renderer Function

func renderCard<V: View>(_ view: V, to filename: String) throws {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(origin: .zero, size: targetSize)
    hostingView.layoutSubtreeIfNeeded()

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasWidth * retinaScale),
        pixelsHigh: Int(canvasHeight * retinaScale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap rep for \(filename)")
    }
    rep.size = targetSize

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Failed to create graphics context for \(filename)")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    hostingView.displayIgnoringOpacity(hostingView.bounds, in: ctx)
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to get PNG data for \(filename)")
    }

    let destURL = URL(fileURLWithPath: "docs/images/\(filename)")
    try pngData.write(to: destURL)
    print("✅ Rendered docs/images/\(filename) (\(rep.pixelsWide)x\(rep.pixelsHigh), \(pngData.count / 1024) KB)")
}

// MARK: - Execute All 6 Cards

print("🎨 Starting high-resolution showcase image rendering...")

try renderCard(Card1_AnnotationToolbar(), to: "annotation_toolbar.png")
try renderCard(Card2_AnnotationShowcase(), to: "annotation_showcase.png")
try renderCard(Card3_ScrollingCapture(), to: "scrolling_capture.png")
try renderCard(Card4_InPlaceTranslation(), to: "inplace_translation.png")
try renderCard(Card5_InputTranslate(), to: "input_translate.png")
try renderCard(Card6_HeroPin(), to: "hero_pin.png")

print("🎉 All 6 showcase images successfully generated!")
