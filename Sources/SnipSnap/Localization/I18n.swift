import Foundation
import Combine
import SwiftUI

// MARK: - Supported Languages

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zhHans"
    case en = "en"
    case ja = "ja"
    case ko = "ko"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .system:
            switch I18n.resolveSystemLanguage() {
            case .zhHans: return "跟随系统 (简体中文)"
            case .ja: return "跟随系统 (日本語)"
            case .ko: return "跟随系统 (한국어)"
            default: return "Follow System (English)"
            }
        case .zhHans: return "简体中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }
}

// MARK: - Reactive Internationalization Manager

public class I18n: ObservableObject {
    public static let shared = I18n()
    
    public static let languageDidChangeNotification = Notification.Name("SnipSnapLanguageDidChange")
    
    @Published public var currentLanguage: AppLanguage = .system {
        didSet {
            NotificationCenter.default.post(name: I18n.languageDidChangeNotification, object: currentLanguage)
        }
    }
    
    public init() {
        let saved = AppConfig.load().language
        self.currentLanguage = AppLanguage(rawValue: saved) ?? .system
    }
    
    public var resolvedLanguage: AppLanguage {
        if currentLanguage == .system {
            return Self.resolveSystemLanguage()
        }
        return currentLanguage
    }
    
    public static func resolveSystemLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("zh") {
            return .zhHans
        } else if preferred.hasPrefix("ja") {
            return .ja
        } else if preferred.hasPrefix("ko") {
            return .ko
        } else {
            return .en
        }
    }
    
    public func setLanguage(_ lang: AppLanguage) {
        self.currentLanguage = lang
        var config = AppConfig.load()
        config.language = lang.rawValue
        config.save()
    }
    
    // MARK: - Dictionary Lookup
    
    public func t(_ key: String) -> String {
        let lang = resolvedLanguage
        if let dict = translations[key], let val = dict[lang] {
            return val
        }
        // Fallback to English, then Simplified Chinese
        if let dict = translations[key] {
            return dict[.en] ?? dict[.zhHans] ?? key
        }
        return key
    }
    
    // MARK: - Complete Translation Table
    
    private let translations: [String: [AppLanguage: String]] = [
        // Menu Bar Items
        "menu.screenshot": [
            .zhHans: "屏幕截图",
            .en: "Screen Capture",
            .ja: "画面キャプチャ",
            .ko: "화면 캡처"
        ],
        "menu.pin_clipboard": [
            .zhHans: "剪贴板贴图",
            .en: "Pin Clipboard",
            .ja: "クリップボードをピン留め",
            .ko: "클립보드 고정"
        ],
        "menu.selection_translate": [
            .zhHans: "选区翻译",
            .en: "Selection Translation",
            .ja: "選択範囲の翻訳",
            .ko: "선택 영역 번역"
        ],
        "menu.scroll_capture": [
            .zhHans: "长截图",
            .en: "Scrolling Capture",
            .ja: "スクロールキャプチャ",
            .ko: "스크롤 캡처"
        ],
        "menu.hide_all_pins": [
            .zhHans: "隐藏所有贴图",
            .en: "Hide All Pins",
            .ja: "すべてのピンを隠す",
            .ko: "모든 고정 숨기기"
        ],
        "menu.show_all_pins": [
            .zhHans: "显示所有贴图",
            .en: "Show All Pins",
            .ja: "すべてのピンを表示",
            .ko: "모든 고정 표시"
        ],
        "menu.unlock_all_pins": [
            .zhHans: "解锁所有穿透贴图",
            .en: "Unlock Click-Through Pins",
            .ja: "クリックスルーピンを解除",
            .ko: "클릭 관통 고정 해제"
        ],
        "menu.close_all_pins": [
            .zhHans: "关闭所有贴图",
            .en: "Close All Pins",
            .ja: "すべてのピンを閉じる",
            .ko: "모든 고정 닫기"
        ],
        "menu.preferences": [
            .zhHans: "偏好设置...",
            .en: "Preferences...",
            .ja: "環境設定...",
            .ko: "환경설정..."
        ],
        "menu.check_updates": [
            .zhHans: "检查更新...",
            .en: "Check for Updates...",
            .ja: "アップデートを確認...",
            .ko: "업데이트 확인..."
        ],
        "menu.quit": [
            .zhHans: "退出 SnipSnap",
            .en: "Quit SnipSnap",
            .ja: "SnipSnap を終了",
            .ko: "SnipSnap 종료"
        ],
        "menu.tooltip": [
            .zhHans: "SnipSnap - 原生截图与极致贴图",
            .en: "SnipSnap - Native Screenshot & Pinning",
            .ja: "SnipSnap - ネイティブキャプチャとピン留め",
            .ko: "SnipSnap - 네이티브 화면 캡처 및 고정"
        ],
        
        // Preferences Window Tabs
        "pref.title": [
            .zhHans: "偏好设置",
            .en: "Preferences",
            .ja: "環境設定",
            .ko: "환경설정"
        ],
        "pref.tab.general": [
            .zhHans: "通用设置",
            .en: "General",
            .ja: "一般設定",
            .ko: "일반 설정"
        ],
        "pref.tab.hotkeys": [
            .zhHans: "快捷键",
            .en: "Hotkeys",
            .ja: "ショートカット",
            .ko: "단축키"
        ],
        "pref.tab.capture": [
            .zhHans: "截图与标注",
            .en: "Capture & Annotation",
            .ja: "キャプチャと注釈",
            .ko: "캡처 및 주석"
        ],
        "pref.tab.pinning": [
            .zhHans: "贴图设置",
            .en: "Pinning",
            .ja: "ピン留め設定",
            .ko: "고정 설정"
        ],
        "pref.tab.ocr": [
            .zhHans: "离线识别与翻译",
            .en: "OCR & Translation",
            .ja: "OCR と翻訳",
            .ko: "OCR 및 번역"
        ],
        "pref.tab.recording": [
            .zhHans: "动图录制",
            .en: "GIF Recording",
            .ja: "GIF録画",
            .ko: "GIF 녹화"
        ],
        "pref.tab.about": [
            .zhHans: "关于",
            .en: "About",
            .ja: "情報",
            .ko: "정보"
        ],
        "pref.recording.quality_group": [
            .zhHans: "画质与性能",
            .en: "Quality & Performance",
            .ja: "画質とパフォーマンス",
            .ko: "화질 및 성능"
        ],
        "pref.recording.fps": [
            .zhHans: "录制帧率",
            .en: "Frame Rate",
            .ja: "フレームレート",
            .ko: "프레임 레이트"
        ],
        "pref.recording.fps_desc": [
            .zhHans: "推荐 15 FPS，在动效平滑度与生成体积间取得最佳平衡。",
            .en: "15 FPS recommended for optimal balance between smoothness and size.",
            .ja: "スムーズさとファイルサイズの最適なバランスに15 FPSを推奨します。",
            .ko: "부드러움과 파일 크기의 최적 균형을 위해 15 FPS를 권장합니다."
        ],
        "pref.recording.downsample": [
            .zhHans: "Retina 屏幕 1x 智能降采样",
            .en: "Retina 1x Smart Downsampling",
            .ja: "Retina 1x スマート縮小",
            .ko: "Retina 1x 스마트 다운샘플링"
        ],
        "pref.recording.downsample_desc": [
            .zhHans: "将高分屏像素密度缩放至 1x，防止生成数十 MB 的膨胀动图。",
            .en: "Scale down Retina pixels to 1x to avoid generating bloated GIF files.",
            .ja: "巨大なGIFファイルの生成を防ぐため、Retinaピクセルを1xに縮小します。",
            .ko: "거대한 GIF 생성을 방지하기 위해 Retina 픽셀을 1x로 축소합니다."
        ],
        "pref.recording.control_group": [
            .zhHans: "捕获控制与时长",
            .en: "Capture & Duration",
            .ja: "キャプチャ制御と時間",
            .ko: "캡처 제어 및 시간"
        ],
        "pref.recording.duration": [
            .zhHans: "最大录制时长",
            .en: "Max Duration",
            .ja: "最大録画時間",
            .ko: "최대 녹화 시간"
        ],
        "pref.recording.cursor": [
            .zhHans: "捕获鼠标光标",
            .en: "Capture Mouse Cursor",
            .ja: "マウスカーソルを含める",
            .ko: "마우스 커서 포함"
        ],
        "pref.recording.cursor_desc": [
            .zhHans: "在动图中包含鼠标光标轨迹，方便操作步骤指引与演示。",
            .en: "Include mouse cursor trajectory in the recorded GIF.",
            .ja: "操作手順をわかりやすくするため、カーソル軌跡を表示します。",
            .ko: "작업 단계를 쉽게 시연하기 위해 마우스 커서 궤적을 포함합니다."
        ],
        "pref.recording.output_group": [
            .zhHans: "输出与交付",
            .en: "Export & Delivery",
            .ja: "エクスポートと出力",
            .ko: "내보내기 및 전달"
        ],
        "pref.recording.autocopy": [
            .zhHans: "录制完成后自动写入剪贴板",
            .en: "Auto-Copy GIF to Clipboard on Finish",
            .ja: "完了時にクリップボードへ自動コピー",
            .ko: "완료 시 클립보드에 자동 복사"
        ],
        "pref.recording.autosave": [
            .zhHans: "同时自动保存到默认文件夹",
            .en: "Auto-Save to Default Folder",
            .ja: "デフォルトフォルダにも自動保存",
            .ko: "기본 폴더에도 자동 저장"
        ],
        "pref.recording.playsound": [
            .zhHans: "录制完成播放提示音",
            .en: "Play Sound on Finish",
            .ja: "完了時にサウンドを再生",
            .ko: "완료 시 효과음 재생"
        ],
        "common.recommended": [
            .zhHans: "推荐",
            .en: "Recommended",
            .ja: "推奨",
            .ko: "권장"
        ],
        
        // General Tab
        "pref.general.lang_card": [
            .zhHans: "界面语言",
            .en: "Interface Language",
            .ja: "表示言語",
            .ko: "인터페이스 언어"
        ],
        "pref.general.lang_label": [
            .zhHans: "应用语言",
            .en: "Application Language",
            .ja: "言語",
            .ko: "애플리케이션 언어"
        ],
        "pref.general.system_card": [
            .zhHans: "启动与系统",
            .en: "Startup & System",
            .ja: "起動とシステム",
            .ko: "시작 및 시스템"
        ],
        "pref.general.launch_at_login": [
            .zhHans: "登录时自动启动 SnipSnap",
            .en: "Launch SnipSnap at login",
            .ja: "ログイン時に SnipSnap を自動起動",
            .ko: "로그인 시 SnipSnap 자동 실행"
        ],
        "pref.general.monochrome_icon": [
            .zhHans: "菜单栏使用极简单色图标",
            .en: "Use monochrome menu bar icon",
            .ja: "メニューバーにモノクロアイコンを使用",
            .ko: "메뉴 막대 단색 아이콘 사용"
        ],
        "pref.general.sound_effect": [
            .zhHans: "截图与复制成功后播放清脆提示音 (Tink)",
            .en: "Play sound effect after capture & copy (Tink)",
            .ja: "キャプチャとコピー成功時に効果音を再生 (Tink)",
            .ko: "캡처 및 복사 성공 시 효과음 재생 (Tink)"
        ],
        "pref.general.storage_card": [
            .zhHans: "存储与保存规则",
            .en: "Storage & Save Rules",
            .ja: "保存ルール",
            .ko: "저장 규칙"
        ],
        "pref.general.default_path": [
            .zhHans: "默认保存目录",
            .en: "Default Save Directory",
            .ja: "デフォルトの保存先",
            .ko: "기본 저장 경로"
        ],
        "pref.general.change_dir": [
            .zhHans: "更改目录...",
            .en: "Change...",
            .ja: "変更...",
            .ko: "변경..."
        ],
        "pref.general.desktop": [
            .zhHans: "桌面",
            .en: "Desktop",
            .ja: "デスクトップ",
            .ko: "데스크탑"
        ],
        "pref.general.choose_panel_title": [
            .zhHans: "选择默认截图存储文件夹",
            .en: "Select Default Screenshot Folder",
            .ja: "デフォルトの保存先フォルダを選択",
            .ko: "기본 스크린샷 저장 폴더 선택"
        ],
        "pref.general.choose_panel_btn": [
            .zhHans: "选择",
            .en: "Select",
            .ja: "選択",
            .ko: "선택"
        ],
        "pref.general.format": [
            .zhHans: "图片保存格式",
            .en: "Image Format",
            .ja: "画像形式",
            .ko: "이미지 형식"
        ],
        "pref.general.auto_save": [
            .zhHans: "截图完成后自动保存到默认文件夹",
            .en: "Auto-save screenshot to default folder",
            .ja: "完了時にデフォルトフォルダへ自動保存",
            .ko: "캡처 후 기본 폴더로 자동 저장"
        ],
        "pref.general.auto_copy": [
            .zhHans: "截图完成后自动复制到系统剪贴板",
            .en: "Auto-copy screenshot to clipboard",
            .ja: "完了時にクリップボードへ自動コピー",
            .ko: "캡처 후 클립보드로 자동 복사"
        ],
        "pref.general.reset_card": [
            .zhHans: "配置重置",
            .en: "Reset Configuration",
            .ja: "設定のリセット",
            .ko: "설정 초기화"
        ],
        "pref.general.reset_title": [
            .zhHans: "恢复出厂默认设置",
            .en: "Restore Factory Defaults",
            .ja: "工場出荷時のデフォルトに戻す",
            .ko: "초기 기본값으로 복원"
        ],
        "pref.general.reset_desc": [
            .zhHans: "重置所有通用配置、快捷键、截图标注偏好与贴图行为",
            .en: "Reset all general settings, hotkeys, annotations, and pinning behaviors",
            .ja: "すべての一般設定、ショートカット、注釈、ピン留め動作をリセット",
            .ko: "모든 일반 설정, 단축키, 주석 및 고정 동작 초기화"
        ],
        "pref.general.reset_btn": [
            .zhHans: "恢复默认...",
            .en: "Restore...",
            .ja: "リセット...",
            .ko: "초기화..."
        ],
        "pref.general.alert_title": [
            .zhHans: "确认恢复全部默认设置？",
            .en: "Confirm Reset All Settings?",
            .ja: "すべての設定をリセットしますか？",
            .ko: "모든 설정을 초기화하시겠습니까?"
        ],
        "pref.general.alert_msg": [
            .zhHans: "所有通用配置、快捷键、标注偏好与贴图行为将重置为初始出厂设置。",
            .en: "All general settings, hotkeys, annotation presets, and pin behaviors will be restored.",
            .ja: "すべての設定が出荷時状態にリセットされます。",
            .ko: "모든 설정이 초기 기본값으로 재설정됩니다."
        ],
        "pref.general.cancel": [
            .zhHans: "取消",
            .en: "Cancel",
            .ja: "キャンセル",
            .ko: "취소"
        ],
        "pref.general.confirm_reset": [
            .zhHans: "确认恢复",
            .en: "Confirm Reset",
            .ja: "リセット実行",
            .ko: "초기화 확인"
        ],
        "pref.about.tagline": [
            .zhHans: "轻量 · 极速 · 无侵入的原生 macOS 截图与贴图工具",
            .en: "Lightweight, blazing-fast, non-intrusive native macOS capture & pinning tool",
            .ja: "軽量・高速・非侵入型のネイティブ macOS キャプチャ＆ピン留めツール",
            .ko: "가볍고 빠른 비침투형 네이티브 macOS 캡처 및 고정 도구"
        ],
        "pref.about.intro_card": [
            .zhHans: "项目特性介绍",
            .en: "Features & Highlights",
            .ja: "主な機能と特徴",
            .ko: "주요 기능 및 특징"
        ],
        "pref.about.intro_desc": [
            .zhHans: "专为 macOS 打造的高性能生产力工具。告别笨重的跨平台框架，带来瞬时呼出的顺滑体验。",
            .en: "Engineered specifically for macOS. Zero framework overhead, delivering instant and fluid capture workflows.",
            .ja: "macOS向けにゼロから設計された高性能ツール。クロスプラットフォームの重さを排除し、瞬時の応答性を実現。",
            .ko: "macOS 전용 고성능 생산성 도구. 무거운 프레임워크 없이 즉각적인 응답성을 제공합니다."
        ],
        "pref.about.feat_native_title": [
            .zhHans: "极致原生性能",
            .en: "Native Performance",
            .ja: "ネイティブの圧倒的高速性",
            .ko: "압도적인 네이티브 성능"
        ],
        "pref.about.feat_native_desc": [
            .zhHans: "纯 Swift + AppKit 深度优化，0ms 启动响应，极低后台内存开销。",
            .en: "Deeply optimized with pure Swift & AppKit, zero startup lag, ultra-low background memory footprint.",
            .ja: "Swift & AppKit ネイティブ実装、瞬時の起動、極めて低い常駐メモリ消費。",
            .ko: "Swift & AppKit 순수 네이티브 구현, 지연 없는 실행, 초저 메모리 점유율."
        ],
        "pref.about.feat_hotkey_title": [
            .zhHans: "硬件级顶排键拦截",
            .en: "Hardware-Level Intercept",
            .ja: "ハードウェアレベルのキー遮断",
            .ko: "하드웨어 수준의 키 가로채기"
        ],
        "pref.about.feat_hotkey_desc": [
            .zhHans: "CGEventTap 深度拦截技术，F1-F4 顶排键无需按 fn 实体键即可直接呼出。",
            .en: "CGEventTap engine allows top-row function keys (F1-F4) to trigger without holding the physical fn key.",
            .ja: "CGEventTap 技術により、物理 fn キーを押さずに F1-F4 ファンクションキーで直接呼び出し可能。",
            .ko: "CGEventTap 기술로 fn 키를 누를 필요 없이 F1-F4 펑션키로 즉시 캡처 실행."
        ],
        "pref.about.feat_annotation_title": [
            .zhHans: "专业精美标注工具集",
            .en: "Rich Annotation Tools",
            .ja: "洗練された注釈ツール群",
            .ko: "세련된 주석 도구 세트"
        ],
        "pref.about.feat_annotation_desc": [
            .zhHans: "矩形、椭圆、箭头、画笔、荧光笔、序号标记与马赛克，全矢量高质渲染。",
            .en: "Shapes, arrows, pens, highlighters, step counters, and pixel-perfect mosaic tools.",
            .ja: "矩形、楕円、矢印、ブラシ、蛍光ペン、連番カウンター、モザイクなど多彩な注釈機能。",
            .ko: "도형, 화살표, 펜, 형광펜, 번호 마커, 모자이크 등 다채로운 벡터 주석 제공."
        ],
        "pref.about.feat_scroll_title": [
            .zhHans: "智能多频特征长截图",
            .en: "Smart Scrolling Capture",
            .ja: "インテリジェント長尺キャプチャ",
            .ko: "스마트 스크롤 캡처"
        ],
        "pref.about.feat_scroll_desc": [
            .zhHans: "自研像素特征比对与缝合算法，支持网页与长文档的顺滑捕捉。",
            .en: "Multi-band feature matching and stitching algorithm for effortless document & webpage capture.",
            .ja: "独自の画像特徴照合・合成アルゴリズムにより、Webページや長文ドキュメントを美しく結合。",
            .ko: "자체 개발한 다중 대역 이미지 정합 알고리즘으로 긴 문서와 웹페이지를 완벽하게 합성."
        ],
        "pref.about.feat_ocr_title": [
            .zhHans: "离线文字识别与翻译",
            .en: "Offline OCR & Translation",
            .ja: "完全オフライン OCR・翻訳",
            .ko: "오프라인 OCR 및 번역"
        ],
        "pref.about.feat_ocr_desc": [
            .zhHans: "基于 Apple Vision 框架的本地离线 OCR 与内置多语言离线字典，隐私安全。",
            .en: "On-device OCR powered by Apple Vision, complete data privacy with no cloud dependencies.",
            .ja: "Apple Vision による端末内 OCR 処理と内蔵辞書翻訳、外部通信不要で高い安全性。",
            .ko: "Apple Vision 기반 온디바이스 OCR 및 내장 번역, 외부 유출 없는 완벽한 개인정보 보호."
        ],
        "pref.about.community_card": [
            .zhHans: "开源社区与支持",
            .en: "Open Source & Community",
            .ja: "オープンソースとコミュニティ",
            .ko: "오픈소스 및 커뮤니티"
        ],
        "pref.about.view_github": [
            .zhHans: "访问 GitHub 仓库",
            .en: "View on GitHub",
            .ja: "GitHub リポジトリを開く",
            .ko: "GitHub 저장소 열기"
        ],
        "pref.about.report_issue": [
            .zhHans: "提交 Issue / 建议",
            .en: "Report Issue / Feedback",
            .ja: "Issue / フィードバックを送信",
            .ko: "이슈 제보 및 피드백"
        ],
        "pref.about.license": [
            .zhHans: "本项目遵循 MIT 开源许可证 · Crafted with ❤️ by iskf",
            .en: "Released under the MIT License · Crafted with ❤️ by iskf",
            .ja: "MIT ライセンスに基づいて公開 · Crafted with ❤️ by iskf",
            .ko: "MIT 라이선스 적용 · Crafted with ❤️ by iskf"
        ],
        "pref.about.check_updates": [
            .zhHans: "检查更新",
            .en: "Check for Updates",
            .ja: "アップデートを確認",
            .ko: "업데이트 확인"
        ],
        "pref.about.checking": [
            .zhHans: "正在检查...",
            .en: "Checking...",
            .ja: "確認中...",
            .ko: "확인 중..."
        ],
        "pref.about.version": [
            .zhHans: "当前版本",
            .en: "Current Version",
            .ja: "現在のバージョン",
            .ko: "현재 버전"
        ],
        "update.title.new_version": [
            .zhHans: "发现新版本 (v%@)",
            .en: "New Version Available (v%@)",
            .ja: "新しいバージョンが見つかりました (v%@)",
            .ko: "새 버전 발견 (v%@)"
        ],
        "update.msg.new_version": [
            .zhHans: "SnipSnap v%@ 已发布！您当前运行的版本为 v%@。\n\n是否立即前往下载最新版本？",
            .en: "SnipSnap v%@ is now available! You are currently running v%@.\n\nWould you like to download it now?",
            .ja: "SnipSnap v%@ がリリースされました！現在のバージョンは v%@ です。\n\n今すぐ最新バージョンをダウンロードしますか？",
            .ko: "SnipSnap v%@ 버전이 출시되었습니다! 현재 사용 중인 버전은 v%@입니다.\n\n지금 다운로드하시겠습니까?"
        ],
        "update.btn.download": [
            .zhHans: "前往下载",
            .en: "Download",
            .ja: "ダウンロード",
            .ko: "다운로드"
        ],
        "update.btn.later": [
            .zhHans: "稍后再说",
            .en: "Later",
            .ja: "後で",
            .ko: "나중에"
        ],
        "update.title.up_to_date": [
            .zhHans: "已是最新版本",
            .en: "You're Up to Date",
            .ja: "最新バージョンです",
            .ko: "최신 버전입니다"
        ],
        "update.msg.up_to_date": [
            .zhHans: "当前运行的 SnipSnap (v%@) 已是最新版本，无需更新。",
            .en: "SnipSnap (v%@) is currently the newest version available.",
            .ja: "お使いの SnipSnap (v%@) は最新バージョンです。",
            .ko: "현재 실행 중인 SnipSnap (v%@)은 최신 버전입니다."
        ],
        "update.title.failed": [
            .zhHans: "检查更新失败",
            .en: "Update Check Failed",
            .ja: "アップデートの確認に失敗しました",
            .ko: "업데이트 확인 실패"
        ],
        "update.msg.failed": [
            .zhHans: "无法连接到更新服务器，请检查网络连接后重试。\n错误信息：%@",
            .en: "Unable to check for updates. Please check your network connection and try again.\nError: %@",
            .ja: "アップデートサーバーに接続できませんでした。ネットワーク接続を確認してください。\nエラー: %@",
            .ko: "업데이트 서버에 연결할 수 없습니다. 네트워크 연결을 확인한 후 다시 시도하세요.\n오류: %@"
        ],
        "update.btn.ok": [
            .zhHans: "好",
            .en: "OK",
            .ja: "OK",
            .ko: "확인"
        ],
        
        // Hotkeys Tab
        "pref.hotkey.intercept_card": [
            .zhHans: "全系统最高优先级拦截状态 (硬件级 CGEventTap)",
            .en: "System-Wide Highest Priority Intercept (CGEventTap)",
            .ja: "システム最高優先度インターセプト状態 (CGEventTap)",
            .ko: "시스템 최고 우선순위 가로채기 상태 (CGEventTap)"
        ],
        "pref.hotkey.intercept_active": [
            .zhHans: "最高优先级拦截引擎已激活",
            .en: "Highest Priority Intercept Engine Active",
            .ja: "最高優先度インターセプトエンジン有効",
            .ko: "최고 우선순위 가로채기 엔진 활성화됨"
        ],
        "pref.hotkey.intercept_active_desc": [
            .zhHans: "拦截层级位于 macOS HID 硬件驱动事件首位。顶排按键 (F1-F4) 可免按 fn 实体键直接呼出截屏/贴图，已智能阻止屏幕亮度调节与调度中心冲突。",
            .en: "Top-level HID event tapping. F1-F4 single keys trigger screenshot/pinning without fn key, preventing conflicts with screen brightness and Mission Control.",
            .ja: "macOS HID 最上位で動作。fn キーなしで F1-F4 が直接機能し、画面輝度調整や Mission Control との競合をスマートに防止します。",
            .ko: "macOS HID 이벤트 최상위에서 가로챕니다. fn 키 없이 F1-F4 키로 캡처/고정을 바로 실행하며 화면 밝기 및 미션 컨트롤 충돌을 방지합니다."
        ],
        "pref.hotkey.intercept_unauth": [
            .zhHans: "最高优先级拦截待授权（当前运行于标准 Carbon 兼容模式）",
            .en: "Accessibility Permission Required (Running in Carbon Mode)",
            .ja: "アクセシビリティ権限が必要です（Carbon 互換モード中）",
            .ko: "손쉬운 사용 권한 필요（Carbon 호환 모드로 실행 중）"
        ],
        "pref.hotkey.intercept_unauth_desc": [
            .zhHans: "建议开启「辅助功能」权限，以激活硬件级最高优先级拦截，彻底杜绝 F1-F4 与 Mac 原生亮度或调度中心抢占。",
            .en: "Grant Accessibility permission to enable hardware-level intercept for F1-F4 hotkeys.",
            .ja: "F1-F4 キーの競合を完全に防ぐため、アクセシビリティ権限の許可を推奨します。",
            .ko: "F1-F4 단축키 충돌을 완벽히 방지하기 위해 손쉬운 사용 권한을 허용해 주세요."
        ],
        "pref.hotkey.goto_accessibility": [
            .zhHans: "前往系统设置授权「辅助功能」 ↗",
            .en: "Open Accessibility Settings ↗",
            .ja: "アクセシビリティ設定を開く ↗",
            .ko: "손쉬운 사용 설정 열기 ↗"
        ],
        "pref.hotkey.goto_keyboard": [
            .zhHans: "键盘功能键设置 ↗",
            .en: "Keyboard Settings ↗",
            .ja: "キーボード設定 ↗",
            .ko: "키보드 설정 ↗"
        ],
        "pref.hotkey.core_card": [
            .zhHans: "四大金刚核心全局热键 (F1-F4 极简单键体系)",
            .en: "Core Global Hotkeys (F1-F4 Single-Key System)",
            .ja: "コアグローバルショートカット (F1-F4 単一キー体系)",
            .ko: "핵심 글로벌 단축키 (F1-F4 단일 키 체계)"
        ],
        "pref.hotkey.action_screenshot": [
            .zhHans: "① 屏幕截图",
            .en: "① Screen Capture",
            .ja: "① 画面キャプチャ",
            .ko: "① 화면 캡처"
        ],
        "pref.hotkey.action_pin": [
            .zhHans: "② 剪贴板贴图",
            .en: "② Pin Clipboard",
            .ja: "② クリップボードをピン留め",
            .ko: "② 클립보드 고정"
        ],
        "pref.hotkey.action_scroll_capture": [
            .zhHans: "③ 长截图",
            .en: "③ Scrolling Capture",
            .ja: "③ スクロールキャプチャ",
            .ko: "③ 스크롤 캡처"
        ],
        "pref.hotkey.action_translate": [
            .zhHans: "④ 选区翻译",
            .en: "④ Selection Translation",
            .ja: "④ 選択範囲の翻訳",
            .ko: "④ 선택 영역 번역"
        ],
        "pref.hotkey.action_toggle_pins": [
            .zhHans: "隐藏/显示所有贴图",
            .en: "Toggle All Pins",
            .ja: "すべてのピンの表示切替",
            .ko: "모든 고정 표시 전환"
        ],
        "pref.hotkey.tips_card": [
            .zhHans: "快捷键录制提示",
            .en: "Hotkey Recording Tips",
            .ja: "ショートカット設定のヒント",
            .ko: "단축키 녹화 팁"
        ],
        "pref.hotkey.tip1": [
            .zhHans: "系统默认已全面升级为 F1-F4 极简单功能键体系，单键直达无需组合键。",
            .en: "Upgraded to F1-F4 single keys by default, no modifiers required.",
            .ja: "デフォルトで F1-F4 単一ファンクションキーが設定されています。",
            .ko: "기본적으로 F1-F4 단일 기능 키 체계로 설정되어 있습니다."
        ],
        "pref.hotkey.tip2": [
            .zhHans: "点击按键框后可录制任意按键或功能键（F1-F12）；按 Esc 键可退出录制，按 ⌫ 清空。",
            .en: "Click box to record keys (F1-F12); press Esc to exit, Backspace to clear.",
            .ja: "クリックしてキーを録音（F1-F12）；Esc で終了、Backspace で消去。",
            .ko: "클릭하여 키를 녹화할 수 있습니다（F1-F12）；Esc 로 취소, 백스페이스로 초기화."
        ],
        "pref.hotkey.tip3": [
            .zhHans: "如录入的按键已分配给其他功能，输入框将自动标红警示并提示冲突来源。",
            .en: "If a key is already assigned, it will automatically alert you of the conflict.",
            .ja: "他の機能に割り当て済みの場合は警告が表示されます。",
            .ko: "이미 다른 기능에 할당된 키인 경우 충돌 경고가 표시됩니다."
        ],
        
        // Capture Tab
        "pref.capture.loupe_card": [
            .zhHans: "放大镜取色器",
            .en: "Loupe & Color Inspector",
            .ja: "拡大鏡とカラーピッカー",
            .ko: "돋보기 및 색상 추출기"
        ],
        "pref.capture.show_loupe": [
            .zhHans: "开启十字线中心取色放大镜跟随",
            .en: "Enable crosshair loupe & color inspector",
            .ja: "十字線の拡大鏡とカラーインスペクタを有効化",
            .ko: "십자선 중심 돋보기 및 색상 추출기 활성화"
        ],
        "pref.capture.color_format": [
            .zhHans: "默认取色色彩格式",
            .en: "Default Color Format",
            .ja: "デフォルトのカラー形式",
            .ko: "기본 색상 형식"
        ],
        "pref.capture.preset_card": [
            .zhHans: "标注默认样式预设",
            .en: "Default Annotation Presets",
            .ja: "注釈のデフォルトスタイル",
            .ko: "기본 주석 스타일 프리셋"
        ],
        "pref.capture.stroke_color": [
            .zhHans: "默认画笔主色调",
            .en: "Default Stroke Color",
            .ja: "デフォルトの描画色",
            .ko: "기본 브러시 색상"
        ],
        "pref.capture.stroke_width": [
            .zhHans: "默认线条粗细",
            .en: "Default Line Width",
            .ja: "デフォルトの線幅",
            .ko: "기본 선 굵기"
        ],
        "pref.capture.stroke_thin": [
            .zhHans: "细 (2px)",
            .en: "Thin (2px)",
            .ja: "細い (2px)",
            .ko: "가늘게 (2px)"
        ],
        "pref.capture.stroke_medium": [
            .zhHans: "中 (4px)",
            .en: "Medium (4px)",
            .ja: "中 (4px)",
            .ko: "보통 (4px)"
        ],
        "pref.capture.stroke_thick": [
            .zhHans: "粗 (6px)",
            .en: "Thick (6px)",
            .ja: "太い (6px)",
            .ko: "굵게 (6px)"
        ],
        "pref.capture.quick_action": [
            .zhHans: "快捷动作",
            .en: "Quick Actions",
            .ja: "クイックアクション",
            .ko: "빠른 작업"
        ],
        "pref.capture.auto_pin": [
            .zhHans: "完成截图时自动上屏贴图 (无需点击图钉按钮)",
            .en: "Auto-pin on capture completion (No button click needed)",
            .ja: "キャプチャ完了時に自動でピン留め",
            .ko: "캡처 완료 시 자동으로 화면에 고정"
        ],
        
        // Pinning Tab
        "pref.pin.appearance_card": [
            .zhHans: "贴图窗口视觉外观",
            .en: "Pin Window Appearance",
            .ja: "ピンウィンドウの外観",
            .ko: "고정 창 모양"
        ],
        "pref.pin.border": [
            .zhHans: "启用贴图紫蓝光感悬浮阴影 (Apple Intelligence 风格)",
            .en: "Enable luminous aura border (Apple Intelligence style)",
            .ja: "発光オーラ境界線を有効化 (Apple Intelligence 風)",
            .ko: "인텔리전스 스타일 발광 테두리 활성화"
        ],
        "pref.pin.shadow": [
            .zhHans: "启用贴图窗口高级柔和悬浮阴影",
            .en: "Enable soft floating window shadow",
            .ja: "ソフトドロップシャドウを有効化",
            .ko: "부드러운 창 그림자 효과 활성화"
        ],
        "pref.pin.corners": [
            .zhHans: "启用贴图窗口抗锯齿平滑圆角",
            .en: "Enable smooth anti-aliased rounded corners",
            .ja: "滑らかな角丸を有効化",
            .ko: "매끄러운 둥근 모서리 활성화"
        ],
        "pref.pin.controls_card": [
            .zhHans: "贴图交互与控制",
            .en: "Pin Interactions & Controls",
            .ja: "ピンの操作とコントロール",
            .ko: "고정 상호작용 및 제어"
        ],
        "pref.pin.alpha": [
            .zhHans: "默认初始透明度",
            .en: "Default Initial Opacity",
            .ja: "デフォルトの初期不透明度",
            .ko: "기본 초기 투명도"
        ],
        "pref.pin.double_click": [
            .zhHans: "双击贴图窗口行为",
            .en: "Double-Click Pin Action",
            .ja: "ダブルクリック時の動作",
            .ko: "더블 클릭 동작"
        ],
        "pref.pin.action_zoom": [
            .zhHans: "1:1 缩放",
            .en: "1:1 Zoom",
            .ja: "1:1 ズーム",
            .ko: "1:1 확대"
        ],
        "pref.pin.action_close": [
            .zhHans: "关闭贴图",
            .en: "Close Pin",
            .ja: "ピンを閉じる",
            .ko: "고정 닫기"
        ],
        "pref.pin.action_annotate": [
            .zhHans: "标注贴图",
            .en: "Annotate Pin",
            .ja: "注釈を付ける",
            .ko: "주석 달기"
        ],
        "pref.pin.guide_card": [
            .zhHans: "贴图神技指南",
            .en: "Pinning Pro Tips",
            .ja: "ピン留め使いこなしガイド",
            .ko: "고정 활용 꿀팁 가이드"
        ],
        "pref.pin.guide1": [
            .zhHans: "• 自由缩放：鼠标滚轮 或 双指捏合手势（10% ~ 800%）",
            .en: "• Zoom: Scroll wheel or trackpad pinch (10% ~ 800%)",
            .ja: "• ズーム: マウスホイールまたはトラックパッドピンチ (10%〜800%)",
            .ko: "• 확대/축소: 마우스 휠 또는 트랙패드 핀치 (10% ~ 800%)"
        ],
        "pref.pin.guide2": [
            .zhHans: "• 调节透明度：Ctrl + 滚轮，或按键盘数字键 1~9 (0 恢复 100%)",
            .en: "• Opacity: Ctrl + Scroll, or number keys 1~9 (0 resets to 100%)",
            .ja: "• 不透明度: Ctrl + ホイール、または数字キー 1〜9 (0 で 100%)",
            .ko: "• 투명도: Ctrl + 휠, 또는 숫자 키 1~9 (0 은 100%)"
        ],
        "pref.pin.guide3": [
            .zhHans: "• 1:1 还原：按键盘数字 0 键，一秒恢复原始 1:1 分辨率",
            .en: "• 1:1 Reset: Press 0 key to restore original resolution",
            .ja: "• 1:1 復元: 数字の 0 キーで元の解像度に復元",
            .ko: "• 1:1 복원: 숫자 0 키로 원본 해상도 즉시 복원"
        ],
        "pref.pin.guide4": [
            .zhHans: "• 外部拖拽：按住 ⌘ 拖动贴图，可作为文件直接丢入微信或访达",
            .en: "• Drag Out: Hold ⌘ and drag to export image to Finder or chat apps",
            .ja: "• ドラッグ: ⌘ を押しながらドラッグで Finder 等にファイル出力",
            .ko: "• 외부 드래그: ⌘ 누르고 드래그하여 파일로 바로 내보내기"
        ],
        "pref.pin.guide5": [
            .zhHans: "• 磁吸拼合：按住 ⇧ 拖动贴图吸附到临近贴图边缘拼接融合",
            .en: "• Snapping: Hold ⇧ to snap to adjacent pin borders",
            .ja: "• スナップ: ⇧ を押しながらドラッグで隣接ピンに吸着",
            .ko: "• 자석 결합: ⇧ 누르고 드래그하여 인접 고정 창 가장자리에 결합"
        ],
        "pref.pin.guide6": [
            .zhHans: "• 二次标注：在贴图上右键选择「🎨 标注贴图」随时补画框写字",
            .en: "• Re-annotate: Right-click pin and select \"Annotate\" anytime",
            .ja: "• 再注釈: ピンを右クリックして「注釈」を選択し再編集",
            .ko: "• 2차 주석: 고정 창 우클릭 후 \"주석\" 선택으로 언제든지 편집"
        ],
        
        // OCR & Translation Tab
        "pref.ocr.vision_card": [
            .zhHans: "Apple Vision 离线文字识别",
            .en: "Apple Vision On-Device OCR",
            .ja: "Apple Vision オフライン文字認識",
            .ko: "Apple Vision 오프라인 문자 인식"
        ],
        "pref.ocr.preferred_lang": [
            .zhHans: "优先识别语言",
            .en: "Preferred Recognition Language",
            .ja: "優先認識言語",
            .ko: "기본 인식 언어"
        ],
        "pref.ocr.auto_copy": [
            .zhHans: "文字识别完成后自动复制文本到剪贴板",
            .en: "Auto-copy recognized text to clipboard",
            .ja: "文字認識完了時にクリップボードへ自動コピー",
            .ko: "텍스트 인식 완료 시 클립보드로 자동 복사"
        ],
        "pref.ocr.engine_card": [
            .zhHans: "智能翻译引擎",
            .en: "Translation Engine",
            .ja: "翻訳エンジン",
            .ko: "스마트 번역 엔진"
        ],
        "pref.ocr.provider": [
            .zhHans: "服务提供商",
            .en: "Service Provider",
            .ja: "サービスプロバイダ",
            .ko: "서비스 제공자"
        ],
        "pref.ocr.provider_apple": [
            .zhHans: "Apple 官方翻译 (系统原生)",
            .en: "Apple Translation (Native)",
            .ja: "Apple 公式翻訳 (ネイティブ)",
            .ko: "Apple 공식 번역 (시스템 기본)"
        ],
        "pref.ocr.provider_deepl": [
            .zhHans: "DeepL 官方 API (高精度)",
            .en: "DeepL Official API (High Accuracy)",
            .ja: "DeepL 公式 API (高精度)",
            .ko: "DeepL 공식 API (고정밀)"
        ],
        "pref.ocr.provider_ai": [
            .zhHans: "AI 大模型翻译 (推荐)",
            .en: "AI Model Translation (Recommended)",
            .ja: "AI モデル翻訳 (推奨)",
            .ko: "AI 대형 모델 번역 (추천)"
        ],
        "pref.ocr.ai_preset": [
            .zhHans: "服务商预设",
            .en: "Provider Preset",
            .ja: "プロバイダプリセット",
            .ko: "제공자 프리셋"
        ],
        "pref.ocr.ai_key": [
            .zhHans: "API 密钥 (API Key)",
            .en: "API Key",
            .ja: "API キー",
            .ko: "API 키"
        ],
        "pref.ocr.ai_key_placeholder": [
            .zhHans: "在此输入 API Key (如 sk-...)",
            .en: "Enter API Key here (e.g. sk-...)",
            .ja: "ここに API キーを入力 (sk-...)",
            .ko: "여기에 API 키 입력 (sk-...)"
        ],
        "pref.ocr.ai_base_url": [
            .zhHans: "API 基础地址 (Base URL)",
            .en: "API Base URL",
            .ja: "API ベース URL",
            .ko: "API 기본 URL"
        ],
        "pref.ocr.ai_model": [
            .zhHans: "模型名称 (Model)",
            .en: "Model Name",
            .ja: "モデル名",
            .ko: "모델 이름"
        ],
        "pref.ocr.ai_test_btn": [
            .zhHans: "测试连接",
            .en: "Test Connection",
            .ja: "接続テスト",
            .ko: "연결 테스트"
        ],
        "pref.ocr.ai_testing": [
            .zhHans: "正在测试...",
            .en: "Testing...",
            .ja: "テスト中...",
            .ko: "테스트 중..."
        ],
        "pref.ocr.apple_offline_title": [
            .zhHans: "Apple 离线翻译语言包",
            .en: "Apple Offline Translation Packages",
            .ja: "Apple オフライン翻訳パッケージ",
            .ko: "Apple 오프라인 번역 언어 팩"
        ],
        "pref.ocr.apple_offline_desc": [
            .zhHans: "Apple 原生翻译依赖系统下载的离线语言包。若尚未下载，SnipSnap 将自动切换至在线多通道备用；您亦可前往 macOS 系统设置一键下载所有语言包。",
            .en: "Apple native translation uses offline language packages. If not installed, SnipSnap automatically falls back to online translation; you can also download language packs in macOS settings.",
            .ja: "Apple ネイティブ翻訳はシステム言語パックを使用します。未インストールの場合は自動でオンライン翻訳に切り替わります。設定からダウンロードも可能です。",
            .ko: "Apple 네이티브 번역은 오프라인 언어 팩을 사용합니다. 미설치 시 온라인으로 자동 전환되며, macOS 설정에서 언어 팩을 다운로드할 수 있습니다."
        ],
        "pref.ocr.open_system_lang": [
            .zhHans: "打开「系统设置 > 语言与地区」管理语言包 ↗",
            .en: "Open Language & Region Settings ↗",
            .ja: "「言語と地域」設定を開く ↗",
            .ko: "「언어 및 지역」 설정 열기 ↗"
        ],
        "pref.ocr.deepl_key": [
            .zhHans: "DeepL API Key",
            .en: "DeepL API Key",
            .ja: "DeepL API キー",
            .ko: "DeepL API 키"
        ],
        "pref.ocr.deepl_placeholder": [
            .zhHans: "在此输入 DeepL 认证密钥",
            .en: "Enter DeepL API Key here",
            .ja: "ここに DeepL API キーを入力",
            .ko: "여기에 DeepL 인증 키 입력"
        ],
        "pref.ocr.deepl_free_endpoint": [
            .zhHans: "免费版 API 终端 (api-free.deepl.com)",
            .en: "Free API Endpoint (api-free.deepl.com)",
            .ja: "無料版 API エンドポイント (api-free.deepl.com)",
            .ko: "무료 버전 API 엔드포인트 (api-free.deepl.com)"
        ],
        "pref.ocr.deepl_free_desc": [
            .zhHans: "DeepL 免费版 Key 通常以 :fx 结尾，系统已支持自动适配",
            .en: "Free keys usually end with :fx, auto-detected",
            .ja: "無料版キーは通常 :fx で終了し、自動認識されます",
            .ko: "DeepL 무료 키는 일반적으로 :fx로 끝나며 자동 감지됩니다"
        ],
        "pref.ocr.deepl_test_btn": [
            .zhHans: "测试连接",
            .en: "Test Connection",
            .ja: "接続テスト",
            .ko: "연결 테스트"
        ],
        "pref.ocr.deepl_testing": [
            .zhHans: "正在测试...",
            .en: "Testing...",
            .ja: "テスト中...",
            .ko: "테스트 중..."
        ],
        "pref.ocr.target_lang": [
            .zhHans: "默认目标语言",
            .en: "Default Target Language",
            .ja: "デフォルト翻訳先言語",
            .ko: "기본 번역 대상 언어"
        ],
        "pref.ocr.smart_tip": [
            .zhHans: "智能语言匹配：截图中检测到中文将自动翻译为英文；检测到外文将自动翻译为中文。卡片内支持一键双向互换。",
            .en: "Smart matching: Automatically translates Chinese to English and foreign languages to Chinese. Card supports one-click swap.",
            .ja: "スマート言語判定: 中国語は英語へ、外国語は母国語へ自動翻訳。カード内でワンクリック双方向切り替え対応。",
            .ko: "스마트 언어 감지: 화면에서 언어를 자동 감지하여 번역합니다. 카드 내에서 원클릭 상호 전환을 지원합니다."
        ],
        "pref.ocr.lang_zh_hans": [
            .zhHans: "简体中文 + 英文",
            .en: "Simplified Chinese + English",
            .ja: "簡体字中国語 + 英語",
            .ko: "중국어 간체 + 영어"
        ],
        "pref.ocr.lang_zh_hant": [
            .zhHans: "繁体中文 + 英文",
            .en: "Traditional Chinese + English",
            .ja: "繁体字中国語 + 英語",
            .ko: "중국어 번체 + 영어"
        ],
        "pref.ocr.lang_en_us": [
            .zhHans: "纯英文 (English)",
            .en: "English (English)",
            .ja: "英語 (English)",
            .ko: "영어 (English)"
        ],
        "pref.ocr.lang_ja_jp": [
            .zhHans: "日语 + 英文",
            .en: "Japanese + English",
            .ja: "日本語 + 英語",
            .ko: "일본어 + 영어"
        ],
        "pref.ocr.lang_ko_kr": [
            .zhHans: "韩语 + 英文",
            .en: "Korean + English",
            .ja: "韓国語 + 英語",
            .ko: "한국어 + 영어"
        ],
        
        // Pin Window Context Menu
        "pin.menu.copy": [
            .zhHans: "复制图片",
            .en: "Copy Image",
            .ja: "画像をコピー",
            .ko: "이미지 복사"
        ],
        "pin.menu.save": [
            .zhHans: "保存图片...",
            .en: "Save Image...",
            .ja: "画像を保存...",
            .ko: "이미지 저장..."
        ],
        "pin.menu.annotate": [
            .zhHans: "标注贴图",
            .en: "Annotate Pin",
            .ja: "ピンに注釈を付ける",
            .ko: "고정에 주석 달기"
        ],
        "pin.menu.reset_zoom": [
            .zhHans: "恢复 1:1 大小",
            .en: "Restore 1:1 Size",
            .ja: "1:1 サイズに復元",
            .ko: "1:1 크기로 복원"
        ],
        "pin.menu.passthrough": [
            .zhHans: "开启鼠标穿透 (点击忽略)",
            .en: "Enable Mouse Pass-Through",
            .ja: "マウスクリックスルーを有効化",
            .ko: "마우스 클릭 관통 활성화"
        ],
        "pin.menu.unlock_passthrough": [
            .zhHans: "解锁鼠标穿透",
            .en: "Unlock Mouse Pass-Through",
            .ja: "クリックスルーを解除",
            .ko: "마우스 클릭 관통 해제"
        ],
        "pin.menu.close": [
            .zhHans: "关闭贴图",
            .en: "Close Pin",
            .ja: "ピンを閉じる",
            .ko: "고정 닫기"
        ],
        "pin.menu.exit_annotate": [
            .zhHans: "退出标注模式",
            .en: "Exit Annotation",
            .ja: "注釈モードを終了",
            .ko: "주석 모드 종료"
        ],
        "pin.menu.transform": [
            .zhHans: "图像变换",
            .en: "Transform",
            .ja: "画像変換",
            .ko: "이미지 변환"
        ],
        "pin.menu.rotate_cw": [
            .zhHans: "顺时针旋转 90°",
            .en: "Rotate 90° Clockwise",
            .ja: "時計回りに90°回転",
            .ko: "시계 방향으로 90° 회전"
        ],
        "pin.menu.rotate_ccw": [
            .zhHans: "逆时针旋转 90°",
            .en: "Rotate 90° Counterclockwise",
            .ja: "反時計回りに90°回転",
            .ko: "반시계 방향으로 90° 회전"
        ],
        "pin.menu.flip_h": [
            .zhHans: "水平翻转",
            .en: "Flip Horizontal",
            .ja: "左右反転",
            .ko: "좌우 반전"
        ],
        "pin.menu.flip_v": [
            .zhHans: "垂直翻转",
            .en: "Flip Vertical",
            .ja: "上下反転",
            .ko: "상하 반전"
        ],
        "pin.menu.reset_resolution": [
            .zhHans: "恢复 1:1 原始比例",
            .en: "Restore 1:1 Scale",
            .ja: "1:1 元の比率に戻す",
            .ko: "1:1 원본 비율 복원"
        ],
        "pin.menu.collapse_thumb": [
            .zhHans: "折叠为缩略图",
            .en: "Collapse to Thumbnail",
            .ja: "サムネイルに縮小",
            .ko: "축소판으로 접기"
        ],
        "pin.menu.expand_thumb": [
            .zhHans: "展开为原图",
            .en: "Expand from Thumbnail",
            .ja: "元のサイズに展開",
            .ko: "원본 크기로 펼치기"
        ],
        "pin.menu.opacity": [
            .zhHans: "窗口透明度",
            .en: "Window Opacity",
            .ja: "ウィンドウの不透明度",
            .ko: "창 투명도"
        ],
        "pin.menu.shadow": [
            .zhHans: "切换悬浮阴影",
            .en: "Toggle Shadow",
            .ja: "影の切り替え",
            .ko: "그림자 전환"
        ],
        "pin.menu.save_as": [
            .zhHans: "存储图片为...",
            .en: "Save Image As...",
            .ja: "画像を保存...",
            .ko: "다른 이름으로 저장..."
        ],
        
        // MARK: - Annotation Toolbar & Tools
        "toolbar.tool.rectangle": [
            .zhHans: "矩形",
            .en: "Rectangle",
            .ja: "矩形",
            .ko: "직사각형"
        ],
        "toolbar.tool.ellipse": [
            .zhHans: "椭圆",
            .en: "Ellipse",
            .ja: "楕円",
            .ko: "타원"
        ],
        "toolbar.tool.arrow": [
            .zhHans: "箭头",
            .en: "Arrow",
            .ja: "矢印",
            .ko: "화살표"
        ],
        "toolbar.tool.line": [
            .zhHans: "直线",
            .en: "Line",
            .ja: "直線",
            .ko: "직선"
        ],
        "toolbar.tool.brush": [
            .zhHans: "画笔",
            .en: "Brush",
            .ja: "ブラシ",
            .ko: "브러시"
        ],
        "toolbar.tool.highlighter": [
            .zhHans: "荧光笔",
            .en: "Highlighter",
            .ja: "蛍光ペン",
            .ko: "형광펜"
        ],
        "toolbar.tool.text": [
            .zhHans: "文字",
            .en: "Text",
            .ja: "テキスト",
            .ko: "텍스트"
        ],
        "toolbar.tool.mosaic": [
            .zhHans: "马赛克",
            .en: "Mosaic",
            .ja: "モザイク",
            .ko: "모자이크"
        ],
        "toolbar.tool.counter": [
            .zhHans: "步骤序号",
            .en: "Step Counter",
            .ja: "ステップ番号",
            .ko: "번호 매기기"
        ],
        "toolbar.action.undo": [
            .zhHans: "撤销",
            .en: "Undo",
            .ja: "元に戻す",
            .ko: "실행 취소"
        ],
        "toolbar.action.redo": [
            .zhHans: "重做",
            .en: "Redo",
            .ja: "やり直し",
            .ko: "다시 실행"
        ],
        "toolbar.action.cancel": [
            .zhHans: "取消截图",
            .en: "Cancel Capture",
            .ja: "キャプチャ中止",
            .ko: "캡처 취소"
        ],
        "toolbar.action.save": [
            .zhHans: "保存图片",
            .en: "Save Image",
            .ja: "画像を保存",
            .ko: "이미지 저장"
        ],
        "toolbar.action.pin": [
            .zhHans: "贴到屏幕",
            .en: "Pin to Screen",
            .ja: "画面にピン留め",
            .ko: "화면에 고정"
        ],
        "toolbar.action.copy": [
            .zhHans: "完成并复制",
            .en: "Done & Copy",
            .ja: "完了してコピー",
            .ko: "완료 및 복사"
        ],
        "toolbar.action.record_gif": [
            .zhHans: "录制短动图",
            .en: "Record GIF",
            .ja: "GIF録画",
            .ko: "GIF 녹화"
        ],
        "toolbar.action.scroll_capture": [
            .zhHans: "长截图",
            .en: "Scrolling Capture",
            .ja: "スクロールキャプチャ",
            .ko: "스크롤 캡처"
        ],
        "scroll.hud.title": [
            .zhHans: "长截图",
            .en: "Scrolling Capture",
            .ja: "スクロールキャプチャ",
            .ko: "스크롤 캡처"
        ],
        "scroll.hud.pause": [
            .zhHans: "暂停",
            .en: "Pause",
            .ja: "一時停止",
            .ko: "일시 중지"
        ],
        "scroll.hud.resume": [
            .zhHans: "继续",
            .en: "Resume",
            .ja: "再開",
            .ko: "재개"
        ],
        "scroll.hud.finish": [
            .zhHans: "完成",
            .en: "Finish",
            .ja: "完了",
            .ko: "완료"
        ],
        "scroll.hud.cancel": [
            .zhHans: "取消",
            .en: "Cancel",
            .ja: "キャンセル",
            .ko: "취소"
        ],
        "scroll.hud.speed_slow": [
            .zhHans: "慢",
            .en: "Slow",
            .ja: "遅い",
            .ko: "느림"
        ],
        "scroll.hud.speed_normal": [
            .zhHans: "中",
            .en: "Normal",
            .ja: "標準",
            .ko: "보통"
        ],
        "scroll.hud.speed_fast": [
            .zhHans: "快",
            .en: "Fast",
            .ja: "速い",
            .ko: "빠름"
        ],
        "scroll.hud.bottom_countdown": [
            .zhHans: "已到达底部，请按 Enter 完成",
            .en: "Reached bottom, press Enter to finish",
            .ja: "末尾に到達、Enterで完了",
            .ko: "하단 도달, Enter를 눌러 완료"
        ],
        "scroll.hud.bottom_reached": [
            .zhHans: "已到达底部，请按 Enter 完成",
            .en: "Reached bottom, press Enter to finish",
            .ja: "末尾に到達、Enterで完了",
            .ko: "하단 도달, Enter를 눌러 완료"
        ],
        "scroll.hud.copied": [
            .zhHans: "✓ 已复制到剪贴板",
            .en: "✓ Copied to clipboard",
            .ja: "✓ クリップボードにコピーしました",
            .ko: "✓ 클립보드에 복사됨"
        ],
        "scroll.hud.copied_segments": [
            .zhHans: "✓ 已分段复制多张长图",
            .en: "✓ Copied segmented images",
            .ja: "✓ 分割画像をコピーしました",
            .ko: "✓ 분할 이미지가 복사됨"
        ],
        "scroll.hud.segment_warn": [
            .zhHans: "接近单图上限，将分段导出",
            .en: "Approaching limit, will segment",
            .ja: "上限に近いため分割保存します",
            .ko: "한계에 도달하여 분할 저장됩니다"
        ],
        "loupe.tip": [
            .zhHans: "C:复制 | Shift:格式",
            .en: "C: Copy | Shift: Format",
            .ja: "C: コピー | Shift: 形式",
            .ko: "C: 복사 | Shift: 서식"
        ],
        "capture.translate_tip": [
            .zhHans: "框选翻译区域 (Esc退出)",
            .en: "Select translation area (Esc to exit)",
            .ja: "翻訳範囲を選択 (Escで終了)",
            .ko: "번역 영역 선택 (Esc로 종료)"
        ],
        "ocr.copy_all": [
            .zhHans: "复制全部文本",
            .en: "Copy All Text",
            .ja: "すべてのテキストをコピー",
            .ko: "모든 텍스트 복사"
        ],
        "ocr.translate": [
            .zhHans: "对照翻译",
            .en: "Translate",
            .ja: "翻訳",
            .ko: "번역"
        ],
        "ocr.recognize_fail": [
            .zhHans: "文字识别失败",
            .en: "Text Recognition Failed",
            .ja: "文字認識に失敗しました",
            .ko: "텍스트 인식 실패"
        ],
        
        // MARK: - Secondary Palette
        "palette.text.plain": [
            .zhHans: "纯色",
            .en: "Plain",
            .ja: "単色",
            .ko: "단색"
        ],
        "palette.text.outline": [
            .zhHans: "描边",
            .en: "Outline",
            .ja: "輪郭",
            .ko: "외곽선"
        ],
        "palette.mosaic.fine": [
            .zhHans: "细 10px",
            .en: "Fine 10px",
            .ja: "細 10px",
            .ko: "얇게 10px"
        ],
        "palette.mosaic.coarse": [
            .zhHans: "粗 20px",
            .en: "Coarse 20px",
            .ja: "太 20px",
            .ko: "굵게 20px"
        ],
        "palette.counter.filled": [
            .zhHans: "实心",
            .en: "Filled",
            .ja: "塗り",
            .ko: "채우기"
        ],
        "palette.counter.outline": [
            .zhHans: "描边",
            .en: "Outline",
            .ja: "輪郭",
            .ko: "외곽선"
        ],
        "palette.counter.reset": [
            .zhHans: "重置序号",
            .en: "Reset Counter",
            .ja: "番号リセット",
            .ko: "번호 초기화"
        ],
        
        // MARK: - Translation Floating Toolbar & HUD
        "translate.tab.original": [
            .zhHans: "原文",
            .en: "Original",
            .ja: "原文",
            .ko: "원문"
        ],
        "translate.tab.translated": [
            .zhHans: "译文",
            .en: "Translated",
            .ja: "訳文",
            .ko: "번역"
        ],
        "translate.switch_help": [
            .zhHans: "在原文与译文之间原地切换 (敲击空格键也可切换)",
            .en: "Toggle between original and translated (Spacebar works too)",
            .ja: "原文と訳文を切り替え (スペースキーでも可能)",
            .ko: "원문과 번역문 전환 (스페이스바로도 전환 가능)"
        ],
        "translate.auto_detect": [
            .zhHans: "自动检测",
            .en: "Auto Detect",
            .ja: "自動検出",
            .ko: "자동 감지"
        ],
        "translate.auto": [
            .zhHans: "自动",
            .en: "Auto",
            .ja: "自動",
            .ko: "자동"
        ],
        "translate.stop_generating": [
            .zhHans: "停止生成",
            .en: "Stop",
            .ja: "停止",
            .ko: "중지"
        ],
        "translate.swap": [
            .zhHans: "互换",
            .en: "Swap",
            .ja: "入替",
            .ko: "맞바꾸기"
        ],
        "translate.swap_help": [
            .zhHans: "互换源语言与目标语言",
            .en: "Swap source and target languages",
            .ja: "原言語と翻訳先言語を入れ替え",
            .ko: "원본 언어와 대상 언어 맞바꾸기"
        ],
        "translate.copy": [
            .zhHans: "复制",
            .en: "Copy",
            .ja: "コピー",
            .ko: "복사"
        ],
        "translate.copy_help": [
            .zhHans: "复制译文到剪贴板",
            .en: "Copy translation to clipboard",
            .ja: "翻訳結果をクリップボードにコピー",
            .ko: "번역 결과 클립보드로 복사"
        ],
        "translate.close_help": [
            .zhHans: "退出翻译 (Esc 或点击外部均可退出)",
            .en: "Close translation (Esc or click outside)",
            .ja: "翻訳を終了 (Esc または外側をクリック)",
            .ko: "번역 닫기 (Esc 또는 바깥쪽 클릭)"
        ],
        "translate.copied": [
            .zhHans: "已复制",
            .en: "Copied",
            .ja: "コピー完了",
            .ko: "복사됨"
        ],
        "translate.engine.apple": [
            .zhHans: "Apple 原生翻译",
            .en: "Apple Translation",
            .ja: "Apple ネイティブ翻訳",
            .ko: "Apple 기본 번역"
        ],
        "translate.engine.deepl": [
            .zhHans: "DeepL 官方翻译",
            .en: "DeepL Translation",
            .ja: "DeepL 公式翻訳",
            .ko: "DeepL 공식 번역"
        ],
        "translate.err.offline_missing": [
            .zhHans: "离线包未下载",
            .en: "Offline pack missing",
            .ja: "オフライン未取得",
            .ko: "오프라인 팩 없음"
        ],
        "translate.err.go_download": [
            .zhHans: "去下载 ↗",
            .en: "Download ↗",
            .ja: "取得 ↗",
            .ko: "다운로드 ↗"
        ],
        "translate.err.offline_help": [
            .zhHans: "点击前往 macOS「语言与地区」系统设置下载翻译语言包",
            .en: "Click to open macOS Language & Region settings to download packs",
            .ja: "macOS の「言語と地域」設定から言語パックをダウンロード",
            .ko: "macOS 「언어 및 지역」 설정에서 언어 팩 다운로드"
        ],
        "translate.err.no_text": [
            .zhHans: "未检测到文字",
            .en: "No text detected",
            .ja: "文字未検出",
            .ko: "텍스트 미감지"
        ],
        "translate.err.same_lang": [
            .zhHans: "源与目标相同",
            .en: "Same languages",
            .ja: "同一言語です",
            .ko: "언어가 동일함"
        ],
        "translate.err.network": [
            .zhHans: "网络连接不可用",
            .en: "Network offline",
            .ja: "オフライン",
            .ko: "네트워크 불가"
        ],
        "translate.retry": [
            .zhHans: "重试",
            .en: "Retry",
            .ja: "再試行",
            .ko: "재시도"
        ],
        "translate.fallback_online": [
            .zhHans: "已转在线·缺离线包",
            .en: "Online fallback (No offline pack)",
            .ja: "オンライン代行中 (パック未取得)",
            .ko: "온라인 대체 중 (오프라인 팩 없음)"
        ],
        "translate.fallback_online_help": [
            .zhHans: "因 Apple 离线语言包未安装，当前已自动降级为在线翻译。点击可前往系统设置下载离线包。",
            .en: "Falling back to online translation because Apple offline pack is not installed. Click to download in System Settings.",
            .ja: "Apple オフラインパック未インストールの為、オンライン翻訳で対応中。クリックで設定を開きます。",
            .ko: "Apple 오프라인 팩이 없어 온라인 번역으로 대체되었습니다. 클릭하여 시스템 설정에서 다운로드하세요."
        ],
        "translate.smart_online": [
            .zhHans: "智能在线补位",
            .en: "Smart Online Fallback",
            .ja: "スマート補正中",
            .ko: "스마트 온라인 대체"
        ],
        "translate.smart_online_help": [
            .zhHans: "源语种特征不明显，已启用多通道智能在线识别与翻译",
            .en: "Low-confidence source language, smart multi-channel online translation enabled",
            .ja: "言語判定が困難なため、高精度オンライン翻訳を使用中",
            .ko: "원본 언어 식별이 어려워 스마트 온라인 번역이 활성화되었습니다"
        ],
        "translate.current_engine": [
            .zhHans: "当前翻译引擎",
            .en: "Current Engine",
            .ja: "現在のエンジン",
            .ko: "현재 번역 엔진"
        ],
        "translate.change_source": [
            .zhHans: "点击修改原语言",
            .en: "Click to change source language",
            .ja: "クリックして原言語を変更",
            .ko: "원본 언어 변경"
        ],
        "translate.change_target": [
            .zhHans: "点击修改目标语言",
            .en: "Click to change target language",
            .ja: "クリックして目標言語を変更",
            .ko: "대상 언어 변경"
        ],
        
        // MARK: - Language Names
        "lang.zh_hans": [
            .zhHans: "中文 (简体)",
            .en: "Chinese (Simplified)",
            .ja: "中国語 (簡体字)",
            .ko: "중국어 (간체)"
        ],
        "lang.zh_hant": [
            .zhHans: "中文 (繁体)",
            .en: "Chinese (Traditional)",
            .ja: "中国語 (繁体字)",
            .ko: "중국어 (번체)"
        ],
        "lang.en": [
            .zhHans: "英语 (English)",
            .en: "English (English)",
            .ja: "英語 (English)",
            .ko: "영어 (English)"
        ],
        "lang.ja": [
            .zhHans: "日语 (日本語)",
            .en: "Japanese (日本語)",
            .ja: "日本語 (日本語)",
            .ko: "일본어 (日本語)"
        ],
        "lang.ko": [
            .zhHans: "韩语 (한국어)",
            .en: "Korean (한국어)",
            .ja: "韓国語 (한국어)",
            .ko: "한국어 (한국어)"
        ],
        "lang.fr": [
            .zhHans: "法语 (Français)",
            .en: "French (Français)",
            .ja: "フランス語 (Français)",
            .ko: "프랑스어 (Français)"
        ],
        "lang.de": [
            .zhHans: "德语 (Deutsch)",
            .en: "German (Deutsch)",
            .ja: "ドイツ語 (Deutsch)",
            .ko: "독일어 (Deutsch)"
        ],
        "lang.es": [
            .zhHans: "西班牙语 (Español)",
            .en: "Spanish (Español)",
            .ja: "スペイン語 (Español)",
            .ko: "스페인어 (Español)"
        ],
        "lang.ru": [
            .zhHans: "俄语 (Русский)",
            .en: "Russian (Русский)",
            .ja: "ロシア語 (Русский)",
            .ko: "러시아어 (Русский)"
        ],
        
        // MARK: - Short Language Badges (1-2 chars)
        "lang.short.zh": [
            .zhHans: "中",
            .en: "ZH",
            .ja: "中",
            .ko: "중"
        ],
        "lang.short.en": [
            .zhHans: "英",
            .en: "EN",
            .ja: "英",
            .ko: "영"
        ],
        "lang.short.ja": [
            .zhHans: "日",
            .en: "JA",
            .ja: "日",
            .ko: "일"
        ],
        "lang.short.ko": [
            .zhHans: "韩",
            .en: "KO",
            .ja: "韓",
            .ko: "한"
        ],
        "lang.short.fr": [
            .zhHans: "法",
            .en: "FR",
            .ja: "仏",
            .ko: "불"
        ],
        "lang.short.de": [
            .zhHans: "德",
            .en: "DE",
            .ja: "独",
            .ko: "독"
        ],
        "lang.short.es": [
            .zhHans: "西",
            .en: "ES",
            .ja: "西",
            .ko: "서"
        ],
        "lang.short.ru": [
            .zhHans: "俄",
            .en: "RU",
            .ja: "露",
            .ko: "러"
        ]
    ]
}

// MARK: - Global Convenience

public func L10n(_ key: String) -> String {
    return I18n.shared.t(key)
}
