# 99 Nights in the Forest — tersine mühendislik

Kaynak: kullanıcının verdiği `99 nights int he forest.lua` (117.470 bayt).

SHA-256: `b8e0498067e40076206fe34418450a9fb6b350ee37470cb869ae1d5a01f6df64`

Dosya çalıştırılmadan incelendi. Başlık `WeAreDevs obfuscator v1.0.0` diyor;
arayüz alt başlığı `by pol`. Bunlar dosyadaki etiketlerdir; yazar kimliği
bağımsız olarak doğrulanmadı. Orijinal dosya değiştirilmedi.

## Çözümleme

- Altı Luau bileşik ataması yalnızca çözümleyicide `k -= m` → `k = k - m`
  biçimine dönüştürüldü. Ardından sözdizimi ağacı çıkarıldı.
- 541 elemanlı kaçışlı metin tablosu, sırayla `1..541`, `1..265`, `266..541`
  aralıklarında ters çevriliyor. Özel Base64 alfabesi çözüldü; erişim
  `e(index) = strings[index - 2537]` biçiminde.
- `l` durum sayacı kullanan sanal makinede 323 durum bloğu ayrıştırıldı.
- İkinci katmandaki 421 metin çözme çağrısı statik sabit takibiyle çözüldü.
  Tablonun yazdırılamayan baytlar içeren bütün değerlerinin kullanımı kapsandı.
- İkinci çözücü 45 bit durumunu `(state * 237 + 34532620664527) % 2^45`
  ile güncelliyor. Diğer durum `% 255 + 2` ile başlıyor, `* 14 % 257` ile
  ilerliyor ve 1 olursa tekrarlanıyor. İlk önceki bayt 106; her açık bayt
  `(şifreli bayt + rastgele bayt + önceki açık bayt) % 256` ile elde ediliyor.
  Dört rastgele bayt 32 bit kaydırma/döndürme hesabıyla üretiliyor.

Bu çalışma orijinal değişken isimlerini veya kaynak biçimini birebir geri
getirmez. Temiz yeniden uygulama `Games/NightsInTheForest/Controller.luau`,
veri listesi ve sabitler ise `Catalog.luau` içindedir.

## Kaynaktaki özellikler

| Özellik | Geri çıkarılan davranış | İşlev giriş durumu |
| --- | --- | --- |
| Kamp ateşine dönüş | Karakteri `(0, 10, 0)` konumuna PivotTo ile taşır | `13180590` |
| Öğütücüye dönüş | `(16.1, 4, -4.6)` | `6919447` |
| Eşyaya ışınlanma | 69 isim için düğme; adı eşleşen Model ve geçerli pivot/ilk parça; orijinden en az 50 stud, hedefin 5 stud üstü | `4270074` |
| Item ESP | Listedeki nesneler, Humanoid içeren modeller hariç; kamp çevresindeki 50 stud filtrelenir; etiket ve Highlight | `12126343`, `6821333` |
| NPC ESP | Sekiz NPC adı, HumanoidRootPart, Drawing kutusu ve ad etiketi | `3673440`, `5744639`, `13570110` |
| Küçük ağaç toplama | Parent adı Small Tree olan Trunk parçaları; orijinden 50 stud dışında, karaktere uzaklığa göre sıralı; 3 stud üstüne ışınlanıp 0,2 saniyede bir tıklar | `1395737` |
| Ağaç zaman aşımı | 12 saniyede bitmezse o ağacı oturum boyunca atlar | `12560864` |
| Aimbot | Sağ tuş tutulurken sekiz NPC'nin Head parçalarından ekranda ve fareye 100 piksel içinde en yakınını seçer; 0,02 saniye kontrol, CFrame:Lerp katsayısı 0,2 | `8540603` |
| Uçuş | Q anahtarı, hız 60; WASD ve kamera UpVector yönünde Space/Left Shift; BodyVelocity ve BodyGyro | `825860`, `9840245`, `11843173` |

NPC listesi: Alien, Alpha Wolf, Wolf, Crossbow Cultist, Cultist, Bunny, Bear,
Polar Bear. 69 hedefin eksiksiz listesi `Catalog.Items` içindedir. Kaynakta
bütün otomasyon anahtarları başlangıçta kapalıdır.

