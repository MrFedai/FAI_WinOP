# Uygulama kataloğu ve kurulum (Faz 4)

Kaynak: [`apps/catalog.json`](../apps/catalog.json) (biçim: [`apps/_schema.json`](../apps/_schema.json), doğrulama
`src/Core/AppCatalog.ps1`). Profil `apps` listesinde kimlik verir; motor her uygulamayı tweak'lerden **sonra**
`app.<id>` tweak'i olarak işler (dry-run, rapor, snapshot, `-Undo` aynı yol).

```json
"apps": [ "chrome", "spotify", { "id": "telegram", "keepAutostart": true } ]
```

## Kurulum sonrası kurallar

| Alan | Ne yapar |
| --- | --- |
| `removeAutostart` + `startupRegistryNames` / `startupFolderNames` | Run değeri ya da Başlangıç klasörü kısayolu **silinmez**; Görev Yöneticisi'nin "Devre dışı bırak"ı gibi `Explorer\StartupApproved` altına kapalı işareti (`03…`) yazılır. Uygulama Run değerini yeniden yazsa da kapalı kalır, kullanıcı Görev Yöneticisi'nden açabilir. Jokersiz ad, değer henüz yokken de HKCU'da önceden kapatılır (ilk açılışta yazan uygulamalar için). |
| `startupTaskNames` | Oturum açılışında uygulamayı başlatan zamanlanmış görevi kapatır. |
| `removeDesktopShortcut` + `desktopShortcutNames` | Kurulum sırasında kullanıcı / ortak masaüstüne eklenen **her** `.lnk` silinir (önce / sonra karşılaştırması); adı listede olanlar her çalıştırmada silinir (güncellemeyle geri gelenler). |
| `flattenStartMenu` + `startMenuFolders` | Başlat > Programlar altındaki klasörün kısayolları köke taşınır, kaldırma kısayolları ve `.url`'ler silinir, boş klasör silinir. |
| profilde `keepAutostart` | O uygulamanın otomatik başlatma kuralı uygulanmaz (fedai: WhatsApp, Telegram). |

Geri alma (`-Undo`): eylem her dosyaya / değere / göreve dokunmadan önce eski hâlini oturum günlüğüne yazar. Uygulama o
çalıştırmada kurulduysa kaldırılır ve bizim taşıdığımız / yazdığımız her şey silinir; zaten kuruluysa silinen kısayollar,
taşınan klasör ve StartupApproved değerleri birebir geri gelir.

Bilinen sınır: Electron uygulamaları (Discord, Claude) "açılışta başlat" ayarı açıkken `StartupApproved`'ı da yeniden
"açık" yapabilir. Profil yeniden çalıştırıldığında tekrar kapatılır; kalıcı çözüm uygulamanın kendi ayarı.

## Paket kimlikleri

