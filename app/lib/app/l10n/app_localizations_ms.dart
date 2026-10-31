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
  String get onboardingControlTitle => 'Kawal TV dari telefon anda';

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
      'Seterusnya, iPhone anda akan meminta kebenaran supaya apl ini dapat mencari peranti pada rangkaian setempat anda. Pilih Benarkan supaya apl ini dapat mencari TV anda. Anda boleh mengubahnya kemudian dalam Tetapan → Privasi & Keselamatan → Rangkaian Setempat.';

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
  String get demoStay => 'Kekal';

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
  String get troubleshootTitle => 'Tidak menemui TV anda?';

  @override
  String get troubleshootSameWifi =>
      'Sambungkan telefon dan TV anda ke rangkaian Wi-Fi yang sama (bukan rangkaian tetamu).';

  @override
  String get troubleshootTvOn =>
      'Hidupkan TV. Sesetengah TV tidak dapat ditemui semasa dalam mod tunggu sedia.';

  @override
  String get troubleshootRemoteService =>
      'Pada TV, pastikan \"Android TV Remote Service\" dipasang dan dikemas kini di Play Store.';

  @override
  String get troubleshootLocalNetwork =>
      'Pada iPhone, benarkan akses Rangkaian Setempat untuk apl ini dalam Tetapan → Privasi & Keselamatan → Rangkaian Setempat.';

  @override
  String get troubleshootRestart =>
      'Masih tiada? Mulakan semula TV dan penghala anda, kemudian imbas semula.';

  @override
  String get troubleshootManualIp =>
      'Anda juga boleh memasukkan alamat IP TV. Cari alamat itu pada TV di bawah Tetapan → Rangkaian & Internet.';

  @override
  String get legacyTitle => 'TV ini perlu dikemas kini';

  @override
  String legacyBody(String tvName) {
    return '$tvName menggunakan perkhidmatan alat kawalan jauh versi lama. Pada TV, buka Play Store, cari \"Android TV Remote Service\", kemas kininya, kemudian imbas semula.';
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
    return '$tvName memberikan kunci keselamatan yang berbeza daripada semasa anda menggandingkannya. Jika TV itu telah ditetapkan semula atau diganti, gandingkannya semula.';
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
  String get keyRewind => 'Mundur';

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
  String get keyGuide => 'Panduan';

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
    return '$tvName tidak memberikan respons';
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
    return '$app, kini pada TV';
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
    return 'Hidupkan $tvName dari telefon anda';
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
  String get pageTitleManageApps => 'Edit apl';

  @override
  String get pageTitleEditDevice => 'Edit TV';

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
    return 'Edit $app';
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
  String get addAppRecentTitle => 'Recently used on your TV';

  @override
  String get addAppRecentEmpty => 'Apps you open on your TV show up here.';

  @override
  String get addAppPopularTitle => 'Suggested apps';

  @override
  String get addAppNoResults =>
      'No apps found. If you know the app\'s ID, type it to add it.';

  @override
  String addAppById(String package) {
    return 'Add app ID \"$package\"';
  }

  @override
  String addAppAdded(String app) {
    return '$app added';
  }

  @override
  String get addAppAlreadyAdded => 'Already on your list';

  @override
  String get shortcutNewTitle => 'New shortcut';

  @override
  String get shortcutEditTitle => 'Edit shortcut';

  @override
  String get shortcutNameLabel => 'Name';

  @override
  String get shortcutNameError => 'Enter a name of up to 30 characters.';

  @override
  String get shortcutPackageLabel => 'App ID';

  @override
  String get shortcutPackageHint => 'com.example.app';

  @override
  String get shortcutPackageHelp =>
      'The app\'s ID on the TV. It\'s in the app\'s Play Store web address, after \"id=\".';

  @override
  String get shortcutPackageError => 'Enter an app ID like com.example.app.';

  @override
  String get shortcutPackageTaken => 'This app is already on your list.';

  @override
  String get shortcutColourLabel => 'Tile colour';

  @override
  String get shortcutColourDefault => 'Default';

  @override
  String get shortcutColourSlate => 'Slate';

  @override
  String get shortcutColourBlue => 'Blue';

  @override
  String get shortcutColourTeal => 'Teal';

  @override
  String get shortcutColourGreen => 'Green';

  @override
  String get shortcutColourAmber => 'Amber';

  @override
  String get shortcutColourOrange => 'Orange';

  @override
  String get shortcutColourRed => 'Red';

  @override
  String get shortcutColourPurple => 'Purple';

  @override
  String get shortcutIconLabel => 'Icon';

  @override
  String get shortcutIconLetter => 'First letter';

  @override
  String get shortcutIconApp => 'App';

  @override
  String get shortcutIconMovies => 'Movies';

  @override
  String get shortcutIconLive => 'Live TV';

  @override
  String get shortcutIconSports => 'Sports';

  @override
  String get shortcutIconMusic => 'Music';

  @override
  String get shortcutIconKids => 'Kids';

  @override
  String get shortcutIconNews => 'News';

  @override
  String get shortcutIconGames => 'Games';

  @override
  String get shortcutIconLearning => 'Learning';

  @override
  String get shortcutPreview => 'Preview';

  @override
  String get shortcutSaved => 'Shortcut saved';

  @override
  String get devicesEmptyTitle => 'No TVs yet';

  @override
  String get devicesLoadFailed => 'Couldn\'t load your TVs.';

  @override
  String get devicesEmptyBody => 'Pair a TV to control it from this phone.';

  @override
  String get devicesInUse => 'In use';

  @override
  String devicesEditTv(String tvName) {
    return 'Edit $tvName';
  }

  @override
  String get editDeviceNameLabel => 'Name on this phone';

  @override
  String editDeviceNameHelp(String tvName) {
    return 'Leave empty to use the TV\'s own name, $tvName.';
  }

  @override
  String get editDeviceNameError => 'Use 40 characters or fewer.';

  @override
  String get editDeviceWolTitle => 'Turn on from your phone';

  @override
  String get editDeviceWolBody =>
      'Add the TV\'s MAC address so the power key can wake it from standby.';

  @override
  String get editDeviceWolHelp => 'Where do I find it?';

  @override
  String get editDeviceWolUnavailable =>
      'Turning the TV on from an iPhone isn\'t available yet. You can still save the address.';

  @override
  String get wolMacTooLong =>
      'That\'s longer than a MAC address. Check what you pasted.';

  @override
  String get wolHelpTitle => 'Find the TV\'s MAC address';

  @override
  String editDeviceLastAddress(String host) {
    return 'Last address: $host';
  }

  @override
  String get editDeviceSaved => 'Saved';

  @override
  String get editDeviceSaveFailed => 'Couldn\'t save. Try again.';

  @override
  String get editDeviceRemove => 'Remove TV';

  @override
  String get editDeviceRemoveFailed => 'Couldn\'t remove this TV. Try again.';

  @override
  String editDeviceRemoveTitle(String tvName) {
    return 'Remove $tvName?';
  }

  @override
  String get editDeviceRemoveBody =>
      'This phone forgets the TV and its settings. To use it again, pair it with a new code. The TV may still list this phone.';

  @override
  String get editDeviceRemoveConfirm => 'Remove';

  @override
  String editDeviceRemoved(String tvName) {
    return '$tvName removed';
  }

  @override
  String get editDeviceNotFound =>
      'This TV isn\'t saved on this phone anymore.';

  @override
  String get editDeviceBackToTvs => 'Back to your TVs';

  @override
  String get discoverOpenFailed => 'Couldn\'t open this TV. Try again.';

  @override
  String get settingsSectionRemote => 'Remote';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionSupport => 'Help and feedback';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsRemoteLayoutSubtitle =>
      'Touchpad or D-pad, and the row of keys above it';

  @override
  String get settingsRemoteBehaviourSubtitle =>
      'Vibration, Smooth Press, screen and keyboard';

  @override
  String get settingsAppsSubtitle => 'Choose and order your app shortcuts';

  @override
  String get settingsDevicesSubtitle =>
      'Rename, remove, or turn on from your phone';

  @override
  String get settingsAppearanceSubtitle => 'Theme and language';

  @override
  String get settingsHelpSubtitle => 'Common questions and troubleshooting';

  @override
  String get settingsFeedback => 'Send feedback';

  @override
  String get settingsFeedbackSubtitle => 'Write to us by email';

  @override
  String get settingsAboutSubtitle => 'Version and licences';

  @override
  String get settingsPrivacy => 'Privacy policy';

  @override
  String get settingsTerms => 'Terms of use';

  @override
  String get settingsOpensInBrowser => 'Opens in your browser';

  @override
  String get settingsLinkFailed =>
      'Couldn\'t open the page. Check your internet connection and try again.';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceThemeSystem => 'Same as phone';

  @override
  String get appearanceThemeLight => 'Light';

  @override
  String get appearanceThemeDark => 'Dark';

  @override
  String get appearanceDynamicColour => 'Colours from wallpaper';

  @override
  String get appearanceDynamicColourSubtitle =>
      'Use your phone\'s wallpaper colours in the app.';

  @override
  String get appearanceLanguage => 'Language';

  @override
  String get appearanceLanguageSystem => 'Same as phone';

  @override
  String get layoutPreviewTitle => 'Preview';

  @override
  String get layoutPreviewSemantics =>
      'Preview of the remote with these choices';

  @override
  String get layoutNavigation => 'Navigation';

  @override
  String get layoutTouchpadSubtitle => 'Swipe to move, tap to select.';

  @override
  String get layoutDpadSubtitle =>
      'Arrow keys around an OK button, like a TV remote.';

  @override
  String get layoutQuickAccess => 'Row above the pad';

  @override
  String get layoutQuickApps => 'App shortcuts';

  @override
  String get layoutQuickAppsSubtitle => 'Open your TV apps with one tap.';

  @override
  String get layoutQuickColourSubtitle => 'Red, green, yellow and blue keys.';

  @override
  String get layoutQuickMediaSubtitle =>
      'Previous, rewind, play or pause, fast-forward and next.';

  @override
  String get layoutQuickNone => 'Nothing';

  @override
  String get layoutQuickNoneSubtitle => 'More room for the touchpad or D-pad.';

  @override
  String get behaviourHaptics => 'Vibrate on key press';

  @override
  String get behaviourHapticsSubtitle =>
      'A short vibration when a key reaches the TV.';

  @override
  String get behaviourSmoothPress => 'Smooth Press';

  @override
  String get behaviourSmoothPressSubtitle =>
      'Holding volume, channel or arrow keys acts like holding a key on a TV remote. When off, holding repeats the key.';

  @override
  String get behaviourKeepAwake => 'Keep screen on';

  @override
  String get behaviourKeepAwakeSubtitle =>
      'Your phone\'s screen stays on while the remote is open.';

  @override
  String get behaviourTheater => 'Theater mode';

  @override
  String get behaviourTheaterSubtitle =>
      'Dims your phone after 30 seconds without a touch. The first touch only brightens it.';

  @override
  String get behaviourAutoKeyboard => 'Open keyboard automatically';

  @override
  String get behaviourAutoKeyboardSubtitle =>
      'Opens the keyboard when the TV asks for text, like in a search box.';

  @override
  String get helpCantConnectTitle => 'Can\'t connect?';

  @override
  String get helpCantConnectBody =>
      'Go through the checks one at a time. Most problems come from the Wi-Fi network or the TV\'s remote service.';

  @override
  String get helpTroubleshootingAction => 'Show troubleshooting steps';

  @override
  String get helpFaqTitle => 'Common questions';

  @override
  String get helpStillStuck => 'Still stuck?';

  @override
  String get faqTvsQ => 'Which TVs does this app work with?';

  @override
  String get faqTvsA =>
      'TVs and streaming boxes that run Android TV or Google TV, on the same Wi-Fi network as your phone. TVs with other systems, such as Samsung (Tizen), LG (webOS), Roku or Fire TV, can\'t be controlled by this app.';

  @override
  String get faqNotFoundQ => 'My TV isn\'t in the list.';

  @override
  String get faqNotFoundA =>
      'Make sure the TV is on and connected to the same Wi-Fi as your phone, and that \"Android TV Remote Service\" is up to date on the TV. You can also add the TV by its IP address. The troubleshooting steps go through each check.';

  @override
  String get faqCodeQ => 'Why does the TV ask for a code again?';

  @override
  String get faqCodeA =>
      'Pairing makes the TV and this phone trust each other. Clearing the app\'s data, reinstalling the app or resetting the TV removes that trust, so you pair once more with a new code.';

  @override
  String get faqPowerQ => 'Why can\'t the app turn my TV on?';

  @override
  String get faqPowerA =>
      'A TV that is fully off can\'t hear the app. The app can send a wake-up signal if you add the TV\'s MAC address under Settings → Your TVs, but some TVs ignore it in deep standby. On iPhone this isn\'t available yet.';

  @override
  String get faqTypingQ => 'What I type doesn\'t show up on the TV.';

  @override
  String get faqTypingA =>
      'Select a text field on the TV first, such as a search box. When the TV asks for text, the keyboard opens on your phone by itself.';

  @override
  String get faqAppQ => 'An app shortcut doesn\'t open.';

  @override
  String get faqAppA =>
      'The app has to be installed on the TV. Some apps have a different version in each country: add the right one by its app ID under Settings → Apps.';

  @override
  String get faqPrivacyQ => 'What does the app keep about my TV?';

  @override
  String get faqPrivacyA =>
      'Your TV\'s name, network address and MAC address stay on this phone. The app can send anonymous usage statistics and crash reports, which never include them. You can turn each on or off in Settings → Privacy choices.';

  @override
  String get faqNewPhoneQ => 'I moved to a new phone. Where are my TVs?';

  @override
  String get faqNewPhoneA =>
      'Your TVs and their pairing stay on the phone you paired them with. They aren\'t copied by backups or when you move to a new phone, so pair each TV again on the new phone.';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutVersionUnknown => 'Version unavailable';

  @override
  String get aboutLicences => 'Open-source licences';

  @override
  String get aboutProtocol =>
      'Talks to your TV over Wi-Fi with the Android TV Remote protocol. Its message formats come from the open-source androidtvremote2 project.';

  @override
  String get aboutTrademark =>
      'Android TV and Google TV are trademarks of Google LLC. This app isn\'t made or endorsed by Google.';

  @override
  String get feedbackTitle => 'Send feedback?';

  @override
  String get feedbackBody =>
      'Your email app opens with a message to us. It includes the app version and your phone\'s system version, and nothing about your TV.';

  @override
  String get feedbackConfirm => 'Write email';

  @override
  String feedbackSubject(String appName, String version) {
    return 'Feedback on $appName $version';
  }

  @override
  String get feedbackPrompt => 'Write your message here.';

  @override
  String feedbackNoEmailApp(String email) {
    return 'No email app found. Write to us at $email.';
  }

  @override
  String get settingsPremiumSubtitle => 'No ads and extra colour styles';

  @override
  String get settingsPremiumActiveSubtitle => 'You have Premium. Thank you!';

  @override
  String get pageTitlePrivacyChoices => 'Privacy choices';

  @override
  String get settingsPrivacyChoicesSubtitle =>
      'Usage statistics, crash reports and ads';

  @override
  String get aboutTestCrash => 'Send a test crash report';

  @override
  String get aboutTestCrashSent =>
      'Test crash report sent. It shows in Crashlytics within a few minutes.';

  @override
  String get privacyIntro =>
      'Choose what the app may share. Your TV\'s name, network address and MAC address never leave this phone.';

  @override
  String get privacySectionImprove => 'Help improve the app';

  @override
  String get privacyUsageTitle => 'Share usage statistics';

  @override
  String get privacyUsageSubtitle =>
      'Anonymous counts of the screens and features you use. Never what you type or anything about your TV.';

  @override
  String get privacyCrashTitle => 'Share crash reports';

  @override
  String get privacyCrashSubtitle =>
      'Sent when something goes wrong, so it can be fixed. Names, addresses and codes are removed first.';

  @override
  String get privacyServicesOff =>
      'This build of the app doesn\'t send usage statistics or crash reports.';

  @override
  String get privacySectionAds => 'Ads';

  @override
  String get privacyAdsInfo =>
      'The free app shows a banner ad at the bottom of the Apps and Settings screens only.';

  @override
  String get privacyAdsPremium => 'You have Premium, so the app shows no ads.';

  @override
  String get privacyAdChoices => 'Ad privacy choices';

  @override
  String get privacyAdChoicesSubtitle => 'Choose how ads are picked for you.';

  @override
  String get privacyAdChoicesFailed =>
      'Couldn\'t open ad privacy choices. Check your internet connection and try again.';

  @override
  String get privacyRemoveAds => 'Remove ads with Premium';

  @override
  String get privacyTrackingTitle => 'Ad tracking';

  @override
  String get privacyTrackingAllowed =>
      'Allowed. You can change this in your iPhone\'s Settings.';

  @override
  String get privacyTrackingDenied =>
      'Not allowed. You can change this in your iPhone\'s Settings.';

  @override
  String get privacyTrackingNotDetermined =>
      'Not chosen yet. The app asks before it first shows an ad.';

  @override
  String get privacyTrackingRestricted => 'Turned off on this iPhone.';

  @override
  String get privacyOpensSettings => 'Opens your phone\'s Settings';

  @override
  String get trackingPrepromptTitle => 'About ads in this app';

  @override
  String get trackingPrepromptBody =>
      'The free app shows a small ad at the bottom of this screen. Next, your iPhone asks whether the app may use your activity in other apps to choose ads. You see the same number of ads whatever you choose, and the remote works the same.';

  @override
  String get trackingPrepromptContinue => 'Continue';

  @override
  String get adLabel => 'Advertisement';

  @override
  String get paywallHeadline => 'Make the remote yours';

  @override
  String get paywallSubhead =>
      'Premium removes ads, adds colour styles and supports the app\'s development.';

  @override
  String get paywallBenefitNoAds => 'No ads';

  @override
  String get paywallBenefitNoAdsBody =>
      'No banner on the Apps and Settings screens.';

  @override
  String get paywallBenefitStyles => 'Colour styles';

  @override
  String get paywallBenefitStylesBody =>
      'Ocean, Ember and Midnight, in light and dark.';

  @override
  String get paywallFreeForever =>
      'Everything else stays free: every TV, every remote control, app shortcuts, the keyboard and turning your TV on.';

  @override
  String get paywallChoosePlan => 'Choose a plan';

  @override
  String get paywallPlanMonthly => 'Monthly';

  @override
  String get paywallPlanYearly => 'Yearly';

  @override
  String get paywallPlanLifetime => 'Lifetime';

  @override
  String paywallPricePerMonth(String price) {
    return '$price per month';
  }

  @override
  String paywallPricePerYear(String price) {
    return '$price per year';
  }

  @override
  String paywallPriceOnce(String price) {
    return '$price, one payment';
  }

  @override
  String get paywallRenewsMonthly => 'Renews every month until you cancel.';

  @override
  String get paywallRenewsYearly => 'Renews every year until you cancel.';

  @override
  String get paywallLifetimeTerms => 'Pay once. No subscription.';

  @override
  String get paywallBestValue => 'Best value';

  @override
  String paywallSavePercent(int percent) {
    return 'Save $percent%';
  }

  @override
  String get paywallContinue => 'Continue';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallTermsAndroid =>
      'Payment is charged to your Google Play account. Subscriptions renew automatically until you cancel them in Google Play, and you keep Premium until the end of the period you paid for.';

  @override
  String get paywallTermsIos =>
      'Payment is charged to your Apple ID. Subscriptions renew automatically unless you cancel at least 24 hours before the end of the current period. Manage or cancel them in your Apple ID settings.';

  @override
  String get paywallLoading => 'Loading plans…';

  @override
  String get paywallUnavailableTitle => 'Premium isn\'t available right now';

  @override
  String get paywallUnavailableBody =>
      'Check your internet connection and try again.';

  @override
  String get paywallPurchasing => 'Confirming your purchase…';

  @override
  String get paywallRestoring => 'Restoring your purchases…';

  @override
  String get paywallWelcome => 'Welcome to Premium. Thank you!';

  @override
  String get paywallPending =>
      'Your purchase is waiting for approval. Premium starts as soon as it\'s complete.';

  @override
  String get paywallFailed => 'The purchase didn\'t go through. Try again.';

  @override
  String get paywallNetworkError =>
      'Couldn\'t reach the store. Check your internet connection and try again.';

  @override
  String get paywallNotAllowed => 'Purchases aren\'t allowed on this phone.';

  @override
  String get paywallAlreadyOwned =>
      'You already own Premium. Tap Restore purchases to get it back.';

  @override
  String get paywallRestored => 'Purchases restored. You have Premium.';

  @override
  String get paywallNothingToRestore => 'No purchases found for this account.';

  @override
  String get paywallRestoreFailed => 'Couldn\'t restore purchases. Try again.';

  @override
  String get paywallActiveTitle => 'You have Premium';

  @override
  String get paywallActiveBody =>
      'Thank you for supporting the app. There are no ads, and every colour style is yours.';

  @override
  String get paywallActiveLifetime => 'Lifetime Premium: it never expires.';

  @override
  String get paywallManageSubscription => 'Manage subscription';

  @override
  String get appearanceStyle => 'Colour style';

  @override
  String get appearanceStyleStandard => 'Standard';

  @override
  String get appearanceStyleOcean => 'Ocean';

  @override
  String get appearanceStyleEmber => 'Ember';

  @override
  String get appearanceStyleMidnight => 'Midnight';

  @override
  String get appearanceStyleLocked => 'Included with Premium';

  @override
  String get appearanceStyleWallpaperOn =>
      'Colours from wallpaper are on, so colour styles don\'t show.';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version of the app is too old to keep working reliably. Update to the latest version to continue.';

  @override
  String get updateRequiredAction => 'Update';

  @override
  String get updateRequiredFailed =>
      'Couldn\'t open the store. Update the app from your phone\'s app store.';

  @override
  String get loadingLabel => 'Loading…';

  @override
  String get manageAppsMoreOptions => 'More options';

  @override
  String manageAppsMoved(String app, int position, int count) {
    return '$app moved to position $position of $count';
  }
}
