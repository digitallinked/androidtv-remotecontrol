# Dasar privasi {{APP_NAME}}

Tarikh berkuat kuasa: {{EFFECTIVE_DATE}}

Dasar ini menerangkan apa yang dilakukan oleh apl {{APP_NAME}} ("apl ini") terhadap maklumat tentang anda. Apl ini diterbitkan oleh {{DEVELOPER_NAME}} ("kami"), {{DEVELOPER_ADDRESS}}. Kami bertanggungjawab ke atas maklumat yang dikendalikan oleh apl ini ("pengawal data" atau "pengguna data" di bawah undang-undang perlindungan data). Dasar ini terpakai kepada apl ini pada Android (pakej Google Play `{{PLAY_PACKAGE}}`) dan pada iPhone dan iPad (App Store), serta kepada laman web kami di {{SUPPORT_URL}}. Apabila dasar ini menyebut "iPhone", ia termasuk iPad juga.

An English version of this policy is available on our website. Versi bahasa Inggeris dasar ini boleh didapati di laman web kami. Jika kedua-dua versi berbeza, versi bahasa Inggeris terpakai, melainkan undang-undang di tempat anda tinggal menetapkan sebaliknya.

Ringkasannya:

- Apl ini tiada akaun dan tiada pelayan sendiri, jadi tiada apa-apa yang perlu anda log masuk.
- Semua maklumat tentang TV anda kekal pada telefon anda.
- Statistik penggunaan dan laporan ranap dihantar kepada Firebase hanya jika anda membenarkannya (atau, di tempat undang-undang tidak mewajibkan kebenaran terlebih dahulu, sehingga anda mematikannya).
- Apl percuma memaparkan iklan sepanduk daripada Google AdMob. Jika kami menghidupkannya, versi percuma juga mungkin sekali-sekala memaparkan iklan skrin penuh apabila anda keluar dari Tetapan. Premium tiada iklan.
- Kami tidak menjual maklumat anda untuk wang. Jika sesuatu undang-undang menganggap iklan diperibadikan sebagai "perkongsian" atau "penjualan", anda boleh memilih untuk menolaknya (seksyen 10).

## 1. Apa yang kekal pada telefon anda

Apl ini menyimpan perkara berikut pada telefon anda sahaja. Tiada satu pun daripadanya dihantar kepada kami, kepada Firebase, kepada AdMob, kepada RevenueCat atau kepada sesiapa pun; hanya TV anda sendiri yang terlibat dalam sambungan (seksyen 2), dan sijil penggandingan dihantar hanya kepada TV tersebut:

- nama TV anda dan nama samaran yang anda berikan kepadanya;
- alamat rangkaiannya (alamat IP dan nama hos tempatan) dan alamat MAC;
- sijil penggandingan yang dicipta oleh apl ini untuk telefon anda, dan pin kunci TV yang digunakannya untuk mengecam setiap TV semula;
- pintasan apl anda, dan kiraan apl TV yang anda gunakan (disimpan pada telefon untuk mencadangkan pintasan; kiraan itu sendiri tidak pernah meninggalkan telefon, tetapi lihat seksyen 3 untuk peristiwa yang dihantar apabila anda memulakan apl daripada senarai apl dalam apl ini);
- tetapan anda, termasuk Pilihan privasi anda;
- negara anda, yang dibaca oleh apl ini setiap kali ia dimulakan (daripada SIM atau rangkaian mudah alih pada Android, daripada tetapan Wilayah pada iPhone) untuk memilih apl TV yang hendak dicadangkan, dan tidak disimpan;
- apa-apa yang anda taip dengan ciri papan kekunci, yang terus dihantar ke TV;
- log ralat yang ringkas (Tetapan → Bantuan → Log ralat) dengan nama dan alamat TV dibuang, yang meninggalkan telefon anda hanya jika anda menyalinnya sendiri.