12 kimliğin hepsi 2026-11-24'te `winget show --id <kimlik> --exact --source <kaynak>` ile doğrulandı (winget 1.29).
Yeniden doğrulama: [`tests/Integration/App-Ids.ps1`](../tests/Integration/App-Ids.ps1) (salt okunur; Windows CI'da her
push'ta koşar).

| id | Paket | Kaynak | Kurucu |
| --- | --- | --- | --- |
| claude | `Anthropic.Claude` | winget | exe |
| telegram | `Telegram.TelegramDesktop` | winget | inno |
| whatsapp | `9NKSQGP7F2NH` | msstore | Store (MSIX) |
| discord | `Discord.Discord` | winget | exe (Squirrel) |
| steam | `Valve.Steam` | winget | nullsoft |
| tradingview | `TradingView.TradingViewDesktop` | winget | msix |
| ollama | `Ollama.Ollama` | winget | inno |
| vscode | `Microsoft.VisualStudioCode` | winget | inno (kullanıcı kapsamı) |
| protonvpn | `Proton.ProtonVPN` | winget | inno |
| chrome | `Google.Chrome` | winget | wix (MSI, makine kapsamı) |
| spotify | `Spotify.Spotify` | winget | exe |
| obs | `OBSProject.OBSStudio` | winget | nullsoft |

## Kurulum sonrası adlar: doğrulama durumu

Başlat klasörü adları bu makinede (11 Pro 26H2) okundu: `Telegram Desktop`, `Visual Studio Code` (kullanıcı), `Steam`
(ortak); Chrome ve Spotify kısayolu kökte. Run değeri / masaüstü kısayolu / diğer klasör adları bilinen kurucu
davranışından yazıldı ve **test VM'inde doğrulanacak**: [`tests/Integration/Apps-Install.ps1`](../tests/Integration/Apps-Install.ps1)
gerçek kurulumdan sonra yeni Run değerlerini, Başlangıç öğelerini, Başlat klasörlerini ve StartupApproved durumunu döker;
masaüstünde yeni kısayol kalırsa HATA verir. CI'da `apps` işi (yalnız elle tetikleme: Actions → CI → Run workflow) ya da
Hyper-V VM'de `-Force -Undo` ile.

| id | Run / Başlangıç | Masaüstü | Başlat klasörü | Durum |
| --- | --- | --- | --- | --- |
| claude | `*Claude*` | `Claude.lnk` | `Anthropic`, `Claude` | doğrulanacak |
| telegram | `Telegram Desktop` | `Telegram.lnk` | `Telegram Desktop` ✓ | Run / masaüstü doğrulanacak |
| discord | `Discord` | `Discord.lnk` | `Discord Inc` | doğrulanacak |
| steam | `Steam` | `Steam.lnk` | `Steam` ✓ | Run / masaüstü doğrulanacak |
| ollama | `Ollama.lnk` (Başlangıç klasörü) | `Ollama.lnk` | — | doğrulanacak |
| vscode | — | `Visual Studio Code.lnk` | `Visual Studio Code` ✓ | masaüstü doğrulanacak |
| protonvpn | `ProtonVPN`, `Proton VPN` | `Proton VPN.lnk` | `Proton VPN`, `Proton AG` | doğrulanacak |
| chrome | `GoogleChromeAutoLaunch_*` | `Google Chrome.lnk` | — (kökte ✓) | Run / masaüstü doğrulanacak |
| spotify | `Spotify` | `Spotify.lnk` | — | doğrulanacak |
| obs | — | `OBS Studio.lnk` | `OBS Studio` | doğrulanacak |
| tradingview, whatsapp | MSIX `StartupTask` (yönetilmiyor) | yeni kısayol temizliği | — | — |

Listede olmayan masaüstü kısayolu da kurulum anındaki önce / sonra karşılaştırmasıyla silinir; tahmini adın yanlış olması
yalnız güncellemeyle geri gelen kısayolu etkiler.

## Varsayılan tarayıcı (`setup.default-browser`)

Karar: **programla ayarlanmaz; Ayarlar'da uygulamanın sayfası açılır, kullanıcı "Varsayılan olarak ayarla"ya basar,
araç sonucu denetler.**

- `http` / `https` seçimi `HKCU\...\Shell\Associations\UrlAssociations\<protokol>\UserChoice` (24H2+'da ayrıca
  `UserChoiceLatest\ProgId`) altında, kullanıcıya ve zamana bağlı bir **karma (Hash)** ile tutulur; karma tutmayan
  yazım Windows tarafından sıfırlanır.
- Şubat 2024 güncellemesiyle (Windows 11: KB5034765) gelen **UCPD** sürücüsü (UserChoice Protection Driver) http/https
  ve .pdf UserChoice anahtarlarına (ve üst anahtarlarına) Microsoft dışı süreçlerin yazmasını engelliyor.
- Kalan yollar uygun değil: UCPD servisini kapatıp karmayı hesaplamak (sistem koruması kapatılır, güncellemeyle
  bozulabilir), üçüncü parti imzasız araç (SetUserFTA vb.; repo kuralı: imzasız ikili yok), DISM / grup ilkesi
  varsayılan ilişkilendirme XML'i (yeni kullanıcı profillerine ya da etki alanı makinelerine uygulanır).
- Desteklenen yol: Windows 11 Ayarlar'daki tek tık "Varsayılan olarak ayarla" (Firefox da bunu kullanıyor). Sayfa
  doğrudan açılır: `ms-settings:defaultapps?registeredAppMachine=Google%20Chrome` (Chrome MSI makine geneli kurulur;
  kullanıcı kapsamındaki tarayıcı için `scope = 'User'`).

Davranış: tweak `Caution` (soru sorar); etkileşimsiz kipte uygulanmaz. Uygulandığında sayfayı açar, kullanıcı onaylayınca
`UserChoiceLatest\ProgId` (yoksa `UserChoice`) yeniden okunur; hâlâ farklıysa HATA. Geri alma da elle: önceki tarayıcı
farklıysa Varsayılan uygulamalar sayfası açılır ve günlüğe uyarı yazılır. Bu makinede okunan değer: `ChromeHTML`.

## WhatsApp ve WebView2

- WhatsApp'ın Windows uygulaması (`9NKSQGP7F2NH`) Temmuz 2025'te beta 2.2569.0.0 ile yerel UWP / WinUI sürümünden
  **WebView2 tabanlı** sürüme geçti (web.whatsapp.com'u WebView2 içinde çalıştırır); Kasım 2025 haberlerine göre kararlı sürüm de
  bu (Faz 9'da kurulu sürümle teyit edilecek). Yani WhatsApp **Microsoft Edge WebView2 Runtime olmadan açılmaz**.
- Claude, Discord, Spotify, VS Code, Telegram, Steam, OBS kendi Chromium'unu / Qt'yi taşır; WebView2'ye bağlı değil.
  Microsoft Store, yeni Outlook / Teams ve Windows'un bazı bileşenleri de WebView2 kullanır.
- WebView2 Runtime Windows 11'de sistem bileşenidir ve Edge tarayıcısından **ayrı** kurulur / güncellenir
  (`Microsoft.EdgeWebView2Runtime`, güncelleme EdgeUpdate üzerinden).
- Faz 5 (`bloat.edge-remove`) için sonuç: Edge kaldırılırken WebView2 Runtime ve EdgeUpdate'in WebView2 güncellemesi
  **korunmalı**; Edge'in yeniden kurulmasını engelleyen politika WebView2'yi kapsamamalı. Faz 9'da kontrol: Edge
  kaldırıldıktan sonra WhatsApp açılıyor ve mesaj yüklüyor.

Kaynaklar: [Neowin](https://www.neowin.net/news/whatsapp-for-windows-is-ditching-uwp-for-a-web-app/),
[Notebookcheck](https://www.notebookcheck.net/WhatsApp-ditches-native-Windows-11-app-in-favor-of-Microsoft-WebView2.1063682.0.html),
[TechSpot](https://www.techspot.com/news/108752-whatsapp-dropping-native-windows-app-favor-web-based.html),
[Daring Fireball](https://daringfireball.net/2025/11/meta_whatsapp_windows_shitty_web_app),
[Mozilla: Set Default (UCPD)](https://firefox-source-docs.mozilla.org/widget/windows/shell/set-default.html),
[Microsoft: ms-settings:defaultapps](https://learn.microsoft.com/windows/uwp/launch-resume/launch-default-apps-settings),
[Chromium default_apps_util](https://chromium.googlesource.com/chromium/src/+/606f178bd02294de6187be5c0f4e2dcd86058dfa/base/win/default_apps_util.cc).
