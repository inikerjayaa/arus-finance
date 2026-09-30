enum SakuIconGroup {
  bank,
  wallet,
  transport,
  marketplace,
  subscription,
  ai,
  telco,
  utility,
  generic,
}

class SakuBrandIcon {
  const SakuBrandIcon({
    required this.id,
    required this.name,
    required this.group,
    this.keywords = const <String>[],
    this.assetPath,
    this.isUserApprovedArtwork = false,
  });

  final String id;
  final String name;
  final SakuIconGroup group;
  final List<String> keywords;

  /// Vetted local asset. Official artwork is required unless the user has
  /// explicitly approved an original custom design. Never fetch at runtime.
  final String? assetPath;

  /// PDAM is the sole approved custom design (user request, 2026-09-29).
  final bool isUserApprovedArtwork;
}

abstract final class SakuBrandIconCatalog {
  static const items = <SakuBrandIcon>[
    // A — Banks & digital banks
    SakuBrandIcon(id: 'bca', assetPath: 'assets/brands/bca.png', name: 'BCA', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'mandiri', assetPath: 'assets/brands/mandiri.png', name: 'Bank Mandiri', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bri', assetPath: 'assets/brands/bri.png', name: 'BRI', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bni', assetPath: 'assets/brands/bni.png', name: 'BNI', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'btn', assetPath: 'assets/brands/btn.png', name: 'BTN', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bsi', assetPath: 'assets/brands/bsi.png', name: 'BSI', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'cimb_niaga', assetPath: 'assets/brands/cimb_niaga.png', name: 'CIMB Niaga', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'permata', assetPath: 'assets/brands/permata.png', name: 'PermataBank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'danamon', assetPath: 'assets/brands/danamon.png', name: 'Danamon', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'ocbc', assetPath: 'assets/brands/ocbc.png', name: 'OCBC', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'maybank', assetPath: 'assets/brands/maybank.png', name: 'Maybank Indonesia', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'panin', assetPath: 'assets/brands/panin.png', name: 'Panin Bank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bank_mega', assetPath: 'assets/brands/bank_mega.png', name: 'Bank Mega', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bank_jago', assetPath: 'assets/brands/bank_jago.png', name: 'Bank Jago', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'seabank', assetPath: 'assets/brands/seabank.png', name: 'SeaBank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'blu', assetPath: 'assets/brands/blu.png', name: 'blu by BCA Digital', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'neobank', assetPath: 'assets/brands/neobank.png', name: 'neobank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'uob', assetPath: 'assets/brands/uob.png', name: 'UOB Indonesia', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'hsbc', assetPath: 'assets/brands/hsbc.png', name: 'HSBC Indonesia', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'standard_chartered', assetPath: 'assets/brands/standard_chartered.png', name: 'Standard Chartered Indonesia', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'sinarmas', assetPath: 'assets/brands/sinarmas.png', name: 'Bank Sinarmas', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'kb_bank', assetPath: 'assets/brands/kb_bank.png', name: 'KB Bank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'muamalat', assetPath: 'assets/brands/muamalat.jpg', name: 'Bank Muamalat', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'allo_bank', assetPath: 'assets/brands/allo_bank.png', name: 'Allo Bank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bank_raya', assetPath: 'assets/brands/bank_raya.png', name: 'Bank Raya', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'jenius', assetPath: 'assets/brands/jenius.png', name: 'Jenius', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'digibank', assetPath: 'assets/brands/digibank.png', name: 'digibank by DBS', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'line_bank', assetPath: 'assets/brands/line_bank.png', name: 'LINE Bank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bank_saqu', assetPath: 'assets/brands/bank_saqu.png', name: 'Bank Saqu', group: SakuIconGroup.bank),
    SakuBrandIcon(
      id: 'motionbanking', assetPath: 'assets/brands/motionbanking.png',
      name: 'MotionBanking',
      group: SakuIconGroup.bank,
      keywords: ['motion', 'banking'],
    ),

    // B — E-wallets & payment
    SakuBrandIcon(id: 'dana', assetPath: 'assets/brands/dana.png', name: 'DANA', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'ovo', assetPath: 'assets/brands/ovo.png', name: 'OVO', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'gopay', assetPath: 'assets/brands/gopay.png', name: 'GoPay', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'shopeepay', assetPath: 'assets/brands/shopeepay.png', name: 'ShopeePay', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'linkaja', assetPath: 'assets/brands/linkaja.png', name: 'LinkAja', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'isaku', assetPath: 'assets/brands/isaku.png', name: 'i.Saku', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'sakuku', assetPath: 'assets/brands/sakuku.png', name: 'Sakuku', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'astrapay', assetPath: 'assets/brands/astrapay.webp', name: 'AstraPay', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'paypal', assetPath: 'assets/brands/paypal.png', name: 'PayPal', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'qris', assetPath: 'assets/brands/qris.png', name: 'QRIS', group: SakuIconGroup.wallet),

    // C — Transport, travel & lifestyle
    SakuBrandIcon(id: 'gojek', assetPath: 'assets/brands/gojek.png', name: 'Gojek', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'grab', assetPath: 'assets/brands/grab.png', name: 'Grab', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'maxim', assetPath: 'assets/brands/maxim.png', name: 'Maxim', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'indrive', assetPath: 'assets/brands/indrive.png', name: 'inDrive', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'traveloka', assetPath: 'assets/brands/traveloka.png', name: 'Traveloka', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'tiket', assetPath: 'assets/brands/tiket.png', name: 'tiket.com', group: SakuIconGroup.transport),

    // D — Marketplaces
    SakuBrandIcon(id: 'tokopedia', assetPath: 'assets/brands/tokopedia.png', name: 'Tokopedia', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'shopee', assetPath: 'assets/brands/shopee.png', name: 'Shopee', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'lazada', assetPath: 'assets/brands/lazada.png', name: 'Lazada', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'blibli', assetPath: 'assets/brands/blibli.png', name: 'Blibli', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'bukalapak', assetPath: 'assets/brands/bukalapak.png', name: 'Bukalapak', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'tiktok_shop', assetPath: 'assets/brands/tiktok_shop.png', name: 'TikTok Shop', group: SakuIconGroup.marketplace),

    // E — Subscriptions & digital services
    SakuBrandIcon(id: 'youtube', assetPath: 'assets/brands/youtube.png', name: 'YouTube', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'youtube_premium', assetPath: 'assets/brands/youtube_premium.png', name: 'YouTube Premium', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'netflix', assetPath: 'assets/brands/netflix.png', name: 'Netflix', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'spotify', assetPath: 'assets/brands/spotify.png', name: 'Spotify', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'disney_plus', assetPath: 'assets/brands/disney_plus.png', name: 'Disney+', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'vidio', assetPath: 'assets/brands/vidio.png', name: 'Vidio', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'prime_video', assetPath: 'assets/brands/prime_video.png', name: 'Prime Video', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'canva', assetPath: 'assets/brands/canva.png', name: 'Canva', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'capcut', assetPath: 'assets/brands/capcut.png', name: 'CapCut', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'zoom', assetPath: 'assets/brands/zoom.png', name: 'Zoom', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'google_one', assetPath: 'assets/brands/google_one.png', name: 'Google One', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'icloud', assetPath: 'assets/brands/icloud.png', name: 'iCloud', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'microsoft_365', assetPath: 'assets/brands/microsoft_365.png', name: 'Microsoft 365', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'adobe', assetPath: 'assets/brands/adobe.png', name: 'Adobe', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'notion', assetPath: 'assets/brands/notion.png', name: 'Notion', group: SakuIconGroup.subscription),

    // F — AI tools
    SakuBrandIcon(id: 'chatgpt', assetPath: 'assets/brands/chatgpt.png', name: 'ChatGPT', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'gemini', assetPath: 'assets/brands/gemini.png', name: 'Gemini', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'claude', assetPath: 'assets/brands/claude.png', name: 'Claude', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'perplexity', assetPath: 'assets/brands/perplexity.png', name: 'Perplexity', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'midjourney', assetPath: 'assets/brands/midjourney.png', name: 'Midjourney', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'github_copilot', assetPath: 'assets/brands/github_copilot.png', name: 'GitHub Copilot', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'grok', assetPath: 'assets/brands/grok.png', name: 'Grok', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'cursor', assetPath: 'assets/brands/cursor.png', name: 'Cursor', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'openrouter', assetPath: 'assets/brands/openrouter.png', name: 'OpenRouter', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'deepseek', assetPath: 'assets/brands/deepseek.png', name: 'DeepSeek', group: SakuIconGroup.ai),

    // G — Telco & internet
    SakuBrandIcon(id: 'telkomsel', assetPath: 'assets/brands/telkomsel.png', name: 'Telkomsel', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'byu', assetPath: 'assets/brands/byu.png', name: 'by.U', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'im3', assetPath: 'assets/brands/im3.png', name: 'IM3', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'xl', assetPath: 'assets/brands/xl.png', name: 'XL', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'axis', assetPath: 'assets/brands/axis.png', name: 'AXIS', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'smartfren', assetPath: 'assets/brands/smartfren.png', name: 'Smartfren', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'tri', assetPath: 'assets/brands/tri.png', name: 'Tri', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'first_media', assetPath: 'assets/brands/first_media.png', name: 'First Media', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'indihome', assetPath: 'assets/brands/indihome.png', name: 'IndiHome', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'biznet', assetPath: 'assets/brands/biznet.png', name: 'Biznet', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'myrepublic', assetPath: 'assets/brands/myrepublic.png', name: 'MyRepublic', group: SakuIconGroup.telco),

    // H — Utilities & bills
    SakuBrandIcon(id: 'pln', assetPath: 'assets/brands/pln.png', name: 'PLN', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'pdam', assetPath: 'assets/brands/pdam.png', name: 'PDAM', group: SakuIconGroup.utility, isUserApprovedArtwork: true),
    SakuBrandIcon(id: 'bpjs', assetPath: 'assets/brands/bpjs.png', name: 'BPJS', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'pbb', name: 'PBB', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'vehicle_tax', name: 'Pajak Kendaraan', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'home_internet', name: 'Internet Rumah', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'electricity', name: 'Listrik', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'water', name: 'Air', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'gas', name: 'Gas', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'installment', name: 'Cicilan', group: SakuIconGroup.utility),

    // I — Generic local fallbacks
    SakuBrandIcon(id: 'cash', name: 'Tunai', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'bank_account', name: 'Rekening Bank', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'digital_wallet', name: 'Dompet Digital', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'credit_card', name: 'Kartu Kredit', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'loan', name: 'Pinjaman', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'savings', name: 'Tabungan', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'investment', name: 'Investasi', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'salary', name: 'Gaji', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'bonus', name: 'Bonus', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'food', name: 'Makanan', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'drink', name: 'Minuman', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'transport', name: 'Transport', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'shopping', name: 'Belanja', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'health', name: 'Kesehatan', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'education', name: 'Pendidikan', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'entertainment', name: 'Hiburan', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'household', name: 'Rumah Tangga', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'business', name: 'Bisnis', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'gift', name: 'Hadiah', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'donation', name: 'Donasi', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'subscription', name: 'Langganan', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'bill', name: 'Tagihan', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'topup', name: 'Top Up', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'transfer', name: 'Transfer', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'refund', name: 'Refund', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'tax', name: 'Pajak', group: SakuIconGroup.generic),
    SakuBrandIcon(id: 'other', name: 'Lainnya', group: SakuIconGroup.generic),
  ];

  static SakuBrandIcon? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}

/// Icon resolution contract used by account/category/merchant/subscription UI.
/// A user-owned custom icon always wins over a bundled brand icon.
enum SakuIconSource { userCustom, bundledBrand, genericFallback }