**Sandaran dan berpindah ke telefon baharu.** Pada Android, apl ini mematikan sandaran Android dan pemindahan peranti untuk semua datanya, jadi tiada satu pun perkara di atas dimasukkan ke dalam sandaran Google atau ke telefon baharu. Pada iPhone, pangkalan data yang menyimpan TV anda dikecualikan daripada sandaran iCloud dan komputer, dan sijil penggandingan disimpan dalam rantai kunci (keychain) iPhone sebagai item untuk peranti ini sahaja, jadi kedua-duanya tidak berpindah ke iPhone lain. Selepas anda berpindah ke telefon baharu, anda perlu menggandingkan TV anda semula. Pada iPhone, keutamaan ringkas apl ini (seperti tema, susun atur dan Pilihan privasi anda, yang tidak mengandungi apa-apa tentang TV anda) disimpan seperti keutamaan apl lain dan mungkin dimasukkan ke dalam sandaran iPhone anda sendiri.

Apabila anda memadamkan apl ini, data ini turut dipadamkan. Pada iPhone, iOS mungkin menyimpan sijil penggandingan apl ini dalam rantai kunci selepas anda memadamkan apl; apl ini menggantikannya dengan sijil baharu apabila anda memasangnya semula. Anda juga boleh membuang TV dalam apl ini pada bila-bila masa.

## 2. Cara apl ini berhubung dengan TV anda

Apl ini berhubung dengan TV anda secara terus melalui rangkaian setempat anda, tanpa melalui internet atau mana-mana pelayan kami:

- ia mencari TV menggunakan penemuan rangkaian setempat (mDNS / Bonjour);
- ia bersambung ke perkhidmatan alat kawalan jauh TV melalui sambungan yang disulitkan (TLS) pada port 6466 dan 6467;
- pada Android, ia boleh menghantar paket Wake-on-LAN pada rangkaian setempat anda untuk menghidupkan TV, menggunakan alamat MAC yang disimpan pada telefon anda.

**Kebenaran.** Pada Android, apl ini menggunakan kebenaran rangkaian (akses internet, keadaan rangkaian dan Wi-Fi, dan multisiar untuk penemuan) dan kebenaran ID pengiklanan yang digunakan oleh AdMob. Pada iPhone, iOS meminta anda membenarkan akses rangkaian setempat sebelum apl ini boleh mencari TV, dan bertanya tentang penjejakan seperti yang diterangkan dalam seksyen 3. Apl ini tidak meminta lokasi, kenalan, kamera, mikrofon, foto atau fail anda.

## 3. Perkhidmatan yang kami gunakan, dan apa yang diterimanya

Apl ini menggunakan perkhidmatan di bawah. Setiap satu hanya menerima apa yang diterangkan di sini. Maklumat yang dihantar kepadanya disulitkan melalui HTTPS. Seperti mana-mana perkhidmatan internet, setiap satu juga melihat alamat IP telefon anda apabila apl ini menghubunginya, dan mungkin menganggarkan lokasi anggaran (seperti bandar, wilayah atau negara) daripadanya.

### Firebase Analytics (statistik penggunaan, oleh Google)

Jika statistik penggunaan dihidupkan, apl ini menghantar kepada Firebase Analytics senarai tetap peristiwa tentang cara apl ini digunakan:

- skrin yang anda buka (mengikut nama skrin sahaja);
- bahawa proses permulaan telah selesai, dan berapa banyak TV ditemui apabila penemuan menemui TV pertamanya;
- bila penggandingan bermula, berjaya atau gagal, dan jenis kegagalan (contohnya, kod yang salah);
- bila sambungan ke TV berjaya atau terputus, dan jenis sebabnya;
- nama butang alat kawalan jauh yang anda tekan (seperti "home" atau "volume up"), bagi kira-kira satu daripada sepuluh tekanan;
- apl yang anda mulakan daripada senarai apl dalam apl ini, mengikut nama pakejnya apabila apl itu ada dalam katalog terbina dalam apl ini, atau hanya sebagai "custom" apabila ia pintasan yang anda tambah sendiri;
- bila anda menukar susun atur alat kawalan jauh;
- bila anda membuka halaman Premium, dari mana, dan versi halaman Premium yang dipaparkan (kami mungkin menguji versi yang berbeza); bila pembelian atau pemulihan membuka Premium, dan produk yang dibeli;
- bila apl ini meminta anda memberikan ulasan di gedung aplikasi.

Firebase Analytics juga merekodkan peristiwa standardnya sendiri, seperti kali pertama apl ini dibuka, sesi apl, kemas kini apl dan pembelian dalam apl, bersama ID tika apl (pengecam rawak untuk pemasangan apl ini), maklumat asas peranti dan apl (seperti model telefon, versi sistem, versi apl dan bahasa), dan lokasi anggaran yang dianggarkan oleh Google daripada alamat IP anda.

