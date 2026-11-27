#!/usr/bin/env bash
# Depoyu Windows test kopyasına aynalar: powershell.exe (5.1) ve Windows Sandbox WSL / UNC yolunu kullanamaz.
#
#   tools/Sync-ToWindows.sh          bundle üret → kopyala → Sandbox dosyasını yaz (parametresiz tam iş)
#
# Hedef: %USERPROFILE%\FAI_WinOP_test (FAI_WINOP_TEST_DIR=<Windows yolu> ile değişir)
#   repo\                 depo aynası: izli + izlenmeyen (gitignore dışı) dosyalar + dist\install.ps1 + dist\install.fakes.ps1.
#                         Ayna: depoda olmayan dosyalar buradan silinir (silinenler listelenir); yalnız bu klasör.
#   out\                  Sandbox sonuçları (run-*.log, SONUC.txt); dokunulmaz
#   FAI_WinOP.wsb         tests/Sandbox/FAI_WinOP.wsb, yollar doldurulmuş; çift tıkla ya da aşağıdaki komut
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -n "${FAI_WINOP_TEST_DIR:-}" ]]; then
  win_dir="$FAI_WINOP_TEST_DIR"
else
  userprofile="$(cd /mnt/c && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  [[ -n "$userprofile" && "$userprofile" != *'%'* ]] || { echo "ERROR: could not read %USERPROFILE%; set FAI_WINOP_TEST_DIR." >&2; exit 1; }
  win_dir="${userprofile}\\FAI_WinOP_test"
fi
dest="$(wslpath -u "$win_dir")"

echo "[1/4] Building bundle (build/Bundle.ps1: dist/install.ps1 + dist/install.fakes.ps1 for tests)"
if command -v pwsh >/dev/null; then
  pwsh -NoProfile -NonInteractive -File "$repo/build/Bundle.ps1" | sed 's/^/      /'
  pwsh -NoProfile -NonInteractive -File "$repo/build/Bundle.ps1" -IncludeFakes | sed 's/^/      /'
else
  echo "      WARNING: pwsh not found, bundle not built (dist/ is copied as is)"
fi

echo "[2/4] Mirroring repo → $win_dir\\repo"
mkdir -p "$dest/repo" "$dest/out"
rlog="$(mktemp)"
trap 'rm -f "$rlog"' EXIT
# Çıktı: itemize satırları + progress2 (\r ile güncellenen yüzde / hız / tahmini bitiş); yüzde satırı canlı gösterilir.
rsync -a --delete --itemize-changes --info=progress2 \
  --include='/dist/' --include='/dist/**' \
  --exclude='/.git/' --exclude='/.devops.toml' \
  --filter=':- .gitignore' \
  "$repo/" "$dest/repo/" | tr '\r' '\n' | tee "$rlog" \
  | { grep -a --line-buffered '%' || true; } \
  | while IFS= read -r pl; do printf '\r      %s   ' "$pl" >&2; done
rs=("${PIPESTATUS[@]}")
echo >&2
[[ "${rs[0]}" -eq 0 ]] || { echo "ERROR: rsync failed (exit ${rs[0]})" >&2; exit 1; }
changes="$(grep -a -v '%' "$rlog" || true)"
copied="$(grep -c '^>f' <<<"$changes" || true)"
deleted="$(grep '^\*deleting' <<<"$changes" || true)"
echo "      files copied / updated: $copied"
if [[ -n "$deleted" ]]; then
  echo "      removed from the mirror (no longer in the repo):"
  sed 's/^\*deleting */        /' <<<"$deleted"
fi

echo "[3/4] Writing Sandbox configuration → $win_dir\\FAI_WinOP.wsb"
esc="${win_dir//\\/\\\\}"   # sed yer değiştirme metninde özel: \ & ve sınırlayıcı |
esc="${esc//&/\\&}"
esc="${esc//|/\\|}"
sed -e "s|__TEST_DIR__|${esc}|g" -e 's/\r$//' -e 's/$/\r/' "$repo/tests/Sandbox/FAI_WinOP.wsb" > "$dest/FAI_WinOP.wsb"

echo "[4/4] Ready. Example commands:"
echo "      powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$win_dir\\repo\\tests\\Integration\\Load-Bundle.ps1'"
echo "      powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$win_dir\\repo\\tests\\Integration\\Engine-Smoke.ps1'"
echo "      cmd.exe /c start \"\" \"$win_dir\\FAI_WinOP.wsb\"     (result: $win_dir\\out\\SONUC.txt)"
