# Cameraman auto farm.lua — açılan BARRAGE katmanları

İkinci paket ve metin katmanları da açıldı: **132 serileştirilmiş fonksiyon,
29.603 VM talimatı ve 392 metin sabiti** çıkarıldı. Bu çıktı, orijinal değişken
isimleri ve kaynak biçimi geri getirilmiş, çalıştırılabilir bir script değildir.
Kendi kendini değiştiren VM işlemleri ve erişilmeyen dolgu talimatları inceleme
listesinde görünür kalır.

**Abysall'a yeni oyun modülü eklenmedi.** Açılan kod ortak yükleyicidir; oyun
modülünü ayrı bir `/script/...` isteğiyle alır. Katalogdaki bir oyunun kimliğini
öğrenmek, o oyunun farm davranışını elde etmek anlamına gelmez.

## Çıktılar

- [functions.txt](Barrage/functions.txt): 132 fonksiyonun sabitleri açılmış
  talimat listesi. `PROTO_0` ana giriş, `Lxxxxx` fonksiyon içindeki talimat
  numarasıdır. `W` yazmaçları, `i` ortamı, `L` üst kapsam değerlerini ve `Z`
  VM yardımcı durumunu gösterir.
- [function-index.json](Barrage/function-index.json): fonksiyon boyutları ve
  içlerinde kullanılan metinler.
- [strings.json](Barrage/strings.json): 392 çözülmüş metin ve sabit kimlikleri.
- [prototypes.json](Barrage/prototypes.json): sayısal, boolean ve metin
  sabitleri ilgili prototip alanlarına yerleştirilmiş tablo grafiği.
- [vm-opcodes.txt](Barrage/vm-opcodes.txt): özgün VM'nin işlem karşılıkları.
- [manifest.json](Barrage/manifest.json): dosya kimlikleri, açma parametreleri
  ve doğrulanan sayımlar.
- [Catalog.md](Barrage/Catalog.md): açık sunucu kataloğundaki 471 kayıt.
  [catalog.json](Barrage/catalog.json) indirilen anlık görüntüdür; Abysall'ın
  destek listesi değildir.

## Kaynak ve çalışma biçimi

Kullanıcının verdiği dosya: `cameraman auto farm.lua`, 407.751 bayt.

SHA-256: `2a8ecd3f5fb1e301b6ed6c44b0dda42ac9175f17fe9ca9a07c14cc8269bd6c59`

