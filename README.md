# FAI_WinOP

[![CI](https://github.com/MrFedai/FAI_WinOP/actions/workflows/ci.yml/badge.svg?branch=dev)](https://github.com/MrFedai/FAI_WinOP/actions/workflows/ci.yml)

Windows 11 için profil odaklı, nesne tabanlı optimizer. Format sonrası tek komut: profildeki ayarlar, uygulamalar ve
masaüstü / görev çubuğu düzeni uygulanır. Her değişiklikten önce anlık görüntü alınır; `-Undo` anlık görüntüyle önceki duruma döner. Geri alınamayanlar: kaldırılan AppX'in provisioned kopyası (`bloat.persistence`; Store'dan yeniden kurulur), kurulan Windows güncellemeleri, yeniden başlatma, varsayılan tarayıcı (Ayarlar'dan elle) ve Sistem Geri Yükleme noktası oluşturma.

> **Durum: ilk yayın öncesi (v0.1.0 hazırlanıyor).** Fazlar 1–9 tamam; yayın etiketlenene kadar aşağıdaki komut çalışmaz.

Yönetici PowerShell'de (önce önizleme):

```powershell
& ([scriptblock]::Create((irm https://github.com/MrFedai/FAI_WinOP/releases/latest/download/get.ps1))) -Profile fedai -DryRun
```

`get.ps1` sürümdeki `install.ps1`'i indirir, yayımlanan `install.ps1.sha256` ile doğrular; tutmazsa çalıştırmaz.
`%TEMP%`'teki dosya doğrudan çalıştırılmaz: yönetici süreci (UAC sonrası) onu `%ProgramData%` altında her seferinde yeni açılan,
yalnız SYSTEM + Administrators'ın yazabildiği klasöre kopyalar, özeti orada yeniden doğrular ve yalnız o kopyayı çalıştırır.
**SHA-256 yalnız bozulmayı (yarım / değişmiş indirme) yakalar, kaynağı kanıtlamaz:** özet de aynı yerden indirilir.
İmza / attestation sonraki sürümlere bırakıldı. `FAI_WINOP_BASEURL` (yalnız test) yalnız `https://` ya da
`http://localhost` / `http://127.0.0.1` kabul eder.
Profil yoksa Türkçe menü açılır. Diğer parametreler: `-Unattended`, `-Undo [-Session <kimlik>] [-SkipFailed]` (geri alınamayan kayıtları atlayıp oturumu kapatır), `-Only` / `-Skip`,
`-UpdatesOn` / `-UpdatesOff`, `-ExportProfile <ad>`, `-ExportLayout`, `-Version vX.Y.Z`, `-List`, `-AllowOtherUser`
(`Get-Help .\install.ps1 -Detailed`). Tweak, katalog ve profil verisi `install.ps1`'e gömülüdür.

**Başka hesapla yükseltme:** UAC'de başka bir yönetici hesabının bilgileri girilirse araç o hesapla çalışır; HKCU ayarları,
masaüstü ve görev çubuğu / Başlat sabitlemeleri oturum sahibinin değil, o hesabın profiline gider. Bu durumda yönetici
gerektiren her iş (önizleme `-DryRun` dahil) kim yükseltti / oturum sahibi kim yazarak durur (çıkış 3). Bilerek sürdürmek
için `-AllowOtherUser`. Oturum sahibi bulunamazsa uyarıp sürer. `-List`, `-ExportProfile`, `-ExportLayout` denetlenmez.
Yeniden başlatmalarda (UAC, `-Version`, yeniden başlatma sonrası devam) `-Profile .\x.json` gibi göreli yollar mutlak yapılır.

## İlkeler
- **Ayarlar veri, motor sınıf:** her tweak bir `.psd1` dosyası (açıklama, risk seviyesi, koşullar, eylemler).
- **Risk seviyesi:** `Safe` doğrudan, `Caution` onay ister, `Risk` açıkça "EVET" yazdırır; gözetimsiz kipte `Risk` hiç uygulanmaz.
- **Koşullar:** dizüstü, GPU üreticisi, sürüm, derleme numarası… Donanıma uymayan ayar atlanır.
- **Geri alınabilir:** uygulamadan önce snapshot; `-DryRun` hiçbir şey yazmaz; `-Undo -DryRun` geri alınca dönülecek durumu snapshot'tan gösterir.
- **Profiller açık:** kendi profilini yaz (`profiles/`), yerel yoldan ya da URL'den yükle. Profillerde kişisel veri (şifre,
  lisans anahtarı, token, e-posta) bulunmaz.
- **Hedef Windows PowerShell 5.1** (Windows 11 ile gelen); ek kurulum gerekmez.

## Geliştirme
Geliştirme WSL Ubuntu'da (pwsh 7 + Pester 5 + PSScriptAnalyzer), hedef Windows PowerShell 5.1.

```bash
pwsh -NoProfile -File build/Lint.ps1          # PSScriptAnalyzer + 5.1 uyumluluk + UTF-8 BOM
pwsh -NoProfile -c 'Invoke-Pester tests/Unit'  # birim testleri
pwsh -NoProfile -File build/Bundle.ps1        # dist/install.ps1
tools/Sync-ToWindows.sh                       # Windows test kopyası + Windows Sandbox yapılandırması
```

Kurallar: `.ps1 / .psd1 / .psm1` UTF-8 BOM'lu; 5.1'de olmayan sözdizimi (`??`, `?.`, ternary, `&&`) kullanılmaz.
Yol haritası ve mimari: [docs/ROADMAP.md](docs/ROADMAP.md).

## Teşekkür
Bu proje [FR33THY/Ultimate](https://github.com/FR33THYFR33THY/Ultimate) (MIT) projesinden ilham alır. Ultimate'in
ayarlarının mantığı incelenip yeniden tasarlandı; kodu kopyalanmadı.

## Lisans
[MIT](LICENSE)