Ia tidak pernah menerima nama TV anda, alamat rangkaian atau alamat MAC, kod penggandingan, apa-apa yang anda taip, nama apl yang anda tambah sendiri, atau laluan skrin tentang TV tertentu. Apl ini dibina supaya Firebase Analytics tidak mengumpul ID pengiklanan, dan isyarat persetujuan berkaitan iklan Google untuk Analytics sentiasa ditetapkan kepada "ditolak" ("denied").

**Kawalan anda.** Dalam apl ini, buka Tetapan → **Pilihan privasi** → **Kongsi statistik penggunaan**. Mematikannya menghentikan pengumpulan. Sehingga anda membuat pilihan, apl ini memutuskan seperti berikut: di tempat undang-undang mewajibkan kebenaran terlebih dahulu (contohnya Kawasan Ekonomi Eropah, United Kingdom dan Switzerland, seperti yang dilaporkan oleh User Messaging Platform Google), statistik penggunaan kekal dimatikan; di tempat lain ia dihidupkan sehingga anda mematikannya. Semasa apl ini belum dapat menentukan yang mana terpakai, peristiwa menunggu pada telefon dan dipadamkan jika jawapannya "dimatikan".

Data analitis disimpan selama {{ANALYTICS_RETENTION}}, kemudian dipadamkan oleh Google.

### Firebase Crashlytics (laporan ranap, oleh Google)

Jika laporan ranap dihidupkan, apl ini menghantar laporan kepada Firebase Crashlytics apabila ia ranap atau mengalami ralat serius. Laporan mengandungi ralat dan lokasi kod tempat ia berlaku, maklumat peranti dan apl (seperti model telefon, versi sistem, versi apl dan memori kosong), dan pengecam pemasangan ranap. Apabila statistik penggunaan juga dihidupkan, Crashlytics mungkin melampirkan peristiwa analitis terkini apl ini (peristiwa yang disenaraikan di atas) pada laporan, untuk menunjukkan apa yang berlaku sebelum ranap.

Sebelum laporan meninggalkan telefon, apl ini membuang nama TV yang diketahuinya, alamat rangkaian, alamat MAC, kod penggandingan, alamat e-mel, sijil, teks pangkalan data dan nilai yang serupa. Jika apl ini belum mengetahui nama TV yang anda simpan, ia menahan laporan itu dan tidak menghantarnya tanpa dibersihkan. Binaan nyahpepijat (debug) apl ini tidak pernah menghantar laporan ranap.

**Kawalan anda.** Tetapan → **Pilihan privasi** → **Kongsi laporan ranap**. Tetapan lalainya berfungsi sama seperti statistik penggunaan. Apabila anda mematikannya, laporan yang menunggu pada telefon dipadamkan.

Laporan ranap disimpan sehingga 90 hari, di bawah tempoh penyimpanan standard Crashlytics Google.

### Firebase Remote Config dan Firebase Installations (oleh Google)

Apl ini meminta tetapannya daripada Firebase Remote Config setiap kali ia dimulakan, tanpa mengira Pilihan privasi anda. Tetapan ini membolehkan kami menghidupkan atau mematikan ciri dari jauh (contohnya, iklan sepanduk dan iklan skrin penuh sekali-sekala yang diterangkan di bawah) dan memberitahu anda apabila versi apl anda terlalu lama untuk berfungsi. Permintaan itu dikenal pasti melalui ID Pemasangan Firebase, iaitu pengecam rawak untuk pemasangan apl ini, dan mengandungi maklumat asas apl dan peranti yang digunakan oleh Firebase untuk memilih tetapan yang betul, seperti id dan versi apl, platform dan versi sistem, serta tetapan bahasa, negara dan zon waktu telefon anda. Remote Config tidak menerima apa-apa tentang TV anda.

### Google AdMob (iklan) dan User Messaging Platform