2026-11-01'de metin olarak indirilen
[BARRAGE yükleyicisi](https://barrage.cc/loader) 407.727 bayttır. Yerel dosyanın
24 CRLF satır sonu LF'ye dönüştürüldüğünde içerikler birebir eşleşir.
Normalize SHA-256:
`1cf121ef6750c91d826d8266154ed7981aba9da15bbb104abf4e0ad8a8ae4aab`.

Orijinal dosya değiştirilmedi veya Roblox'ta çalıştırılmadı. Araştırma sırasında
ilk VM'nin açıcı talimatları adım sınırı bulunan yerel bir emülatörle izlendi.
Gerçek Roblox, executor, ağ, kullanıcı hesabı ve dosya API'leri verilmedi;
gerekli ortam değerleri bellekte temsil edildi. Bu geçici emülasyon, oyunun
canlı davranışını doğrulamaz.

Projeye eklenen son çözücü bu emülasyona ihtiyaç duymaz: VM kapanışını oluşturan
fonksiyon gövdesi derlenmeden önce veri yakalayıcısıyla değiştirilir. Yalnızca
veri açıcı resmi Luau CLI'da çağrılır. Oyun/yükleyici bayt kodu yürütülmez,
sunucuya istek gönderilmez. Farklı kaynak parmak izleri reddedilir.

## Açılan katmanlar

1. **Dış giriş:** `shared._barrageLoaderFlight` ile 600 saniyelik eşzamanlı
   yükleme denetimi; `pcall`; `_barrageGameLoaded`, `_barrageReadyProtocol` ve
   `_barrageGameReady` alanlarıyla tamamlanma kontrolü.
2. **LPH paketi:** 191 alanlı, 154 fonksiyon tanımlı açıcı tablosu.
   `LPH%` metni 337.859 karakterdir. ASCII85 ve little endian `uint32`
   dönüşümünden 270.284 bayt çıkar.
3. **İlk prototip ağacı:** 53 fonksiyon, 10.526 talimat. İlk geçişin okuma
   konumu 69.161'dir. Unicode normalleştirme ve Roblox ortam sonuçlarını
   kullanan hesaplar, sonraki veri bloğunun açılmasına katılır.
4. **İkinci veri çerçevesi:** veri başlangıcı sıfır tabanlı **69.411**, uzunluk
   **200.871**. Önceki dört baytın `0x46636b55` ile XOR'u bu uzunluğu verir.
   Veri baytları sırayla `e3 36 18 5b 27 4b 6e 3d` ile XOR edilir. Frekans
   çözümlemesindeki 256 düşük bit adayı içinde yalnızca biri prototip ağacını
   tam ayrıştırır. Ayrıştırıcı **270.282** konumunda biter; kalan iki bayt
   ASCII85 doldurmasıdır.
5. **Ertelenmiş sabitler:** 2.627 sabit, değer/tür ve kullanılacak prototip
   alanlarının listesiyle tutulur. 2.233 sayının işareti çevrilir, iki boolean
   terslenir. 392 metin için bu dosyada eşdeğer dönüşüm şöyledir:
   başlık sıfırsa ikinci bayt tek karakterdir; diğerlerinde ikinci bayt tohum
   olur. Her gövde baytı için `s = (201*s + 179) % 256`,
   `açık_bayt = şifreli_bayt XOR s XOR 71` uygulanır. Sonuçlar, sabit kullanım
   kayıtlarının gösterdiği prototip alanlarına yerleştirilir.

İkinci ağacın ana prototipinden 129 fonksiyon/29.600 talimat izlenir. Ayrıca
serileştirilmiş listede üç tek talimatlı prototip vardır; bunlar da çıktıya
dahildir. Böylece toplam **132/29.603** elde edilir.

## Geri çıkarılan yükleme akışı

| Bölüm | Görülen adres/yapı | Talimat listesindeki fonksiyon |
| --- | --- | --- |
| Katalog | `https://barrage.cc/catalog` | `PROTO_54` |
| Oyun kimliklerini işleme | `Games`, `PlaceIds`, `UniverseIds` | `PROTO_74` |
| Arayüz | `https://barrage.cc/ui` | `PROTO_8`, `PROTO_120` |
| Ortak çalışma modülü | `https://barrage.cc/runtime` | `PROTO_71` |
| Kimlik doğrulama bileşeni | `https://barrage.cc/authentication` | `PROTO_69` |
| Oturum açma | `https://barrage.cc/session/create` | `PROTO_119` |
| Oturum yenileme | `https://barrage.cc/session/refresh` | `PROTO_78` |
| Oturum sahibi kontrolü | `https://barrage.cc/session/owner` | `PROTO_27` |
| Oyun kodunu alma | `https://barrage.cc` + `/script/` + seçilen kimlik | `PROTO_33` |

Metin ve talimatlarda istek başlıkları, SHA-256/bundle bilgileri, yerel
`BARRAGE/cache/index.json` ve `BARRAGE/catalog.json` yolları, arayüzün başlangıç
sözleşmesi, oturum yenileme ve yeniden giriş alanları da görülür. Bunlar yükleme
ve oturum altyapısıdır. Sunucu oturumu oluşturulmadı, anahtar gönderilmedi ve
korumalı oyun modülü indirilmedi. Farm remote yolları ve argümanları bu
çözümlemeden elde edilmedi.

Yer kimliğiyle oluşturulan `/script/132929771812494` adresine ayrıca oturumsuz
bir GET denemesi yapıldı. Son yanıt `200 text/html` idi; Lua oyun kaynağı
gelmedi. Bu deneme doğru `ScriptId` değerini veya sunucunun kabul edeceği
oturumu doğrulamaz. HTML içerik çalıştırılmadı ya da oyun modülü sayılmadı.

## Dış katalog ve Cameraman

Çözülmüş adresteki [açık katalog](https://barrage.cc/catalog), 2026-11-01'de
ayrı bir GET isteğiyle alındı; 471 oyun kaydı içerir. Bu indirme, çevrimdışı
çözücünün bir parçası değildir. Anlık görüntünün SHA-256 değeri ve sürümü
[catalog-meta.json](Barrage/catalog-meta.json) içindedir.

Cameraman Tower Defense kaydı:

- Evren: `10762636904`.
- Yerler: `132929771812494`, `114068177100380`.

Roblox'un [birinci yer](https://apis.roblox.com/universes/v1/places/132929771812494/universe)
ve [ikinci yer](https://apis.roblox.com/universes/v1/places/114068177100380/universe)
API'leri iki kimliği de bu evrene bağlar. İkinci yerin rolü bu incelemede
doğrulanmadı. Katalogdaki diğer oyunların canlı uyumluluğu ayrıca sınanmadı.

## Tekrar üretme

Temel ASCII85 çıkarma aracı `Tools/inspect-barrage-loader.cjs` yalnızca Node.js
ister. İki paket katmanı ve sabitleri açan araç
`Tools/decode-barrage-loader.cjs`, ayrıca resmi Luau CLI ve `luaparse` modülü
ister. İncelenen dosyanın parmak izine sabitlenmiştir.

```powershell
node Tools/decode-barrage-loader.cjs 'C:\path\cameraman auto farm.lua' 'C:\path\output' 'C:\path\luau.exe' 'C:\path\node_modules\luaparse'
```

Çözücü yalnızca yerel dosyalarla çalışır. Geçici veri açıcıya süre ve ayırma
sınırları uygulanır; geçici dosya işlem sonunda kaldırılır. Çıktılar manifest,
metinler, fonksiyon dizini, talimat listesi, VM işlemleri ve prototip grafiğidir.
Katalog dosyalarını indirmez ve GameRegistry'yi değiştirmez.
