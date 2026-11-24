# FAI_WinOP

Windows 11 için profil odaklı, nesne tabanlı optimizer (PowerShell). Format sonrası tek komut → profil (ayarlar +
uygulamalar + masaüstü / görev çubuğu düzeni) uygulanır. Açık GitHub reposu (`MrFedai/FAI_WinOP`, MIT).
Ortak kurallar (yanıt tarzı, çalışma, kesin kurallar, model / işçi, graphify): `~/.claude/CLAUDE.md` (`~/PROJECTS/claude-ortak`).
Burada yalnız bu projenin farkı.

**Her Windows bağımlılığı sağlayıcı arayüzünün arkasında; eylem doğrudan `Set-ItemProperty` vb. çağırmaz.**
Plan, mimari, fazlar ve kabul kriterleri: `docs/ROADMAP.md` (faz kabul edilmeden sonrakine geçilmez).
Durum notu: `~/fai_notes/fai-winop/DURUM.md`.

## Kesin (bu proje)
- Hedef **Windows PowerShell 5.1**. `??`, `?.`, ternary, `&&` / `||`, `ConvertFrom-Json -AsHashtable` yok;
  sınıflar bundle sırasıyla tek dosyada (`build/Bundle.ps1`). Lint (`build/Lint.ps1`) 5.1 uyumunu denetler.
- `.ps1 .psd1 .psm1` dosyaları **UTF-8 BOM'lu** (Türkçe karakter; lint denetler). Satır sonu `.gitattributes`'te.
- Referans `/mnt/c/Users/MrFedai/Desktop/Ultimate` (FR33THY/Ultimate) **yalnız okunur**: mantık incelenir, değerler
  tek tek doğrulanır, **kod kopyalanmaz**, repoya girmez.
- Açık repo: profil / tweak / katalogda **kişisel veri yok** (Wi-Fi şifresi, lisans anahtarı, token, e-posta, kullanıcı adı
  içeren yol). Yollar `%USERPROFILE%` vb. ile. Korsan aktivasyon ve imzasız üçüncü parti ikili dosya yok.

## Çalışma
- Geliştirme dalı `dev`; `main`'e commit ve `v*` etiketi yok (yayın kullanıcıda).
- Lint: `pwsh -NoProfile -File build/Lint.ps1` · birim: `pwsh -NoProfile -c 'Invoke-Pester tests/Unit -Output Detailed'`
  (Pester 5.7.1 + PSScriptAnalyzer 1.25.0, `CurrentUser`) · bundle: `pwsh -NoProfile -File build/Bundle.ps1` → `dist/install.ps1`.
- Windows testleri WSL yolundan değil, **`tools/Sync-ToWindows.sh` kopyasından** çalışır (`%USERPROFILE%\FAI_WinOP_test`;
  `powershell.exe` 5.1 ve Windows Sandbox UNC yolu desteklemez). Önce sync, sonra
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\<kullanıcı>\FAI_WinOP_test\...'`.
- Sandbox: sync sonrası kopyadaki `tests\Sandbox\FAI_WinOP.wsb` açılır; sonuç `FAI_WinOP_test\out\`.
- Gerçek makinede kayıt defteri / servis değiştiren deneme yok; o iş Sandbox, Hyper-V VM ya da Windows CI'da.