Versi percuma apl ini memaparkan iklan sepanduk di bahagian bawah skrin Apl dan Tetapan. Iklan skrin penuh dimatikan secara lalai; jika kami menghidupkannya melalui Remote Config, versi percuma juga mungkin sekali-sekala memaparkan iklan skrin penuh apabila anda keluar dari Tetapan, tetapi tidak sekali-kali semasa anda menggandingkan TV atau sejurus selepas masalah sambungan. Premium tidak memaparkan iklan, dan apl ini tidak memuatkan iklan untuk pengguna Premium. Iklan dihadkan kepada kandungan yang sesuai untuk khalayak umum.

Untuk memaparkan dan mengukur iklan serta mencegah penipuan, Google AdMob menerima pengecam pengiklanan peranti anda (pada Android, ID pengiklanan; pada iPhone, pengecam pengiklanan hanya jika anda membenarkan penjejakan, lihat di bawah), alamat IP anda (yang digunakan oleh Google untuk menganggarkan lokasi anggaran), dan maklumat peranti dan apl, dan ia mungkin mengumpul maklumat diagnostik dan ranap tentang kod iklannya sendiri. Pada iPhone, kod iklan Google juga mungkin menggunakan pengecam untuk vendor (pengecam rawak yang diberikan oleh iOS kepada semua apl daripada pembangun yang sama pada peranti anda) tanpa mengira jawapan anda tentang penjejakan. Di wilayah yang mewajibkan persetujuan, iklan diperibadikan hanya jika anda bersetuju melalui borang persetujuan; jika tidak, anda melihat iklan yang tidak diperibadikan atau iklan terhad. Di tempat lain, iklan mungkin diperibadikan secara lalai; anda boleh mengehadkannya melalui tetapan iklan telefon anda, melalui Tetapan → **Pilihan privasi** → **Pilihan privasi iklan** jika ia dipaparkan, dan, pada iPhone, dengan tidak membenarkan penjejakan. Pada Android, kod iklan Google juga mungkin menggunakan Android Privacy Sandbox (seperti Topics dan pengukuran iklan), yang anda kawal dalam tetapan telefon anda; pada iPhone, SKAdNetwork Apple mungkin melaporkan, tanpa mengenal pasti anda, bahawa sesuatu iklan membawa kepada pemasangan apl. Google menggunakan maklumat ini seperti yang diterangkan dalam dasar privasinya sendiri, di https://policies.google.com/privacy, dan menerangkan cara ia menggunakan maklumat daripada apl yang menggunakan perkhidmatannya di https://policies.google.com/technologies/partner-sites.

**User Messaging Platform** Google menentukan sama ada wilayah anda memerlukan borang persetujuan atau mesej privasi (contohnya Kawasan Ekonomi Eropah, United Kingdom dan Switzerland, dan negeri-negeri Amerika Syarikat yang mempunyai undang-undang privasi; senarai tepatnya bergantung pada mesej yang kami terbitkan dalam AdMob). Jika ya, apl ini memaparkan borang Google sebelum sebarang iklan dimuatkan, dan menyimpan jawapan anda pada telefon anda. Anda boleh menukar jawapan anda pada bila-bila masa dalam Tetapan → **Pilihan privasi** → **Pilihan privasi iklan** (dipaparkan di mana-mana tempat mesej sedemikian terpakai, juga dengan Premium).

### App Tracking Transparency (iPhone)

Pada iPhone, apl ini menerangkan sebab ia bertanya, kemudian memaparkan soalan **App Tracking Transparency** Apple sebelum ia memaparkan iklan buat kali pertama. Kod iklan tidak dimulakan sehingga anda telah menjawab. Jika anda tidak membenarkan penjejakan, AdMob tidak menerima pengecam pengiklanan dan anda masih melihat iklan, yang kemudiannya kurang disesuaikan. Jawapan itu dipaparkan dalam Tetapan → **Pilihan privasi** → **Penjejakan iklan**, dan anda boleh menukarnya dalam Seting iPhone.

### RevenueCat (pembelian Premium)

Premium dijual melalui Google Play dan App Store, dan apl ini menggunakan RevenueCat untuk mengesahkan pembelian anda. RevenueCat menerima ID pengguna apl tanpa nama (pengecam rawak, bukan nama atau alamat e-mel anda), rekod pembelian gedung anda untuk apl ini (seperti produk, tarikh pembelian dan ID transaksi), dan maklumat asas peranti dan apl. Pembayaran dikendalikan oleh Google Play atau App Store; kami dan RevenueCat tidak pernah melihat butiran kad anda. RevenueCat menyimpan rekod pembelian selagi kami menggunakan perkhidmatannya, supaya Premium boleh dipulihkan, dan mengendalikannya di bawah dasar privasinya di https://www.revenuecat.com/privacy.

