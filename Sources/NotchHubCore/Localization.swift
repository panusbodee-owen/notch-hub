import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case en = "en"
    case th = "th"
    case ja = "ja"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .en: return "EN"
        case .th: return "ไทย"
        case .ja: return "日本語"
        }
    }
}

public struct L10n: Sendable {
    public let lang: AppLanguage

    public init(_ lang: AppLanguage) {
        self.lang = lang
    }

    public func tabTitle(_ tab: NotchTab) -> String {
        switch (lang, tab) {
        case (.en, .home): return "Home"
        case (.en, .shelf): return "Shelf"
        case (.en, .ai): return "AI & Jobs"
        case (.en, .clipboard): return "Clips"
        case (.en, .settings): return "Settings"

        case (.th, .home): return "หน้าหลัก"
        case (.th, .shelf): return "พักไฟล์"
        case (.th, .ai): return "AI & งาน"
        case (.th, .clipboard): return "คลิปบอร์ด"
        case (.th, .settings): return "ตั้งค่า"

        case (.ja, .home): return "ホーム"
        case (.ja, .shelf): return "シェルフ"
        case (.ja, .ai): return "AI & ジョブ"
        case (.ja, .clipboard): return "履歴"
        case (.ja, .settings): return "設定"
        }
    }

    public func gadgetName(_ kind: HomeGadgetKind) -> String {
        switch (lang, kind) {
        case (.en, _): return kind.displayName

        case (.th, .captures): return "ภาพ Cap (5)"
        case (.th, .aiRadar): return "AI ในเครื่อง"
        case (.th, .media): return "เพลง"
        case (.th, .ai): return "สถานะงาน AI"
        case (.th, .timer): return "จับเวลา"
        case (.th, .system): return "สถานะเครื่อง"
        case (.th, .notes): return "โน้ตด่วน"
        case (.th, .clock): return "นาฬิกา"

        case (.ja, .captures): return "スクショ (5)"
        case (.ja, .aiRadar): return "AI レーダー"
        case (.ja, .media): return "メディア"
        case (.ja, .ai): return "AI ジョブ"
        case (.ja, .timer): return "タイマー"
        case (.ja, .system): return "システム"
        case (.ja, .notes): return "クイックメモ"
        case (.ja, .clock): return "時計"
        }
    }

    public var capScreen: String {
        switch lang {
        case .en: return "Cap Screen"
        case .th: return "แคปจอ"
        case .ja: return "スクショ"
        }
    }

    public var capHint: String {
        switch lang {
        case .en: return "Cmd+Shift+4 / Ctrl+Cmd+Shift+4 auto-saves here"
        case .th: return "แคปด้วย Cmd+Shift+4 / Ctrl+Cmd+Shift+4 รูปจะเข้าอัตโนมัติ"
        case .ja: return "Cmd+Shift+4 / Ctrl+Cmd+Shift+4 で自動保存"
        }
    }

    public var gadgets: String {
        switch lang {
        case .en: return "Gadgets"
        case .th: return "Gadgets"
        case .ja: return "ガジェット"
        }
    }

    public var done: String {
        switch lang {
        case .en: return "Done"
        case .th: return "เสร็จสิ้น"
        case .ja: return "完了"
        }
    }

    public var recentCaptures: String {
        switch lang {
        case .en: return "Recent Captures"
        case .th: return "ภาพ Cap ล่าสุด"
        case .ja: return "最近のキャプチャ"
        }
    }

    public var captureDragHint: String {
        switch lang {
        case .en: return "Drag to any app/file or click to Copy image"
        case .th: return "ลากไปวางในแอป/ไฟล์ หรือคลิกเพื่อ Copy รูป"
        case .ja: return "アプリへドラッグ、またはクリックでコピー"
        }
    }

    public var clear: String {
        switch lang {
        case .en: return "Clear"
        case .th: return "ล้าง"
        case .ja: return "クリア"
        }
    }

    public var copied: String {
        switch lang {
        case .en: return "Copied!"
        case .th: return "ก๊อปแล้ว!"
        case .ja: return "コピー済"
        }
    }

    public var aiOnThisMac: String {
        switch lang {
        case .en: return "AI on This Mac"
        case .th: return "AI ในเครื่องนี้"
        case .ja: return "このMacのAI"
        }
    }

    public var shelfTitle: String {
        switch lang {
        case .en: return "File Drop Shelf"
        case .th: return "ถาดพักไฟล์ชั่วคราว"
        case .ja: return "ファイルシェルフ"
        }
    }

    public var shelfHint: String {
        switch lang {
        case .en: return "Drop files here or drag out to FilmCraft, EffectCraft & Finder"
        case .th: return "ลากไฟล์มาวางพัก หรือลากออกไปใส่ FilmCraft / EffectCraft / Finder"
        case .ja: return "ファイルを一時保管し、他アプリへドラッグ＆ドロップ"
        }
    }

    public var shelfEmpty: String {
        switch lang {
        case .en: return "Drop files, clips, or images here"
        case .th: return "วางไฟล์ คลิป หรือรูปภาพตรงนี้"
        case .ja: return "ファイル・動画・画像をここにドロップ"
        }
    }

    public var clipboardTitle: String {
        switch lang {
        case .en: return "Clipboard & Prompt Snippets"
        case .th: return "ประวัติคลิปบอร์ด & Prompt"
        case .ja: return "クリップボード履歴"
        }
    }

    public var clearUnpinned: String {
        switch lang {
        case .en: return "Clear Unpinned"
        case .th: return "ล้างที่ไม่ได้ปักหมุด"
        case .ja: return "未固定を削除"
        }
    }

    public var languageLabel: String {
        switch lang {
        case .en: return "Language"
        case .th: return "ภาษา (Language)"
        case .ja: return "言語 (Language)"
        }
    }

    public var modularWidgets: String {
        switch lang {
        case .en: return "Modular Widgets"
        case .th: return "เปิด/ปิดโมดูล"
        case .ja: return "モジュール設定"
        }
    }

    public var notchSizeLayout: String {
        switch lang {
        case .en: return "Notch Size & Layout"
        case .th: return "ขนาดและการแสดงผล Notch"
        case .ja: return "ノッチサイズ・動作"
        }
    }

    public var quickNote: String {
        switch lang {
        case .en: return "Quick Note"
        case .th: return "โน้ตด่วน"
        case .ja: return "クイックメモ"
        }
    }

    public var clockTitle: String {
        switch lang {
        case .en: return "Clock"
        case .th: return "นาฬิกา"
        case .ja: return "時計"
        }
    }
}
