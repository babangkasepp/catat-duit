# CatatDuit 💸

![Build](https://github.com/babangkasepp/catat-duit/actions/workflows/build.yml/badge.svg)
![Quality](https://github.com/babangkasepp/catat-duit/actions/workflows/quality.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-blue)

Aplikasi manajemen keuangan personal — **offline-first**, **Indonesia-first**.

> Catat pengeluaran tanpa ribet. Ketik aja `50rb kopi`, app langsung deteksi nominal dan kategori.

---

## ✨ Fitur Utama

- **Quick input bahasa natural** — `50rb kopi`, `gajian 8jt`, `bayar listrik 350rb`
- **16 kategori Indonesia-first** — Makan & Minum (warteg, kopi kekinian), Transport (gojek, ojol, e-toll), Tagihan (PLN, indihome, BPJS), Sosial (kondangan, amplop), dst.
- **Auto-deteksi pemasukan** dari kata kunci (`gaji`, `bonus`, `thr`, `cuan`, `dapet`)
- **Laporan visual** — saldo bulanan, pie chart kategori, ringkasan tahunan
- **Budget per kategori** dengan progress bar + alert lewat budget
- **Reminder harian** offline (notification, gak butuh server)
- **100% offline** — semua data nyimpen di SQLite di HP, gak butuh internet, gak butuh login
- **Material You** theme — auto light/dark mode mengikuti sistem

## 🏗️ Arsitektur

```
UI (Material 3 + GoRouter)
   ↓
Riverpod (state)
   ↓
Repository
   ↓
SQLite (sqflite) ← semua read/write ke sini
```

**Prinsip offline-first:** semua aksi user → local DB. Sync cloud (kalau ada) cuma di background, gak block UI.

## 📂 Struktur Proyek

```
lib/
├── main.dart
├── app/
│   ├── theme.dart           # Material 3 theme + dark mode
│   ├── router.dart          # go_router config
│   └── providers.dart       # Riverpod providers global
├── core/
│   ├── db/database.dart     # sqflite setup + seed kategori
│   ├── notifications/       # Local notifications
│   └── utils/formatters.dart # Money.format, DateRange
├── features/
│   ├── transactions/
│   │   ├── models/
│   │   ├── parser/          # AmountParser, TransactionParser
│   │   └── repository/
│   └── budget/
├── screens/                 # Home, Add, List, Reports, Budget, Settings
└── widgets/
assets/
└── keywords.json            # 16 kategori + ~200 keyword Indo
```

## 🚀 Cara Build

### 1. Persiapan

Pastikan udah install:

- Flutter SDK ≥ 3.19 → https://docs.flutter.dev/get-started/install
- Android Studio (buat Android SDK + emulator)
- HP Android (kalau mau install langsung) atau emulator

Cek instalasi:

```bash
flutter doctor
```

### 2. Setup Proyek

```bash
cd catat-duit
flutter pub get
```

### 3. Run di HP / Emulator

Sambungin HP Android (USB debugging on) atau jalanin emulator, terus:

```bash
flutter run
```

App bakal langsung jalan dalam mode debug.

### 4. Build APK Release

```bash
flutter build apk --release
```

APK output ada di:
```
build/app/outputs/flutter-apk/app-release.apk
```

Tinggal copy ke HP, install, langsung pake.

### 5. Build App Bundle (buat Play Store)

```bash
flutter build appbundle --release
```

## 🎨 Customization

### Tambah/edit kategori

Edit `assets/keywords.json`. Contoh tambah kategori baru:

```json
{
  "id": "olahraga",
  "name": "Olahraga",
  "icon": "🏃",
  "color": "#00CEC9",
  "type": "expense",
  "keywords": ["gym", "fitness", "yoga", "treadmill", "lari"]
}
```

Hapus database lama (uninstall app) biar seed jalan ulang.

### Ubah warna theme

Edit `lib/app/theme.dart`:

```dart
static const _seed = Color(0xFF6C5CE7);  // ganti warna utama
```

## 🔒 Privasi

Aplikasi ini **100% offline-first**:
- Data transaksi disimpan di SQLite lokal (`catat_duit.db`)
- **Tidak ada** server, tidak ada cloud, tidak ada login
- **Tidak ada** analytics atau tracking
- Permission yang dipake:
  - `CAMERA` & `READ_MEDIA_IMAGES` — buat OCR struk (rencana v0.2)
  - `POST_NOTIFICATIONS` — buat reminder harian
  - `SCHEDULE_EXACT_ALARM` — buat reminder akurat

## 🗺️ Roadmap

**v0.1 (current)** — Core MVP
- ✅ Input transaksi + parser bahasa natural
- ✅ Kategori Indonesia-first
- ✅ Laporan harian/bulanan/tahunan
- ✅ Budget bulanan + alert
- ✅ Reminder harian
- ✅ Material You + dark mode

**v0.2 — Smart Features**
- [ ] OCR foto struk (offline, ML Kit on-device)
- [ ] Streak tracking + gamification
- [ ] Export PDF report
- [ ] Year-in-review (Wrapped style)

**v0.3 — Cloud (optional)**
- [ ] Backup encrypted ke Supabase
- [ ] Multi-device sync
- [ ] Family sharing

**v0.4 — Pro**
- [ ] AI insight (LLM-powered, optional online)
- [ ] Tracking utang/piutang
- [ ] Multi-akun (cash, e-wallet, bank — manual)

## 📝 Lisensi

MIT — pake aja, modif aja, tapi mention sumbernya kalau redistribute publicly.

## 🙏 Kontribusi

Issue dan PR welcome banget. Sebelum bikin PR besar, buka issue dulu buat diskusi arah implementasi.

---

## 🚢 Release & Distribusi

CI/CD otomatis lewat GitHub Actions:

```bash
git tag v0.1.0
git push origin v0.1.0
# → CI build APK signed + bikin GitHub Release otomatis
```

Detail lengkap: [`RELEASE.md`](./RELEASE.md)
Kontribusi: [`CONTRIBUTING.md`](./CONTRIBUTING.md)

---

**Built with ❤️ for Indonesian users**

Catatan: Ini MVP sehat — bisa langsung di-build, dipake, dan dikembangin. Tetap perlu real-device testing buat validasi UX di berbagai HP Android.