### Google Play dan App Store

Apabila anda memuat turun apl ini, membeli Premium atau memberikan ulasan, Google Play atau App Store memprosesnya di bawah dasar privasi mereka sendiri. Apl ini boleh meminta gedung memaparkan gesaan ulasannya; gedung yang memutuskan sama ada gesaan itu muncul, dan kami tidak mengetahui sama ada ia dipaparkan kepada anda atau apa yang anda tulis melainkan anda menyiarkan ulasan awam. Gedung juga memberi kami statistik tentang pemasangan, pembelian dan ranap yang tidak mengenal pasti anda.

### Laman web kami

Laman web kami disampaikan melalui Cloudflare, yang memproses alamat IP pelawat dan data teknikal permintaan untuk menyampaikan halaman dan melindunginya daripada serangan. Laman web ini tidak menetapkan sebarang kuki pengiklanan atau analitis.

## 4. E-mel maklum balas

Jika anda memilih untuk menghantar maklum balas, apl ini membuka apl e-mel anda sendiri dengan mesej kepada {{SUPPORT_EMAIL}}. Mesej itu mengandungi versi apl ini dan versi sistem telefon anda, dan tiada apa-apa tentang TV anda. Jika anda menghantarnya, kami menerima alamat e-mel anda, nama anda jika apl e-mel anda menambahkannya, dan apa sahaja yang anda tulis. Anda boleh membaca dan mengubahnya sebelum menghantarnya. Kami menggunakan apa yang anda hantar hanya untuk menjawab anda dan menambah baik apl ini. Kami memadamkan e-mel maklum balas dalam tempoh 24 bulan selepas jawapan terakhir kami, melainkan kami perlu menyimpannya lebih lama untuk menangani tuntutan undang-undang.

## 5. Apa yang kami tidak lakukan

- Kami tiada akaun, jadi tiada apa-apa yang perlu anda daftar dan tiada akaun untuk dipadamkan.
- Kami tidak menjual maklumat peribadi anda untuk wang.
- Kami sendiri tidak menggunakan maklumat anda untuk membina profil tentang anda, dan kami tidak membuat keputusan tentang anda secara automatik yang mempunyai kesan undang-undang atau kesan ketara yang serupa.
- Kami tidak mengumpul maklumat sensitif, seperti maklumat kesihatan, kewangan, agama atau biometrik.

## 6. Berapa lama maklumat disimpan

| Maklumat | Di mana | Berapa lama |
|---|---|---|
| TV anda, sijil penggandingan, pintasan, tetapan | Telefon anda | Sehingga anda membuang TV atau memadamkan apl |
| Statistik penggunaan | Firebase Analytics | {{ANALYTICS_RETENTION}} |
| Laporan ranap | Firebase Crashlytics | Sehingga 90 hari |
| Remote Config dan pengecam pemasangan | Firebase | Selagi apl dipasang; Google memadamkan data pemasangan yang tidak aktif mengikut jadualnya sendiri |
| Data iklan | Google AdMob | Di bawah dasar penyimpanan Google sendiri |
| Rekod pembelian | RevenueCat, Google Play, App Store | Selagi diperlukan untuk menyediakan Premium dan mematuhi undang-undang cukai dan perakaunan |
| E-mel maklum balas | Peti mel kami | Sehingga 24 bulan selepas jawapan terakhir kami |

## 7. Keselamatan

Sambungan ke TV anda disulitkan dengan TLS dan dilindungi oleh kod penggandingan yang dipaparkan oleh TV anda. Maklumat yang dihantar kepada perkhidmatan dalam seksyen 3 dihantar melalui HTTPS. Pada telefon anda, sijil penggandingan disimpan dalam storan selamat sistem (disulitkan dengan kunci yang dipegang oleh Android Keystore, atau rantai kunci iPhone). Laporan ranap dibersihkan sebelum meninggalkan telefon (seksyen 3). Tiada kaedah penyimpanan atau penghantaran yang selamat sepenuhnya, tetapi kami dan perkhidmatan yang kami gunakan mengambil langkah yang munasabah untuk melindungi maklumat. Jika berlaku pelanggaran data yang menjejaskan anda, kami akan memaklumkan anda dan pihak berkuasa seperti yang dikehendaki oleh undang-undang.

