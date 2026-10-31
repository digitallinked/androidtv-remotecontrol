// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get statusConnected => 'Disambungkan';

  @override
  String get statusConnecting => 'Menyambung…';

  @override
  String get statusReconnecting => 'Menyambung semula…';

  @override
  String get statusOffline => 'Luar talian';

  @override
  String get statusNeedsPairing => 'Perlu digandingkan';

  @override
  String get statusDisconnected => 'Tidak disambungkan';

  @override
  String get statusReconnectAction => 'Sambung semula';

  @override
  String statusSemantics(String status) {
    return 'Sambungan: $status';
  }

  @override
  String get closeAction => 'Tutup';

  @override
  String get onboardingGetStarted => 'Mulakan';

  @override
  String get onboardingTryDemo => 'Cuba demo';

  @override
  String get onboardingSkip => 'Langkau';

  @override
  String get onboardingNext => 'Seterusnya';

  @override
  String onboardingProgress(int current, int total) {
    return 'Kad $current daripada $total';
  }

  @override
  String get onboardingConnectTitle => 'Cari TV anda';

  @override
  String get onboardingConnectBody =>
      'Telefon anda mencari Android TV anda pada rangkaian Wi-Fi yang sama. Gandingkan sekali sahaja dengan kod yang dipaparkan pada TV anda.';

  @override
  String get onboardingConnectNote =>
      'Apl ini hanya mencari pada rangkaian Wi-Fi anda. Apl ini tidak pernah meminta lokasi anda.';

  @override
  String get onboardingControlTitle => 'Kawal TV menggunakan telefon anda';

  @override
  String get onboardingControlBody =>
      'Leret pad sentuh atau gunakan D-pad, ubah kelantangan dan taip dengan papan kekunci telefon anda.';

  @override
  String get onboardingAppsTitle => 'Buka apl dengan satu ketikan';

  @override
  String get onboardingAppsBody =>
      'Simpan apl TV kegemaran anda dalam satu baris pada alat kawalan jauh dan bukanya tanpa perlu mencari.';

  @override
  String get onboardingLocalNetworkTitle => 'Benarkan akses rangkaian setempat';

  @override
  String get onboardingLocalNetworkBody =>
      'Seterusnya, iPhone anda akan meminta kebenaran supaya apl ini dapat mencari peranti pada rangkaian setempat anda. Pilih Benarkan supaya apl ini dapat mencari TV anda. Anda boleh mengubahnya kemudian dalam Seting → Privasi & Keselamatan → Rangkaian Setempat.';

  @override
  String get onboardingContinue => 'Teruskan';

  @override
  String get demoBadgeLabel => 'Mod demo';

  @override
  String get demoLeaveAction => 'Keluar';

  @override
  String get demoLeaveTitle => 'Keluar daripada demo?';

  @override
  String get demoLeaveMessage => 'Anda akan kembali ke senarai TV.';

  @override
  String get demoLeaveConfirm => 'Keluar demo';

  @override
  String get demoStay => 'Terus di sini';

  @override
  String get tvPreviewTitle => 'Pratonton TV';

  @override
  String get tvPreviewIdle => 'Tekan butang untuk melihat tindakan TV.';

  @override
  String tvPreviewPressed(String key) {
    return 'Ditekan: $key';
  }

  @override
  String tvPreviewHolding(String key) {
    return 'Ditahan: $key';
  }

  @override
  String tvPreviewReleased(String key) {
    return 'Dilepaskan: $key';
  }

  @override
  String tvPreviewOpened(String link) {
    return 'Dibuka: $link';
  }

  @override
  String tvPreviewTyped(String text) {
    return 'Ditaip: \"$text\"';
  }

  @override
  String get tvPreviewScreenOn => 'Skrin hidup';

  @override
  String get tvPreviewScreenOff => 'Skrin mati';

  @override
  String tvPreviewVolume(int level, int max) {
    return 'Kelantangan $level daripada $max';
  }

  @override
  String get tvPreviewMuted => 'Disenyapkan';

  @override
  String get discoverTitle => 'Pilih TV anda';

  @override
  String get discoverEmptyTitle => 'Belum ada TV ditemui';

  @override
  String get discoverEmptyBody =>
      'Pastikan telefon dan TV anda berada pada rangkaian Wi-Fi yang sama dan TV dihidupkan.';

  @override
  String get discoverSearching => 'Mencari TV pada Wi-Fi ini…';

  @override
  String get discoverScanAgain => 'Imbas semula';

  @override
  String get discoverEnterIp => 'Masukkan alamat IP';

  @override
  String get discoverTryDemo => 'Cuba demo';

  @override
  String get discoverTroubleshooting => 'Penyelesaian masalah';

  @override
  String get discoverPaired => 'Digandingkan';

  @override
  String get discoverUpdateNeeded => 'Perlu dikemas kini';

  @override
  String get discoverErrorTitle => 'Tidak dapat mencari TV';

  @override
  String get discoverErrorBody =>
      'Pastikan Wi-Fi dihidupkan, kemudian imbas semula.';

  @override
  String get troubleshootTitle => 'Tidak dapat menemui TV anda?';

  @override
  String get troubleshootSameWifi =>
      'Sambungkan telefon dan TV anda ke rangkaian Wi-Fi yang sama (bukan rangkaian tetamu).';

  @override
  String get troubleshootTvOn =>
      'Hidupkan TV. Sesetengah TV tidak dapat ditemui semasa dalam mod tunggu sedia.';

  @override
  String get troubleshootRemoteService =>
      'Pada TV, pastikan \"Android TV Remote Service\" dipasang dan versinya terkini di Play Store.';

  @override
  String get troubleshootLocalNetwork =>
      'Pada iPhone, benarkan akses Rangkaian Setempat untuk apl ini dalam Seting → Privasi & Keselamatan → Rangkaian Setempat.';

  @override
  String get troubleshootRestart =>
      'Masih tidak berjaya? Mulakan semula TV dan penghala anda, kemudian imbas semula.';

  @override
  String get troubleshootManualIp =>
      'Anda juga boleh memasukkan alamat IP TV. Cari alamat itu pada TV di bawah Tetapan → Rangkaian & Internet.';

  @override
  String get legacyTitle => 'TV ini perlu dikemas kini';

  @override
  String legacyBody(String tvName) {
    return '$tvName menggunakan perkhidmatan alat kawalan jauh versi lama. Pada TV, buka Play Store, cari \"Android TV Remote Service\" dan kemas kinikannya, kemudian imbas semula.';
  }

  @override
  String get manualIpTitle => 'Masukkan alamat IP';

  @override
  String get manualIpLabel => 'Alamat IP TV';

  @override
  String get manualIpHint => '192.168.1.20';

  @override
  String get manualIpHelp =>
      'Cari alamat itu pada TV di bawah Tetapan → Rangkaian & Internet → rangkaian anda.';

  @override
  String get manualIpError => 'Masukkan alamat seperti 192.168.1.20';

  @override
  String get manualIpContinue => 'Teruskan';

  @override
  String get pageTitlePair => 'Gandingkan TV anda';

  @override
  String get pageTitleRemote => 'Alat kawalan jauh';

  @override
  String get pageTitleApps => 'Apl';

  @override
  String get pageTitleDevices => 'TV anda';

  @override
  String get pageTitleSettings => 'Tetapan';

  @override
  String get pageTitlePaywall => 'Premium';

  @override
  String get placeholderBody => 'Skrin ini akan tersedia tidak lama lagi.';

  @override
  String get routeNotFoundTitle => 'Halaman tidak ditemui';

  @override
  String get routeNotFoundBody => 'Kami tidak dapat menemui halaman itu.';

  @override
  String get routeNotFoundAction => 'Kembali ke senarai TV';

  @override
  String get statusPairAgainAction => 'Gandingkan semula';

  @override
  String get remoteNotConnected => 'Tidak disambungkan ke TV anda';

  @override
  String get remoteSwitchTv => 'Tukar TV';

  @override
  String get remoteAddTv => 'Tambah TV';

  @override
  String get remoteNoTvTitle => 'Tiada TV dipilih';

  @override
  String get remoteNoTvAction => 'Pilih TV';

  @override
  String get remoteIdentityChangedTitle => 'Identiti TV ini telah berubah';

  @override
  String remoteIdentityChangedMessage(String tvName) {
    return '$tvName memberikan kunci keselamatan yang berbeza daripada kunci semasa anda menggandingkannya. Jika TV itu telah ditetapkan semula atau diganti, gandingkannya semula.';
  }

  @override
  String get remoteNotNow => 'Bukan sekarang';

  @override
  String get remoteSessionErrorTitle =>
      'Tidak dapat menyediakan sambungan selamat';

  @override
  String get remoteSessionErrorBody =>
      'Berlaku masalah semasa memuatkan kunci keselamatan telefon ini.';

  @override
  String get remoteRetry => 'Cuba lagi';

  @override
  String get demoTvName => 'TV Demo';

  @override
  String get volumeLabel => 'VOL';

  @override
  String keyNumber(int digit) {
    return 'Nombor $digit';
  }

  @override
  String keyUnknown(int code) {
    return 'Kekunci $code';
  }

  @override
  String get keyUp => 'Atas';

  @override
  String get keyDown => 'Bawah';

  @override
  String get keyLeft => 'Kiri';

  @override
  String get keyRight => 'Kanan';

  @override
  String get keyOk => 'OK';

  @override
  String get keyBack => 'Kembali';

  @override
  String get keyHome => 'Laman utama';

  @override
  String get keyMenu => 'Menu';

  @override
  String get keyPower => 'Kuasa';

  @override
  String get keyVolumeUp => 'Kuatkan kelantangan';

  @override
  String get keyVolumeDown => 'Perlahankan kelantangan';

  @override
  String get keyMute => 'Senyap';

  @override
  String get keyChannelUp => 'Saluran naik';

  @override
  String get keyChannelDown => 'Saluran turun';

  @override
  String get keyPlayPause => 'Main atau jeda';

  @override
  String get keyNext => 'Seterusnya';

  @override
  String get keyPrevious => 'Sebelumnya';

  @override
  String get keyRewind => 'Undur';

  @override
  String get keyFastForward => 'Mara laju';

  @override
  String get keyStop => 'Henti';

  @override
  String get keyRed => 'Merah';

  @override
  String get keyGreen => 'Hijau';

  @override
  String get keyYellow => 'Kuning';

  @override
  String get keyBlue => 'Biru';

  @override
  String get keyTvInput => 'Input TV';

  @override
  String get keySettings => 'Tetapan';

  @override
  String get keyGuide => 'Panduan rancangan';

  @override
  String get keyInfo => 'Maklumat';

  @override
  String get keyCaptions => 'Kapsyen';

  @override
  String get keySearch => 'Cari';

  @override
  String get keyEnter => 'Enter';

  @override
  String get keyDelete => 'Padam';

  @override
  String get keyKeyboard => 'Papan kekunci';

  @override
  String pairStarting(String tvName) {
    return 'Menyambung ke $tvName…';
  }

  @override
  String pairEnterCode(String tvName) {
    return 'Masukkan kod yang dipaparkan pada $tvName';
  }

  @override
  String get pairCodeLabel => 'Kod penggandingan';

  @override
  String pairExpiresIn(int seconds) {
    return 'Kod tamat tempoh dalam $seconds s';
  }

  @override
  String get pairPaste => 'Tampal kod';

  @override
  String get pairNothingToPaste => 'Tiada kod 6 aksara pada papan keratan.';

  @override
  String get pairCodeMismatch =>
      'Kod itu tidak sepadan. Semak kod pada TV anda dan masukkannya semula.';

  @override
  String get pairVerifying => 'Menyemak kod…';

  @override
  String get pairExpiredTitle => 'Kod telah tamat tempoh';

  @override
  String get pairExpiredBody =>
      'Minta kod baharu daripada TV dan masukkannya dalam masa 60 saat.';

  @override
  String get pairNewCode => 'Dapatkan kod baharu';

  @override
  String get pairTryAgain => 'Cuba lagi';

  @override
  String get pairTroubleshooting => 'Penyelesaian masalah';

  @override
  String pairCantReachTitle(String tvName) {
    return 'Tidak dapat menghubungi $tvName';
  }

  @override
  String get pairCantReachBody =>
      'Pastikan TV dihidupkan dan berada pada rangkaian Wi-Fi yang sama dengan telefon anda.';

  @override
  String pairNoResponseTitle(String tvName) {
    return '$tvName tidak bertindak balas';
  }

  @override
  String get pairRejectedTitle => 'TV tidak menerima kod itu';

  @override
  String get pairRejectedBody =>
      'Dapatkan kod baharu dan masukkannya tepat seperti yang dipaparkan.';

  @override
  String get pairErrorTitle => 'Penggandingan tidak berjaya';

  @override
  String get pairErrorBody => 'Sesuatu yang tidak dijangka berlaku. Cuba lagi.';

  @override
  String get pairIdentityTitle => 'Tidak dapat menyediakan sambungan selamat';

  @override
  String get pairSaveFailedTitle => 'Tidak dapat menyimpan TV ini';

  @override
  String get pairNotFoundTitle => 'Kami tidak dapat menemui TV ini';

  @override
  String get pairNotFoundBody =>
      'Kembali ke senarai TV dan pilih TV itu semula.';

  @override
  String get remotePadTabsLabel => 'Gaya kawalan';

  @override
  String get remotePadTouchpad => 'Pad sentuh';

  @override
  String get remotePadDpad => 'D-pad';

  @override
  String get remotePadNumbers => 'Nombor';

  @override
  String get touchpadLabel => 'Pad sentuh';

  @override
  String get touchpadHint =>
      'Leret untuk bergerak, ketik untuk memilih, ketik dengan dua jari untuk kembali.';

  @override
  String get touchpadIdleHint => 'Leret untuk bergerak · Ketik untuk memilih';

  @override
  String get channelLabel => 'CH';

  @override
  String remoteVolumeValue(int level) {
    return '$level';
  }

  @override
  String get remoteMutedValue => 'Senyap';

  @override
  String remoteVolumeSemantics(int level, int max) {
    return 'Kelantangan $level daripada $max';
  }

  @override
  String get remoteVolumeMutedSemantics => 'Kelantangan disenyapkan';

  @override
  String get quickAccessAppsLabel => 'Apl pada TV anda';

  @override
  String get quickAccessColourLabel => 'Kekunci warna';

  @override
  String get quickAccessMediaLabel => 'Kekunci media';

  @override
  String quickAppOpen(String app) {
    return 'Buka $app';
  }

  @override
  String quickAppNowOnTv(String app) {
    return '$app, kini dibuka pada TV';
  }

  @override
  String get powerHoldHint => 'Tahan untuk menghidupkan atau mematikan TV';

  @override
  String powerWaking(String tvName) {
    return 'Menghidupkan $tvName…';
  }

  @override
  String get powerWakeFailed =>
      'Tidak dapat menghantar isyarat untuk menghidupkan TV. Pastikan telefon anda berada pada Wi-Fi yang sama dengan TV.';

  @override
  String get powerTurnOnWithTvRemote =>
      'Hidupkan TV dengan alat kawalan jauh TV itu sendiri. Apl ini akan menyambung semula dengan sendirinya.';

  @override
  String wolSetupTitle(String tvName) {
    return 'Hidupkan $tvName melalui telefon anda';
  }

  @override
  String get wolSetupBody =>
      'Telefon anda boleh menghidupkan TV melalui rangkaian dengan alamat MAC TV itu. Pada TV, buka Tetapan → Sistem → Perihal → Status (atau Tetapan → Rangkaian & Internet) dan salin alamat MAC Wi-Fi atau Ethernet.';

  @override
  String get wolNotBluetooth =>
      'Gunakan alamat MAC Wi-Fi atau Ethernet, bukan alamat Bluetooth.';

  @override
  String get wolMayNotWork =>
      'Sesetengah TV tidak dapat dihidupkan apabila dimatikan sepenuhnya atau berada dalam mod tunggu sedia mendalam.';

  @override
  String get wolMacLabel => 'Alamat MAC';

  @override
  String get wolMacHint => 'AA:BB:CC:DD:EE:FF';

  @override
  String get wolMacError =>
      'Masukkan 6 pasang huruf atau digit, seperti AA:BB:CC:DD:EE:FF';

  @override
  String get wolSaveAndWake => 'Simpan dan hidupkan';

  @override
  String get wolSaveFailed => 'Tidak dapat menyimpan alamat MAC. Cuba lagi.';

  @override
  String get keyboardTitle => 'Taip pada TV anda';

  @override
  String get keyboardFieldLabel => 'Teks';

  @override
  String get keyboardHint => 'Mula menaip…';

  @override
  String get keyboardTvHint =>
      'Pilih medan teks pada TV dahulu, seperti kotak carian.';

  @override
  String get keyboardClear => 'Kosongkan';

  @override
  String get keyboardOpenTvSearch => 'Buka carian pada TV';

  @override
  String get keyboardNotConnected =>
      'Tidak disambungkan ke TV anda. Apa yang anda taip tidak dihantar.';

  @override
  String get theaterWakeLabel =>
      'Skrin dimalapkan. Sentuh untuk menerangkan skrin.';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonSave => 'Simpan';

  @override
  String get commonUndo => 'Buat asal';

  @override
  String get commonRetry => 'Cuba lagi';

  @override
  String get remoteManageTvs => 'Urus TV';

  @override
  String get quickAccessAllApps => 'Semua apl';

  @override
  String get pageTitleManageApps => 'Sunting apl';

  @override
  String get pageTitleEditDevice => 'Sunting TV';

  @override
  String get pageTitleAppearance => 'Penampilan';

  @override
  String get pageTitleRemoteLayout => 'Susun atur alat kawalan jauh';

  @override
  String get pageTitleRemoteBehaviour => 'Tingkah laku alat kawalan jauh';

  @override
  String get pageTitleHelp => 'Bantuan';

  @override
  String get pageTitleAbout => 'Perihal apl ini';

  @override
  String get appsSearchLabel => 'Cari apl';

  @override
  String get appsYourApps => 'Apl anda';

  @override
  String get appsMoreApps => 'Apl lain';

  @override
  String appsNoMatches(String query) {
    return 'Tiada apl yang sepadan dengan \"$query\".';
  }

  @override
  String get appsEmptyTitle => 'Belum ada apl';

  @override
  String get appsLoadFailed => 'Tidak dapat memuatkan apl anda.';

  @override
  String get appsEmptyBody =>
      'Tambah apl yang anda gunakan pada TV supaya anda boleh membukanya dengan satu ketikan.';

  @override
  String get appsEmptyAction => 'Tambah apl';

  @override
  String get manageAppsAdd => 'Tambah apl';

  @override
  String get manageAppsReset => 'Tetapkan semula kepada apl cadangan';

  @override
  String get manageAppsResetTitle => 'Tetapkan semula apl anda?';

  @override
  String get manageAppsResetBody =>
      'Senarai anda akan kembali kepada apl cadangan untuk rantau anda. Pintasan yang anda tambah atau ubah akan dialih keluar.';

  @override
  String get manageAppsResetConfirm => 'Tetapkan semula';

  @override
  String get manageAppsReorderHint =>
      'Seret pemegang untuk mengubah susunan. Alat kawalan jauh memaparkan apl anda mengikut susunan ini.';

  @override
  String manageAppsDragHandle(String app) {
    return 'Susun semula $app';
  }

  @override
  String manageAppsEdit(String app) {
    return 'Sunting $app';
  }

  @override
  String manageAppsRemove(String app) {
    return 'Alih keluar $app';
  }

  @override
  String manageAppsRemoved(String app) {
    return '$app dialih keluar';
  }

  @override
  String get manageAppsEmpty =>
      'Tiada apl dalam senarai anda. Tambah satu apl untuk melihatnya pada alat kawalan jauh.';

  @override
  String get manageAppsSaveFailed =>
      'Tidak dapat menyimpan apl anda. Cuba lagi.';

  @override
  String get addAppTitle => 'Tambah apl';

  @override
  String get addAppSearchLabel => 'Cari apl atau masukkan ID apl';

  @override
  String get addAppCustom => 'Cipta pintasan tersuai';

  @override
  String get addAppRecentTitle => 'Digunakan baru-baru ini pada TV anda';

  @override
  String get addAppRecentEmpty =>
      'Apl yang anda buka pada TV akan dipaparkan di sini.';

  @override
  String get addAppPopularTitle => 'Apl cadangan';

  @override
  String get addAppNoResults =>
      'Tiada apl ditemui. Jika anda tahu ID apl itu, taipkannya untuk menambahnya.';

  @override
  String addAppById(String package) {
    return 'Tambah ID apl \"$package\"';
  }

  @override
  String addAppAdded(String app) {
    return '$app ditambah';
  }

  @override
  String get addAppAlreadyAdded => 'Sudah ada dalam senarai anda';

  @override
  String get shortcutNewTitle => 'Pintasan baharu';

  @override
  String get shortcutEditTitle => 'Sunting pintasan';

  @override
  String get shortcutNameLabel => 'Nama';

  @override
  String get shortcutNameError => 'Masukkan nama hingga 30 aksara.';

  @override
  String get shortcutPackageLabel => 'ID apl';

  @override
  String get shortcutPackageHint => 'com.example.app';

  @override
  String get shortcutPackageHelp =>
      'ID apl itu pada TV. ID ini ada dalam alamat web apl itu di Play Store, selepas \"id=\".';

  @override
  String get shortcutPackageError => 'Masukkan ID apl seperti com.example.app.';

  @override
  String get shortcutPackageTaken => 'Apl ini sudah ada dalam senarai anda.';

  @override
  String get shortcutColourLabel => 'Warna jubin';

  @override
  String get shortcutColourDefault => 'Lalai';

  @override
  String get shortcutColourSlate => 'Kelabu batu';

  @override
  String get shortcutColourBlue => 'Biru';

  @override
  String get shortcutColourTeal => 'Hijau kebiruan';

  @override
  String get shortcutColourGreen => 'Hijau';

  @override
  String get shortcutColourAmber => 'Ambar';

  @override
  String get shortcutColourOrange => 'Oren';

  @override
  String get shortcutColourRed => 'Merah';

  @override
  String get shortcutColourPurple => 'Ungu';

  @override
  String get shortcutIconLabel => 'Ikon';

  @override
  String get shortcutIconLetter => 'Huruf pertama';

  @override
  String get shortcutIconApp => 'Apl';

  @override
  String get shortcutIconMovies => 'Filem';

  @override
  String get shortcutIconLive => 'TV langsung';

  @override
  String get shortcutIconSports => 'Sukan';

  @override
  String get shortcutIconMusic => 'Muzik';

  @override
  String get shortcutIconKids => 'Kanak-kanak';

  @override
  String get shortcutIconNews => 'Berita';

  @override
  String get shortcutIconGames => 'Permainan';

  @override
  String get shortcutIconLearning => 'Pembelajaran';

  @override
  String get shortcutPreview => 'Pratonton';

  @override
  String get shortcutSaved => 'Pintasan disimpan';

  @override
  String get devicesEmptyTitle => 'Belum ada TV';

  @override
  String get devicesLoadFailed => 'Tidak dapat memuatkan TV anda.';

  @override
  String get devicesEmptyBody =>
      'Gandingkan TV untuk mengawalnya menggunakan telefon ini.';

  @override
  String get devicesInUse => 'Sedang digunakan';

  @override
  String devicesEditTv(String tvName) {
    return 'Sunting $tvName';
  }

  @override
  String get editDeviceNameLabel => 'Nama pada telefon ini';

  @override
  String editDeviceNameHelp(String tvName) {
    return 'Biarkan kosong untuk menggunakan nama TV itu sendiri, $tvName.';
  }

  @override
  String get editDeviceNameError => 'Gunakan 40 aksara atau kurang.';

  @override
  String get editDeviceWolTitle => 'Hidupkan melalui telefon anda';

  @override
  String get editDeviceWolBody =>
      'Tambah alamat MAC TV supaya kekunci kuasa dapat menghidupkannya daripada mod tunggu sedia.';

  @override
  String get editDeviceWolHelp => 'Di mana saya boleh mencarinya?';

  @override
  String get editDeviceWolUnavailable =>
      'Menghidupkan TV melalui iPhone belum tersedia lagi. Anda masih boleh menyimpan alamat ini.';

  @override
  String get wolMacTooLong =>
      'Itu lebih panjang daripada alamat MAC. Semak apa yang anda tampal.';

  @override
  String get wolHelpTitle => 'Cari alamat MAC TV';

  @override
  String editDeviceLastAddress(String host) {
    return 'Alamat terakhir: $host';
  }

  @override
  String get editDeviceSaved => 'Disimpan';

  @override
  String get editDeviceSaveFailed => 'Tidak dapat menyimpan. Cuba lagi.';

  @override
  String get editDeviceRemove => 'Alih keluar TV';

  @override
  String get editDeviceRemoveFailed =>
      'Tidak dapat mengalih keluar TV ini. Cuba lagi.';

  @override
  String editDeviceRemoveTitle(String tvName) {
    return 'Alih keluar $tvName?';
  }

  @override
  String get editDeviceRemoveBody =>
      'Telefon ini akan melupakan TV ini dan tetapannya. Untuk menggunakannya semula, gandingkannya dengan kod baharu. TV itu mungkin masih menyenaraikan telefon ini.';

  @override
  String get editDeviceRemoveConfirm => 'Alih keluar';

  @override
  String editDeviceRemoved(String tvName) {
    return '$tvName dialih keluar';
  }

  @override
  String get editDeviceNotFound =>
      'TV ini tidak lagi disimpan pada telefon ini.';

  @override
  String get editDeviceBackToTvs => 'Kembali ke TV anda';

  @override
  String get discoverOpenFailed => 'Tidak dapat membuka TV ini. Cuba lagi.';

  @override
  String get settingsSectionRemote => 'Alat kawalan jauh';

  @override
  String get settingsSectionApp => 'Apl';

  @override
  String get settingsSectionSupport => 'Bantuan dan maklum balas';

  @override
  String get settingsSectionAbout => 'Perihal';

  @override
  String get settingsRemoteLayoutSubtitle =>
      'Pad sentuh atau D-pad, dan baris kekunci di atasnya';

  @override
  String get settingsRemoteBehaviourSubtitle =>
      'Getaran, Smooth Press, skrin dan papan kekunci';

  @override
  String get settingsAppsSubtitle => 'Pilih dan susun pintasan apl anda';

  @override
  String get settingsDevicesSubtitle =>
      'Namakan semula, alih keluar atau hidupkan melalui telefon anda';

  @override
  String get settingsAppearanceSubtitle => 'Tema dan bahasa';

  @override
  String get settingsHelpSubtitle => 'Soalan lazim dan penyelesaian masalah';

  @override
  String get settingsFeedback => 'Hantar maklum balas';

  @override
  String get settingsFeedbackSubtitle => 'Tulis kepada kami melalui e-mel';

  @override
  String get settingsAboutSubtitle => 'Versi dan lesen';

  @override
  String get settingsPrivacy => 'Dasar privasi';

  @override
  String get settingsTerms => 'Terma penggunaan';

  @override
  String get settingsOpensInBrowser => 'Dibuka dalam pelayar anda';

  @override
  String get settingsLinkFailed =>
      'Tidak dapat membuka halaman itu. Semak sambungan internet anda dan cuba lagi.';

  @override
  String get appearanceTheme => 'Tema';

  @override
  String get appearanceThemeSystem => 'Sama seperti telefon';

  @override
  String get appearanceThemeLight => 'Cerah';

  @override
  String get appearanceThemeDark => 'Gelap';

  @override
  String get appearanceDynamicColour => 'Warna daripada kertas dinding';

  @override
  String get appearanceDynamicColourSubtitle =>
      'Gunakan warna kertas dinding telefon anda dalam apl ini.';

  @override
  String get appearanceLanguage => 'Bahasa';

  @override
  String get appearanceLanguageSystem => 'Sama seperti telefon';

  @override
  String get layoutPreviewTitle => 'Pratonton';

  @override
  String get layoutPreviewSemantics =>
      'Pratonton alat kawalan jauh dengan pilihan ini';

  @override
  String get layoutNavigation => 'Navigasi';

  @override
  String get layoutTouchpadSubtitle =>
      'Leret untuk bergerak, ketik untuk memilih.';

  @override
  String get layoutDpadSubtitle =>
      'Kekunci anak panah di sekeliling butang OK, seperti alat kawalan jauh TV.';

  @override
  String get layoutQuickAccess => 'Baris di atas pad';

  @override
  String get layoutQuickApps => 'Pintasan apl';

  @override
  String get layoutQuickAppsSubtitle => 'Buka apl TV anda dengan satu ketikan.';

  @override
  String get layoutQuickColourSubtitle =>
      'Kekunci merah, hijau, kuning dan biru.';

  @override
  String get layoutQuickMediaSubtitle =>
      'Sebelumnya, undur, main atau jeda, mara laju dan seterusnya.';

  @override
  String get layoutQuickNone => 'Tiada';

  @override
  String get layoutQuickNoneSubtitle =>
      'Lebih banyak ruang untuk pad sentuh atau D-pad.';

  @override
  String get behaviourHaptics => 'Bergetar apabila kekunci ditekan';

  @override
  String get behaviourHapticsSubtitle =>
      'Getaran pendek apabila kekunci sampai ke TV.';

  @override
  String get behaviourSmoothPress => 'Smooth Press';

  @override
  String get behaviourSmoothPressSubtitle =>
      'Menahan kekunci kelantangan, saluran atau anak panah sama seperti menahan kekunci pada alat kawalan jauh TV. Apabila dimatikan, kekunci yang ditahan akan berulang.';

  @override
  String get behaviourKeepAwake => 'Biarkan skrin hidup';

  @override
  String get behaviourKeepAwakeSubtitle =>
      'Skrin telefon anda kekal hidup semasa alat kawalan jauh dibuka.';

  @override
  String get behaviourTheater => 'Mod teater';

  @override
  String get behaviourTheaterSubtitle =>
      'Memalapkan skrin telefon anda selepas 30 saat tanpa sentuhan. Sentuhan pertama hanya mencerahkan skrin semula.';

  @override
  String get behaviourAutoKeyboard => 'Buka papan kekunci secara automatik';

  @override
  String get behaviourAutoKeyboardSubtitle =>
      'Membuka papan kekunci apabila TV meminta teks, seperti dalam kotak carian.';

  @override
  String get helpCantConnectTitle => 'Tidak dapat menyambung?';

  @override
  String get helpCantConnectBody =>
      'Lakukan semakan satu demi satu. Kebanyakan masalah berpunca daripada rangkaian Wi-Fi atau perkhidmatan alat kawalan jauh TV.';

  @override
  String get helpTroubleshootingAction =>
      'Tunjukkan langkah penyelesaian masalah';

  @override
  String get helpFaqTitle => 'Soalan lazim';

  @override
  String get helpStillStuck => 'Masih belum selesai?';

  @override
  String get faqTvsQ => 'TV manakah yang berfungsi dengan apl ini?';

  @override
  String get faqTvsA =>
      'TV dan kotak penstriman yang menjalankan Android TV atau Google TV, pada rangkaian Wi-Fi yang sama dengan telefon anda. TV dengan sistem lain, seperti Samsung (Tizen), LG (webOS), Roku atau Fire TV, tidak dapat dikawal oleh apl ini.';

  @override
  String get faqNotFoundQ => 'TV saya tiada dalam senarai.';

  @override
  String get faqNotFoundA =>
      'Pastikan TV dihidupkan dan disambungkan ke Wi-Fi yang sama dengan telefon anda, dan \"Android TV Remote Service\" pada TV ialah versi terkini. Anda juga boleh menambah TV itu melalui alamat IP-nya. Langkah penyelesaian masalah membawa anda melalui setiap semakan.';

  @override
  String get faqCodeQ => 'Mengapakah TV meminta kod sekali lagi?';

  @override
  String get faqCodeA =>
      'Penggandingan membuatkan TV dan telefon ini saling mempercayai. Mengosongkan data apl, memasang semula apl atau menetapkan semula TV akan membuang kepercayaan itu, jadi anda perlu menggandingkannya sekali lagi dengan kod baharu.';

  @override
  String get faqPowerQ =>
      'Mengapakah apl ini tidak dapat menghidupkan TV saya?';

  @override
  String get faqPowerA =>
      'TV yang dimatikan sepenuhnya tidak dapat menerima isyarat daripada apl ini. Apl ini boleh menghantar isyarat untuk menghidupkan TV jika anda menambah alamat MAC TV di bawah Tetapan → TV anda, tetapi sesetengah TV mengabaikannya dalam mod tunggu sedia mendalam. Pada iPhone, ciri ini belum tersedia lagi.';

  @override
  String get faqTypingQ => 'Apa yang saya taip tidak muncul pada TV.';

  @override
  String get faqTypingA =>
      'Pilih medan teks pada TV dahulu, seperti kotak carian. Apabila TV meminta teks, papan kekunci akan terbuka pada telefon anda dengan sendirinya.';

  @override
  String get faqAppQ => 'Pintasan apl tidak dapat dibuka.';

  @override
  String get faqAppA =>
      'Apl itu mesti dipasang pada TV. Sesetengah apl mempunyai versi berbeza bagi setiap negara: tambah versi yang betul melalui ID aplnya di bawah Tetapan → Apl.';

  @override
  String get faqPrivacyQ =>
      'Apakah yang disimpan oleh apl ini tentang TV saya?';

  @override
  String get faqPrivacyA =>
      'Nama, alamat rangkaian dan alamat MAC TV anda kekal pada telefon ini. Apl ini boleh menghantar statistik penggunaan dan laporan ranap tanpa nama, yang tidak pernah mengandungi maklumat itu. Anda boleh menghidupkan atau mematikan setiap satu dalam Tetapan → Pilihan privasi.';

  @override
  String get faqNewPhoneQ =>
      'Saya bertukar ke telefon baharu. Di manakah TV saya?';

  @override
  String get faqNewPhoneA =>
      'TV anda dan penggandingannya kekal pada telefon yang anda gunakan untuk menggandingkannya. Semua itu tidak disalin dalam sandaran atau apabila anda bertukar ke telefon baharu, jadi gandingkan setiap TV sekali lagi pada telefon baharu itu.';

  @override
  String aboutVersion(String version, String build) {
    return 'Versi $version ($build)';
  }

  @override
  String get aboutVersionUnknown => 'Versi tidak tersedia';

  @override
  String get aboutLicences => 'Lesen sumber terbuka';

  @override
  String get aboutProtocol =>
      'Berhubung dengan TV anda melalui Wi-Fi menggunakan protokol Android TV Remote. Format mesejnya diambil daripada projek sumber terbuka androidtvremote2.';

  @override
  String get aboutTrademark =>
      'Android TV dan Google TV ialah tanda dagangan Google LLC. Apl ini tidak dibuat atau diendors oleh Google.';

  @override
  String get feedbackTitle => 'Hantar maklum balas?';

  @override
  String get feedbackBody =>
      'Apl e-mel anda akan dibuka dengan mesej kepada kami. Mesej itu mengandungi versi apl dan versi sistem telefon anda, dan tiada apa-apa tentang TV anda.';

  @override
  String get feedbackConfirm => 'Tulis e-mel';

  @override
  String feedbackSubject(String appName, String version) {
    return 'Maklum balas tentang $appName $version';
  }

  @override
  String get feedbackPrompt => 'Tulis mesej anda di sini.';

  @override
  String feedbackNoEmailApp(String email) {
    return 'Tiada apl e-mel ditemui. Tulis kepada kami di $email.';
  }

  @override
  String get settingsPremiumSubtitle =>
      'Bebas iklan, dengan gaya warna tambahan';

  @override
  String get settingsPremiumActiveSubtitle =>
      'Anda mempunyai Premium. Terima kasih!';

  @override
  String get pageTitlePrivacyChoices => 'Pilihan privasi';

  @override
  String get settingsPrivacyChoicesSubtitle =>
      'Statistik penggunaan, laporan ranap dan iklan';

  @override
  String get aboutTestCrash => 'Hantar laporan ranap ujian';

  @override
  String get aboutTestCrashSent =>
      'Laporan ranap ujian dihantar. Laporan itu akan muncul dalam Crashlytics dalam beberapa minit.';

  @override
  String get privacyIntro =>
      'Pilih perkara yang boleh dikongsi oleh apl ini. Nama, alamat rangkaian dan alamat MAC TV anda tidak pernah keluar dari telefon ini.';

  @override
  String get privacySectionImprove => 'Bantu menambah baik apl ini';

  @override
  String get privacyUsageTitle => 'Kongsi statistik penggunaan';

  @override
  String get privacyUsageSubtitle =>
      'Kiraan tanpa nama bagi skrin dan ciri yang anda gunakan. Tidak pernah termasuk apa yang anda taip atau apa-apa tentang TV anda.';

  @override
  String get privacyCrashTitle => 'Kongsi laporan ranap';

  @override
  String get privacyCrashSubtitle =>
      'Dihantar apabila berlaku masalah supaya masalah itu dapat dibaiki. Nama, alamat dan kod dibuang terlebih dahulu.';

  @override
  String get privacyServicesOff =>
      'Binaan apl ini tidak menghantar statistik penggunaan atau laporan ranap.';

  @override
  String get privacySectionAds => 'Iklan';

  @override
  String get privacyAdsInfo =>
      'Versi percuma apl ini memaparkan iklan sepanduk di bahagian bawah skrin Apl dan Tetapan sahaja.';

  @override
  String get privacyAdsPremium =>
      'Anda mempunyai Premium, jadi apl ini tidak memaparkan iklan.';

  @override
  String get privacyAdChoices => 'Pilihan privasi iklan';

  @override
  String get privacyAdChoicesSubtitle => 'Pilih cara iklan dipilih untuk anda.';

  @override
  String get privacyAdChoicesFailed =>
      'Tidak dapat membuka pilihan privasi iklan. Semak sambungan internet anda dan cuba lagi.';

  @override
  String get privacyRemoveAds => 'Buang iklan dengan Premium';

  @override
  String get privacyTrackingTitle => 'Penjejakan iklan';

  @override
  String get privacyTrackingAllowed =>
      'Dibenarkan. Anda boleh mengubahnya dalam Seting iPhone anda.';

  @override
  String get privacyTrackingDenied =>
      'Tidak dibenarkan. Anda boleh mengubahnya dalam Seting iPhone anda.';

  @override
  String get privacyTrackingNotDetermined =>
      'Belum dipilih. Apl ini akan bertanya sebelum memaparkan iklan buat kali pertama.';

  @override
  String get privacyTrackingRestricted => 'Dimatikan pada iPhone ini.';

  @override
  String get privacyOpensSettings => 'Membuka Seting telefon anda';

  @override
  String get trackingPrepromptTitle => 'Tentang iklan dalam apl ini';

  @override
  String get trackingPrepromptBody =>
      'Versi percuma apl ini memaparkan iklan kecil di bahagian bawah skrin ini. Seterusnya, iPhone anda akan bertanya sama ada apl ini boleh menggunakan aktiviti anda dalam apl lain untuk memilih iklan. Bilangan iklan yang anda lihat tetap sama walau apa pun pilihan anda, dan alat kawalan jauh berfungsi seperti biasa.';

  @override
  String get trackingPrepromptContinue => 'Teruskan';

  @override
  String get adLabel => 'Iklan';

  @override
  String get paywallHeadline => 'Jadikan alat kawalan jauh milik anda';

  @override
  String get paywallSubhead =>
      'Premium membuang iklan, menambah gaya warna dan menyokong pembangunan apl ini.';

  @override
  String get paywallBenefitNoAds => 'Tanpa iklan';

  @override
  String get paywallBenefitNoAdsBody =>
      'Tiada sepanduk pada skrin Apl dan Tetapan.';

  @override
  String get paywallBenefitStyles => 'Gaya warna';

  @override
  String get paywallBenefitStylesBody =>
      'Ocean, Ember dan Midnight, dalam mod cerah dan gelap.';

  @override
  String get paywallFreeForever =>
      'Semua yang lain kekal percuma: setiap TV, semua kawalan alat kawalan jauh, pintasan apl, papan kekunci dan menghidupkan TV anda.';

  @override
  String get paywallChoosePlan => 'Pilih pelan';

  @override
  String get paywallPlanMonthly => 'Bulanan';

  @override
  String get paywallPlanYearly => 'Tahunan';

  @override
  String get paywallPlanLifetime => 'Seumur hidup';

  @override
  String paywallPricePerMonth(String price) {
    return '$price sebulan';
  }

  @override
  String paywallPricePerYear(String price) {
    return '$price setahun';
  }

  @override
  String paywallPriceOnce(String price) {
    return '$price, sekali bayar';
  }

  @override
  String get paywallRenewsMonthly =>
      'Diperbaharui setiap bulan sehingga anda membatalkannya.';

  @override
  String get paywallRenewsYearly =>
      'Diperbaharui setiap tahun sehingga anda membatalkannya.';

  @override
  String get paywallLifetimeTerms => 'Bayar sekali. Tiada langganan.';

  @override
  String get paywallBestValue => 'Nilai terbaik';

  @override
  String paywallSavePercent(int percent) {
    return 'Jimat $percent%';
  }

  @override
  String get paywallContinue => 'Teruskan';

  @override
  String get paywallRestore => 'Pulihkan pembelian';

  @override
  String get paywallTermsAndroid =>
      'Bayaran dikenakan pada akaun Google Play anda. Langganan diperbaharui secara automatik sehingga anda membatalkannya dalam Google Play, dan anda kekal mendapat Premium sehingga akhir tempoh yang telah anda bayar.';

  @override
  String get paywallTermsIos =>
      'Bayaran dikenakan pada Apple ID anda. Langganan diperbaharui secara automatik melainkan anda membatalkannya sekurang-kurangnya 24 jam sebelum tempoh semasa tamat. Urus atau batalkan langganan dalam seting Apple ID anda.';

  @override
  String get paywallLoading => 'Memuatkan pelan…';

  @override
  String get paywallUnavailableTitle => 'Premium tidak tersedia buat masa ini';

  @override
  String get paywallUnavailableBody =>
      'Semak sambungan internet anda dan cuba lagi.';

  @override
  String get paywallPurchasing => 'Mengesahkan pembelian anda…';

  @override
  String get paywallRestoring => 'Memulihkan pembelian anda…';

  @override
  String get paywallWelcome => 'Selamat datang ke Premium. Terima kasih!';

  @override
  String get paywallPending =>
      'Pembelian anda sedang menunggu kelulusan. Premium akan bermula sebaik sahaja pembelian itu selesai.';

  @override
  String get paywallFailed => 'Pembelian tidak berjaya. Cuba lagi.';

  @override
  String get paywallNetworkError =>
      'Tidak dapat menghubungi gedung apl. Semak sambungan internet anda dan cuba lagi.';

  @override
  String get paywallNotAllowed =>
      'Pembelian tidak dibenarkan pada telefon ini.';

  @override
  String get paywallAlreadyOwned =>
      'Anda sudah memiliki Premium. Ketik Pulihkan pembelian untuk mendapatkannya semula.';

  @override
  String get paywallRestored => 'Pembelian dipulihkan. Anda mempunyai Premium.';

  @override
  String get paywallNothingToRestore =>
      'Tiada pembelian ditemui untuk akaun ini.';

  @override
  String get paywallRestoreFailed =>
      'Tidak dapat memulihkan pembelian. Cuba lagi.';

  @override
  String get paywallActiveTitle => 'Anda mempunyai Premium';

  @override
  String get paywallActiveBody =>
      'Terima kasih kerana menyokong apl ini. Tiada iklan, dan setiap gaya warna milik anda.';

  @override
  String get paywallActiveLifetime =>
      'Premium seumur hidup: tidak akan tamat tempoh.';

  @override
  String get paywallManageSubscription => 'Urus langganan';

  @override
  String get appearanceStyle => 'Gaya warna';

  @override
  String get appearanceStyleStandard => 'Lalai';

  @override
  String get appearanceStyleOcean => 'Ocean';

  @override
  String get appearanceStyleEmber => 'Ember';

  @override
  String get appearanceStyleMidnight => 'Midnight';

  @override
  String get appearanceStyleLocked => 'Termasuk dalam Premium';

  @override
  String get appearanceStyleWallpaperOn =>
      'Warna daripada kertas dinding dihidupkan, jadi gaya warna tidak dipaparkan.';

  @override
  String get updateRequiredTitle => 'Kemas kini diperlukan';

  @override
  String get updateRequiredBody =>
      'Versi apl ini terlalu lama untuk terus berfungsi dengan baik. Kemas kini kepada versi terkini untuk meneruskan.';

  @override
  String get updateRequiredAction => 'Kemas kini';

  @override
  String get updateRequiredFailed =>
      'Tidak dapat membuka gedung apl. Kemas kini apl ini daripada gedung apl telefon anda.';

  @override
  String get loadingLabel => 'Memuatkan…';

  @override
  String get manageAppsMoreOptions => 'Lagi pilihan';

  @override
  String manageAppsMoved(String app, int position, int count) {
    return '$app dialihkan ke kedudukan $position daripada $count';
  }
}
