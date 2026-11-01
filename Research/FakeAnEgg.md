# Fake an Egg — tersine mühendislik ve Abysall desteği

Kaynak, kullanıcının verdiği `fakeanegg.lua` dosyasıdır: **74.130 bayt**.
Özgün dosya değiştirilmedi ve oyun/yükleyici kodu çalıştırılmadı.

- Dosyanın SHA-256 değeri: `0c0c06d289cb617bf3ba81882129cbe86fc7d86bff96a4b1f11cb4ac8325bff9`.
- CRLF → LF sonrası SHA-256: `3bb85d19824b4e9d7adc373377041f0661e3a7182c2ebe4d0ad1a8c0dc56a70d`.
- Başlık `MoonVeil 2.1.0`, arayüz adı `FAKE AN EGG`, alt yazı
  `YOUTUBE: SPIRITUAL GAMING`. Bunlar dosyada bulunan etiketlerdir;
  yazar kimliği bağımsız olarak doğrulanmadı.

## Çözümleme

58 sıralı alan, kaynakta bulunan isim tablosuna sıfır tabanlı
`(100193 * index + 2049) % 58` konumuyla bağlanır. Üç açık isimli alanla
birlikte **61 alan** elde edilir. `a/b/c/d`, sırasıyla `bit32.band`,
`bor`, `bxor`, `bnot` işlemleridir.

`V`, aşağıdaki alfabeyle Base85 bayt çözümlemesi yapar. Beş karakterden
dört büyük sıralı bayt üretilir; son kısa grup `~` ile tamamlanıp fazla
baytlar atılır.

```text
0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~
```

`la`, çözülen veriyi tekrarlanan anahtarla ileri yönde XOR'lar; `ra`,
anahtarı ters yönde kullanır. `ma/na/oa/pa/sa/ta/ua/va` yardımcıları,
aritmetik ve bit işlemleriyle durum sabitlerini hesaplar.

**805 sabit çözme ifadesinin tamamı** çözüldü. Bunların 669'u metin
sonucudur; **146 farklı metin** bulunur. Bayt/bit yardımcıları sınırlı
bir Luau ortamında ayrı olarak kontrol edildi. Daha sonra yazılan
JavaScript çözücüsünün 805 sonucu da bu sonuçlarla birebir karşılaştırıldı.
Özgün giriş noktası, oyun API'leri ve dış yükleyiciler çalıştırılmadı.

- [functions.txt](FakeAnEgg/functions.txt): Açılmış sabitlerle 61 alanın
  okunabilir inceleme dökümü. Durum makineleri ve closure yakalamaları
  korunur; çalıştırılabilir bir yedek script değildir.
- [strings.json](FakeAnEgg/strings.json): Çözülen 669 metin ifadesi.
- [manifest.json](FakeAnEgg/manifest.json): Parmak izleri ve çıktı sayıları.
- [Çözücü](../Tools/decode-fakeanegg.cjs): Özgün Lua'yı çalıştırmayan,
  yalnızca tanınan dosya parmak izini kabul eden çevrimdışı araç.

Çözümleyici aralıkları, token'ları normalleştirilmiş ara metindeki
konumlardır; özgün dosyanın satır numaraları değildir. Bu çalışma özgün
değişken adlarını ve kaynak biçimini geri getirmez. Çalışan temiz uyarlama
`Games/FakeAnEgg/Controller.luau`, sabitler `Catalog.luau` içindedir.

## Kaynaktan çıkarılan özellikler

| Özellik | Protokol ve davranış | Kaynaktaki alanlar |
| --- | --- | --- |
| Auto Hatch | `ReplicatedStorage.RemoteEvents.OpenBlockEvent:FireServer(tostring(slot))`; 1–20 sırası, her slotta 0,3 saniye, tur sonunda ek 0,1 saniye | `F`, `G`, `t` |
| Auto Rebirth | `RemoteEvents.RebirthEvent:FireServer()`; argümansız, 1 saniye aralıkla | `D`, `E`, `r` |
| Auto Sell All | `RemoteEvents.SellAllEvent:FireServer("Pets")`; 1 saniye aralıkla | `A`, `B`, `o` |
| Nadirliğe göre Auto Steal | `Workspace.ClientEggs` içinden uygun rastgele hedef; 3 stud üstüne gitme, 0,3 saniye bekleme, prompt'u iki kez tetikleme, aralarda 0,5 saniye, kendi üssünün `Collect` noktasına dönüş | `x`, `w`, `n`, `y`, `z` |

11 nadirlik: **Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret,
Exotic, Divine, Celestial, Admin**.