Doğrudan görülen HTTP erişimi `https://sirius.menu/rayfield` arayüzünü indirip
çalıştırıyor. Rayfield içeriği çalıştırılmadı. Kaynak, kendi `mouse1click`
globalini VirtualInputManager bas/bırak çağrılarıyla yeniden tanımlıyor.
Bu dosyada oyun sunucusuna yönelik FireServer/InvokeServer protokolü bulunmadı.
Sunucu tarafındaki mesafe, yetki veya fizik kontrollerini kaldırdığı doğrulanamaz.

## Oyun yönlendirmesi

Roblox'un yer → evren API'si iki yerin de `7326934954` evrenine ait olduğunu
doğruladı:

- [Lobi: 79546208627805](https://apis.roblox.com/universes/v1/places/79546208627805/universe)
- [Orman yeri: 126509999114328](https://apis.roblox.com/universes/v1/places/126509999114328/universe)

Katalog evreni ve bu iki yeri tanır. Lobi girişinde yalnızca Home, bilgi ve
ayarlar açılır; orman koordinatlarına ışınlanma ve otomasyon başlatılmaz.
Orman maçına girdikten sonra ana yükleyici tekrar çalıştırılır.

## Abysall uyarlaması

- Rayfield yükleyicisi yerine seçili Linoria/Obsidian ve ortak Home/ayarlar
  kullanılır. Yeni kayıt klasörü `Abysall/NightsInTheForest`, eklenti anahtarı
  `nightsintheforest` olur.
- 69 ayrı düğme, aynı isimleri içeren seçim listesi ve tek ışınlanma düğmesine
  dönüştürüldü. En yakın geçerli eşleşme seçilir; BasePart hedefler de desteklenir.
  Manuel ışınlanma ağaç otomasyonunu kapatır.
- ESP ortak Abysall kütüphanesindeki ad/Highlight görünümünü kullanır. NPC'ler
  için eski Drawing kutuları oluşturulmaz. Aimbot çemberi yerel GUI ile çizilir;
  Drawing API bağımlılığı yoktur. Ekran/fare GUI inset farkı hesaba katılır.
- Sahne bir kez indekslenir, yeni ve kaldırılan nesneler olaylarla takip edilir.
  Her aimbot kontrolünde bütün Workspace yeniden taranmaz.
- Oyuncu karakterleri NPC/hedef listesine alınmaz. Ölü Humanoid hedefleri
  elenir; eksik parça, kamera, yeniden doğuş ve karakter ölümü tolere edilir.
- Uçuş yalnızca bu modülün oluşturduğu kuvvetleri kaldırır, önceki AutoRotate
  değerini geri getirir. Başka scriptlerin BodyVelocity/BodyGyro nesneleri silinmez.
- Ağaç toplama uçuş sırasında bekler. Hatalı fare girdisi otomasyonu kapatır;
  global mouse1click fonksiyonu değiştirilmez. Zaman aşımı kayıtları nesne
  kimliğine bağlıdır; yeni doğan bir ağaç aynı isim yüzünden engellenmez.
- Unload bağlantıları, ESP nesnelerini, kuvvetleri ve çemberi temizler.

Canlı Roblox oturumu veya sunucu kabulü üzerinde test yapılmadı.

## Yerel doğrulama

- 27 oyun/arayüz kontrolü: hedef listeleri, mevcut/yeni/silinen nesneler,
  oyuncu ve ölü NPC filtreleri, yakın hedef seçimi, karakter yokluğu/ölümü,
  tıklama aralığı ve zaman aşımı, uçuş/yeniden doğuş, GUI inset ve kamera
  değişimi, profil bağlama, GUI çemberi, fare girdisi hataları ve unload.
  Roblox nesneleri, sinyaller ve fizik bu kontrollerde taklit edildi.
- Ortak yükleyici/arayüz için 33 entegrasyon kontrolü: iki UI stili,
  lobi/orman rotaları, Home kataloğu, ön indirme ve mevcut oyun rotaları dahil.
- Yeni Main, Lobby, Loader, Catalog, Controller ve güncel GameRegistry resmi
  Luau derleyicisiyle derlendi. Kaynaktan çıkarılan 69 hedef, yeni katalogla
  birebir karşılaştırıldı; özgün dosyanın SHA-256 değeri tekrar doğrulandı.