## 8. Kanak-kanak

Apl ini ditujukan untuk orang dewasa; di gedung aplikasi, khalayak sasarannya ialah 18 tahun ke atas. Apl ini tidak ditujukan kepada kanak-kanak di bawah umur 13 tahun, dan kami tidak dengan sengaja mengumpul maklumat peribadi daripada kanak-kanak. Jika anda percaya seorang kanak-kanak telah menggunakan apl ini dan menghantar maklumat kepada kami, hubungi kami dan kami akan memadamkan apa yang kami boleh.

## 9. Di mana maklumat diproses

Kami berpangkalan di Malaysia. Google (Firebase dan AdMob), RevenueCat dan Cloudflare mungkin memproses maklumat di negara selain negara anda, termasuk Amerika Syarikat. Jika dikehendaki oleh undang-undang, mereka melindungi pemindahan dengan perlindungan yang diiktiraf seperti klausa kontrak standard Suruhanjaya Eropah atau Rangka Kerja Privasi Data EU–AS, seperti yang diterangkan dalam terma mereka sendiri. Pemindahan data peribadi ke luar Malaysia dibuat di bawah syarat yang dibenarkan oleh Akta Perlindungan Data Peribadi 2010.

## 10. Undang-undang privasi di tempat anda tinggal

### Malaysia (Akta Perlindungan Data Peribadi 2010)

Seksyen ini ialah notis kami di bawah seksyen 7 Akta tersebut.

- **Apa yang kami proses dan mengapa:** maklumat dalam seksyen 3 dan 4, untuk menyediakan apl ini dan Premium, memastikan ia terus berfungsi, membaiki ranap, memaparkan iklan yang membiayai versi percuma, dan menjawab anda.
- **Dari mana ia diperoleh:** daripada anda dan daripada apl ini pada telefon anda, dan daripada gedung aplikasi apabila anda membeli Premium.
- **Siapa yang menerimanya:** pembekal perkhidmatan dalam seksyen 3 (Google, RevenueCat, Google Play dan App Store, Cloudflare), dan pihak berkuasa apabila dikehendaki oleh undang-undang.
- **Adakah ia wajib?** Statistik penggunaan dan laporan ranap adalah pilihan, dan anda boleh mematikannya pada bila-bila masa. Iklan disertakan dengan versi percuma; Premium membuangnya. Maklumat pembelian diperlukan untuk menyediakan Premium. Maklum balas terpulang kepada anda. Apl ini berfungsi sepenuhnya tanpa apa-apa yang bersifat pilihan.
- **Hak anda:** anda boleh meminta akses kepada dan pembetulan data peribadi anda, menarik balik persetujuan, meminta kami menghentikan pemprosesan yang mungkin menyebabkan kerosakan atau distres, dan menghentikan pemasaran langsung (kami tidak menghantar sebarang pemasaran langsung). Hantar permintaan kepada {{SUPPORT_EMAIL}}. Kami menjawab dalam tempoh 21 hari, seperti yang dikehendaki oleh Akta tersebut.

### Kawasan Ekonomi Eropah, United Kingdom dan Switzerland (GDPR)

Asas undang-undang yang kami gunakan:

- **Statistik penggunaan, laporan ranap, iklan diperibadikan, dan menyimpan atau membaca maklumat pada peranti anda untuk iklan:** persetujuan anda. Anda boleh menarik baliknya pada bila-bila masa dalam Tetapan → **Pilihan privasi**, tanpa menjejaskan apa yang telah berlaku sebelumnya.
- **Iklan yang tidak diperibadikan atau iklan terhad:** kepentingan sah kami dalam membiayai versi percuma apl ini, bersama persetujuan anda jika dikehendaki oleh undang-undang untuk storan peranti.
- **Remote Config:** kepentingan sah kami dalam memastikan apl ini terus berfungsi dan selamat (menghidupkan atau mematikan ciri, dan memberitahu anda apabila kemas kini diperlukan).
- **Pembelian Premium:** untuk menyediakan apa yang anda beli (pelaksanaan kontrak) dan untuk memenuhi kewajipan undang-undang kami, seperti rekod cukai.
- **E-mel maklum balas:** kepentingan sah kami dalam menjawab anda.

