# Contributing

PR welcome! Workflow simple:

1. **Fork** + clone
2. Bikin branch dari `main`: `git checkout -b feat/nama-fitur`
3. Code + test: `flutter test`
4. Format: `dart format lib test`
5. Push + buka PR ke `main`

## Quality Gate

PR harus pass:
- `dart format --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`
- `flutter test`

CI bakal jalanin ini otomatis. Cek `.github/workflows/quality.yml`.

## Commit Message

Pake [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: tambah OCR foto struk`
- `fix: parser nominal "1,5jt" salah deteksi`
- `chore: bump deps`
- `docs: update README`
- `refactor: pisahin BudgetCard ke widget`
- `test: tambah test parser`

## Release

Maintainer only — lihat [`RELEASE.md`](./RELEASE.md).
