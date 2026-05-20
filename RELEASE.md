# 🚀 Release Guide — CatatDuit

Panduan release APK via GitHub Actions.

## TL;DR

```bash
# Push code ke main → CI auto-build debug APK + jalanin test
git push origin main

# Tag release → CI auto-build APK signed + bikin GitHub Release
git tag v0.1.0
git push origin v0.1.0
```

Hasil download di **Releases** tab repo lu.

---

## 🔁 Workflow Otomatis

### `build.yml` — Main pipeline

| Trigger | Yang Dijalanin | Output |
|---|---|---|
| `push` ke `main` | Lint + test + build debug APK | Debug APK (artifact, 7 hari) |
| `pull_request` ke `main` | Lint + test + build debug APK | Debug APK (artifact, 7 hari) |
| Tag `v*` (push) | Lint + test + build release APK + AAB | **GitHub Release + APK + AAB** |
| Manual dispatch | Sama dengan tag, tapi tanpa Release | Artifact only |

### `quality.yml` — PR gate

Cek `dart format` + `flutter analyze` di setiap PR. Block merge kalau gagal.

---

## 🔐 Setup Signing (Optional tapi Recommended)

Tanpa keystore, APK di-sign pake debug key — masih bisa diinstall, tapi gak bisa upload ke Play Store dan unsafe buat distribusi luas.

### 1. Generate keystore

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Inget password dan alias. **Backup file `.jks` ke tempat aman** — kalau ilang, lu gak bisa update app yang udah ada di Play Store.

### 2. Encode jadi base64

```bash
base64 upload-keystore.jks | tr -d '\n' > keystore.b64
```

### 3. Tambah ke GitHub Secrets

Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Isi `keystore.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | Password keystore |
| `ANDROID_KEY_ALIAS` | `upload` (atau alias lu) |
| `ANDROID_KEY_PASSWORD` | Password key |

### 4. Update `android/app/build.gradle`

Edit bagian `signingConfigs` dan `buildTypes.release`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }

    buildTypes {
        release {
            signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug
            minifyEnabled false
            shrinkResources false
        }
    }
}
```

Sekarang push tag → APK di-sign release key otomatis.

---

## 📦 Cara Bikin Release

### Opsi A: Tag dari local

```bash
# Bump version di pubspec.yaml dulu (e.g. 0.1.0+1 → 0.2.0+2)
git add pubspec.yaml
git commit -m "chore: bump v0.2.0"
git tag v0.2.0
git push origin main --tags
```

CI bakal:
1. Run lint + test
2. Build APK universal + arm64 + arm32 + x86_64
3. Build AAB (buat Play Store)
4. Bikin GitHub Release dengan auto-generated changelog
5. Attach semua APK + AAB ke release

### Opsi B: Manual dispatch

Repo → **Actions** → **Build & Release APK** → **Run workflow** → input tag (optional) → Run.

Hasil di artifacts (gak bikin Release).

---

## 🐛 Troubleshooting

**"Gradle build fail di CI tapi local OK"**
→ Beda Java/Flutter version. Workflow pin Flutter `3.24.5` + Java `17`. Cek `flutter --version` lu sama atau enggak.

**"Keystore not found"**
→ Cek 4 secret udah masuk semua. Tanpa salah satu, fallback ke debug signing.

**"Test fail tapi build dipaksa lanjut"**
→ Sengaja: `quality.yml` strict di PR, tapi `build.yml` pake `continue-on-error: true` buat format/analyze biar gak block release urgent. Test wajib pass.

**"APK gak bisa install di HP — parse error"**
→ Cek `minSdk` di `android/app/build.gradle` (default 23 = Android 6+). HP lebih lama gak support.

**"Gak ada perms buat create Release"**
→ Repo → Settings → Actions → General → Workflow permissions → enable "Read and write permissions".

---

## 🎯 Versioning Convention

Pake [Semantic Versioning](https://semver.org/):

- `v0.1.0` — pre-release MVP
- `v1.0.0` — public stable
- `v1.0.1` — bug fix
- `v1.1.0` — feature baru, backward compatible
- `v2.0.0` — breaking change

Format `pubspec.yaml`:
```yaml
version: 1.0.0+5   # 1.0.0 = display, 5 = build number (must increment per Play Store upload)
```

---

## 📊 CI Status Badge

Tambah ke `README.md`:

```markdown
![Build](https://github.com/USER/REPO/actions/workflows/build.yml/badge.svg)
![Quality](https://github.com/USER/REPO/actions/workflows/quality.yml/badge.svg)
```

Ganti `USER/REPO` sama path repo lu.