Anda berhak untuk mengakses, membetulkan, memadamkan atau menerima salinan mudah alih data peribadi anda, untuk menyekat atau membantah penggunaannya (termasuk penggunaan berdasarkan kepentingan sah), dan untuk menarik balik persetujuan. Anda juga boleh membuat aduan kepada pihak berkuasa perlindungan data di tempat anda tinggal atau bekerja.

### Amerika Syarikat (undang-undang privasi negeri)

Sesetengah undang-undang negeri di Amerika Syarikat, seperti undang-undang California, memberi anda hak ke atas maklumat peribadi: untuk mengetahui apa yang dikumpul, untuk mengakses, membetulkan atau memadamkannya, dan untuk menolak "penjualan"nya, "perkongsian"nya untuk pengiklanan tingkah laku rentas konteks, atau pengiklanan bersasar. Kami tidak menjual maklumat peribadi untuk wang. Memaparkan iklan diperibadikan melalui AdMob mungkin dikira sebagai "perkongsian" atau pengiklanan bersasar di bawah undang-undang tersebut. Untuk menolak, gunakan Tetapan → **Pilihan privasi** → **Pilihan privasi iklan** jika ia dipaparkan, matikan pemperibadian iklan dalam tetapan telefon anda (Android: Tetapan → Google → Iklan, atau Tetapan → Privasi → Iklan; iPhone: jangan benarkan penjejakan), atau beli Premium. Kategori yang terlibat ialah pengecam (pengecam pengiklanan dan pengecam apl), aktiviti internet dan apl (peristiwa dalam seksyen 3), lokasi anggaran dan maklumat pembelian, yang digunakan untuk tujuan dalam seksyen 3. Kami tidak mengumpul maklumat peribadi sensitif, dan kami tidak akan melayan anda secara berbeza kerana menggunakan hak anda.

## 11. Pilihan dan hak anda

- Hidupkan atau matikan statistik penggunaan dan laporan ranap dalam Tetapan → **Pilihan privasi**.
- Tukar persetujuan iklan anda dalam Tetapan → **Pilihan privasi** → **Pilihan privasi iklan**, dan penjejakan iklan dalam Seting iPhone.
- Beli Premium untuk membuang iklan.
- Padamkan apl ini untuk memadamkan apa yang disimpannya pada telefon anda; pemasangan baharu mendapat pengecam rawak baharu untuk analitis dan laporan ranap. Pada iPhone, iOS mungkin menyimpan sijil penggandingan apl ini dalam rantai kunci selepas anda memadamkan apl; apl ini menggantikannya dengan sijil baharu apabila anda memasangnya semula.

**Cara membuat permintaan.** Tulis kepada {{SUPPORT_EMAIL}} dan nyatakan apa yang anda mahu. Oleh sebab apl ini tiada akaun, kami tidak dapat mencari anda mengikut nama atau alamat e-mel: perkhidmatan dalam seksyen 3 hanya menyimpan pengecam rawak, yang tidak dipaparkan oleh apl ini. Mematikan perkongsian dalam Tetapan → **Pilihan privasi** dan memadamkan apl ini menghentikan pengumpulan selanjutnya; Google kemudiannya memadamkan data mengikut tempoh penyimpanan dalam seksyen 6. Untuk permintaan tentang pembelian anda, sertakan nombor pesanan gedung. Untuk e-mel maklum balas, tulis daripada alamat yang sama. Kami mungkin meminta maklumat untuk mengesahkan bahawa permintaan itu milik anda, dan kami menjawab dalam tempoh yang ditetapkan oleh undang-undang di tempat anda tinggal.

## 12. Perubahan pada dasar ini

Jika kami mengubah dasar ini, kami akan menerbitkan versi baharu di {{PRIVACY_POLICY_URL}} dengan tarikh berkuat kuasa yang baharu. Jika sesuatu perubahan itu ketara, kami juga akan memaklumkannya dalam apl ini atau di halaman gedungnya.

## 13. Hubungi kami

{{DEVELOPER_NAME}}
{{DEVELOPER_ADDRESS}}
E-mel: {{SUPPORT_EMAIL}}
Laman web: {{SUPPORT_URL}}