Nadirlik yolu `egg.InfoGui.Frame.CharRarity`; kaynak bu nesnenin altındaki
isim işaretlerine veya metin etiketlerine bakar. Üsler `Workspace.Bases`
içindedir. Kendi üssü, oyuncu adına eşit isim, `Creator/Owner` özniteliği
veya oyuncuyu belirten `StringValue/ObjectValue` üzerinden bulunur.
`Collect`, parçaysa CFrame'i, modelse pivotu kullanılır; hedef 3 stud üstüdür.

Kaynak ayrıca yerel dosyaya anahtar kaydeden, panoya bağlantı kopyalayan ve
Pastebin üzerinden kontrol metni isteyen bir giriş ekranı içerir. Bu dış
akış alınmadı; bağlantıları çağrılmadı. Kaynakta ESP, uçuş veya hız özelliği
bulunmadığından bunlar yeni modüle eklenmedi.

## Oyun kimliği ve yönlendirme

Kaynakta gömülü bir PlaceId bulunmadı. Oyun kimliği, 1 Kasım 2026'da
Roblox'un resmi API'lerinden ayrıca doğrulandı:

- [Yer → evren eşlemesi](https://apis.roblox.com/universes/v1/places/97289366402005/universe):
  PlaceId **97289366402005** → GameId/UniverseId **10769384180**.
- [Oyun bilgisi](https://games.roblox.com/v1/games?universeIds=10769384180):
  `[🎃] Fake an Egg`, yapımcı **Slime Time Studios**, kök yer aynı PlaceId.
- [Oyun sayfası](https://www.roblox.com/games/97289366402005/Fake-an-Egg).

`Components/GameRegistry.luau` hem evreni hem yeri `FakeAnEgg` modülüne
yönlendirir. Bağımlılıklar ana yükleyiciyle önceden indirilir; Home listesi
aynı kayıttan otomatik oluşur. Bu modül, PlaceId `107778070777162` olan
**Steal An Egg** modülünden ayrıdır. Profiller `Abysall/FakeAnEgg` altına
kaydedilir.

## Abysall uyarlaması ve doğrulama

Seçili Linoria/Obsidian, ortak Home ve ayarlar kullanılır. Dört otomasyon
başlangıçta kapalıdır; Auto Steal için çoklu nadirlik seçimi vardır.
Kaynakta her nadirliğin başlattığı ayrı ışınlanma döngüsü, tek Heartbeat
zamanlayıcısında birleştirildi. Geciken karelerde birikmiş istekler topluca
gönderilmez. Geç yüklenen remote'lar beklenirken menü bloke edilmez.

`Common`, `Uncommon` metnine yanlışlıkla eşleşmez. Eksik veya ölü karakter,
kaldırılmış yumurta, eksik prompt/Collect noktası ve yeniden doğuş kontrol
edilir. Auto Steal kapatılınca, nadirlikler değişince veya modül
boşaltılınca bekleyen işlem iptal edilir ve değiştirilmiş `HoldDuration`
geri yüklenir. Unload, Heartbeat bağlantısını kapatır. Gerekli prompt API'si
yoksa ilgili anahtar açılmaz; bir remote hatası diğer otomasyonları kapatmaz.

- **28 modül/arayüz kontrolü geçti:** remote argümanları ve zamanlamaları,
  20 slot sırası, nadirlik eşleştirme, iki prompt adımı, üs sahipliği ve
  dönüşü, iptal/yeniden doğuş, profil bağlama, hata ve unload temizliği.
- **34 ortak yükleyici/arayüz kontrolü geçti:** iki UI stilinde yer ve evren
  yönlendirmesi, Home bilgileri, tekil bağımlılık indirmeleri ve mevcut
  oyun rotalarının korunması dahil.
- Yeni modül dosyaları ve oyun kataloğu resmi Luau derleyicisiyle derlendi.
  Testlerde Roblox nesneleri, sinyalleri ve sunucu çağrıları taklit edildi.

**Canlı Roblox oturumu ve sunucunun bu çağrıları kabul etmesi test edilmedi.**

## Çözümlemeyi tekrar üretme

Node.js ve `luaparse@0.3.1` gerekir. Bağımlılık ayrı bir araç klasörüne
kurulabilir. Modülün yolu üçüncü argümanla verilebilir:

```powershell
node Tools/decode-fakeanegg.cjs "C:/path/to/fakeanegg.lua" "C:/analysis/fakeanegg" "C:/tools/node_modules/luaparse"
```

Araç `manifest.json`, `constants.json`, `strings.json`, `functions.txt` ve
`decoded-methods.json` üretir. Genel bir Lua yürütücüsü kullanmaz; yalnızca
izinli aritmetik, bayt/bit işlemleri ve iki sabit önbelleğine erişim vardır.
