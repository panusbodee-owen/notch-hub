# NotchHub — Native macOS Dynamic Island (Productivity + AI & Creator Hub)

แอป **NotchHub** เขียนด้วย **Swift + SwiftUI + AppKit (`NSPanel`)** แบบ Native macOS (Apple Silicon) เปลี่ยนรอยบากบน MacBook (หรือ Floating Pill บนจอนอก) ให้เป็นศูนย์รวม Gadget, ถาดเก็บรูป Cap อัตโนมัติ, File Shelf และ AI Radar

---

## Download ตรงๆ (Direct Download)

- **macOS Installer (`.dmg` — ลากใส่ Applications ได้เลย):**  
  [Download NotchHub-macOS-arm64.dmg](https://github.com/panusbodee-owen/notch-hub/releases/latest/download/NotchHub-macOS-arm64.dmg)
- **macOS Archive (`.zip` — แตกไฟล์แล้วเปิดใช้ได้ทันที):**  
  [Download NotchHub-macOS-arm64.zip](https://github.com/panusbodee-owen/notch-hub/releases/latest/download/NotchHub-macOS-arm64.zip)
- **หน้า Releases ทั้งหมด:**  
  https://github.com/panusbodee-owen/notch-hub/releases/latest

### ติดตั้งผ่าน Terminal แบบ 1 บรรทัด
```bash
curl -fL "https://github.com/panusbodee-owen/notch-hub/releases/latest/download/NotchHub-macOS-arm64.zip" -o /tmp/NotchHub.zip && ditto -xk /tmp/NotchHub.zip /Applications && xattr -dr com.apple.quarantine /Applications/NotchHub.app && open /Applications/NotchHub.app
```

> **หมายเหตุครั้งแรกที่เปิดแอป (macOS Gatekeeper):** เนื่องจากแอปยังไม่ได้ Notarize ผ่าน Apple Developer Account หากโหลดจากเบราว์เซอร์แล้ว macOS แจ้งเตือน ให้รันคำสั่งนี้ 1 ครั้งแล้วเปิดใหม่:
> ```bash
> xattr -dr com.apple.quarantine /Applications/NotchHub.app
> ```

---

## ฟีเจอร์เด่นทั้งหมด

- **3-State Dynamic Notch & ปรับขนาดได้อิสระ:**
  - `Closed` / `Compact Wings` / `Expanded` ลอยเหนือ Menu Bar & Full-Screen โดยไม่แย่ง Focus
  - ลากมุมขวาล่าง (`↖↘`) ปรับขนาดกว้าง-สูงได้สดๆ หรือเลือก Preset **`S / M / L / XL`** + สไลเดอร์ในแท็บ **Settings**
- **Home แบบเลือกใส่ Gadget เองได้:**
  - กดปุ่ม **`Gadgets`** บนหน้า Home เพื่อเพิ่ม/ลบ/สลับตำแหน่ง: **Recent Captures (5)**, **My AIs Radar**, **Media**, **AI Jobs**, **Timer**, **System HUD**, **Quick Note**, **Clock**
- **ถาดเก็บรูป Cap อัตโนมัติ 5 รูป:**
  - จับอัตโนมัติทั้ง `Cmd+Shift+3/4/5` (ลงไฟล์), `Ctrl+Cmd+Shift+3/4` (ลง Clipboard) หรือกดปุ่ม **`Cap Screen`** บน Notch
  - ลากรูปจาก Thumbnail ไปวางในแอป/ไฟล์ต่างๆ หรือคลิก 1 ทีเพื่อ Copy รูปไป `Cmd+V` ได้ทันที
- **AI Radar (สแกน AI ทั้งเครื่อง — Desktop App, CLI, API):**
  - ตรวจจับ Desktop Apps (Antigravity, Claude, ChatGPT, Cursor, Ollama ฯลฯ), CLI (`agy`, `codex`, `claude`, `gemini`, `ollama`, MCPs) และ Local/Cloud APIs พร้อมสถานะสดและปุ่มกดเปิด/รัน/Copy
- **File Drop Shelf:** ลากไฟล์/คลิปขึ้นด้านบนกลางจอเพื่อพักไว้ แล้วลากออกไปวางใส่ FilmCraft, EffectCraft, Blender หรือ Finder
- **Local Live Activity HTTP API (`http://127.0.0.1:47890`):** ยิงสถานะ AI Agent หรือแถบ Progress งาน Render ขึ้น Notch ได้ทันที
- **Clipboard History & Quick Camera Mirror:** เก็บประวัติข้อความ/Prompt ปักหมุดได้ และเปิดกล้องเช็กหน้า/ไฟใน 1 คลิก

---

## ส่งสถานะ AI / งาน Render ขึ้น Notch ผ่าน Local API

```bash
./scripts/notch-notify.sh yt-1 "yt-creative-mcp" running "Analyzing YouTube Edit" "Detecting cuts & 124 BPM" 0.68
```

หรือด้วย `curl`:
```bash
curl -X POST http://127.0.0.1:47890/v1/activity \
  -H 'Content-Type: application/json' \
  -d '{"id":"fc-render","source":"FilmCraft","state":"running","title":"Rendering Timeline","detail":"1080p60 H.264","progress":0.42}'
```

---

## Build จาก Source (macOS 14+ / Apple Silicon)

```bash
git clone https://github.com/panusbodee-owen/notch-hub.git
cd notch-hub
swift run NotchHubSelfTest
./scripts/package_release.sh
open dist/NotchHub.app
```
