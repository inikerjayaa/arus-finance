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
  });

  final String id;
  final String name;
  final SakuIconGroup group;
  final List<String> keywords;

  /// Optional bundled local asset. Null means the UI must render the generic
  /// local fallback until a vetted asset is bundled. Never fetch icons from
  /// the network at runtime.
  final String? assetPath;
}

abstract final class SakuBrandIconCatalog {
  static const items = <SakuBrandIcon>[
    // A — Banks & digital banks
    SakuBrandIcon(id: 'bca', name: 'BCA', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'mandiri', name: 'Bank Mandiri', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bri', name: 'BRI', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bni', name: 'BNI', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'btn', name: 'BTN', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bsi', name: 'BSI', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'cimb_niaga', name: 'CIMB Niaga', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'permata', name: 'PermataBank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'danamon', name: 'Danamon', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'ocbc', name: 'OCBC', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'maybank', name: 'Maybank Indonesia', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'panin', name: 'Panin Bank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bank_mega', name: 'Bank Mega', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bank_jago', name: 'Bank Jago', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'seabank', name: 'SeaBank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'blu', name: 'blu by BCA Digital', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'neobank', name: 'neobank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'uob', name: 'UOB Indonesia', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'hsbc', name: 'HSBC Indonesia', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'standard_chartered', name: 'Standard Chartered Indonesia', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'sinarmas', name: 'Bank Sinarmas', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'kb_bank', name: 'KB Bank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'muamalat', name: 'Bank Muamalat', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'allo_bank', name: 'Allo Bank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bank_raya', name: 'Bank Raya', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'jenius', name: 'Jenius', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'digibank', name: 'digibank by DBS', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'line_bank', name: 'LINE Bank', group: SakuIconGroup.bank),
    SakuBrandIcon(id: 'bank_saqu', name: 'Bank Saqu', group: SakuIconGroup.bank),
    SakuBrandIcon(
      id: 'motionbanking',
      name: 'MotionBanking',
      group: SakuIconGroup.bank,
      keywords: ['motion', 'banking'],
    ),

    // B — E-wallets & payment
    SakuBrandIcon(id: 'dana', name: 'DANA', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'ovo', name: 'OVO', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'gopay', name: 'GoPay', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'shopeepay', name: 'ShopeePay', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'linkaja', name: 'LinkAja', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'isaku', name: 'i.Saku', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'sakuku', name: 'Sakuku', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'astrapay', name: 'AstraPay', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'paypal', name: 'PayPal', group: SakuIconGroup.wallet),
    SakuBrandIcon(id: 'qris', name: 'QRIS', group: SakuIconGroup.wallet),

    // C — Transport, travel & lifestyle
    SakuBrandIcon(id: 'gojek', name: 'Gojek', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'grab', name: 'Grab', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'maxim', name: 'Maxim', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'indrive', name: 'inDrive', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'traveloka', name: 'Traveloka', group: SakuIconGroup.transport),
    SakuBrandIcon(id: 'tiket', name: 'tiket.com', group: SakuIconGroup.transport),

    // D — Marketplaces
    SakuBrandIcon(id: 'tokopedia', name: 'Tokopedia', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'shopee', name: 'Shopee', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'lazada', name: 'Lazada', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'blibli', name: 'Blibli', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'bukalapak', name: 'Bukalapak', group: SakuIconGroup.marketplace),
    SakuBrandIcon(id: 'tiktok_shop', name: 'TikTok Shop', group: SakuIconGroup.marketplace),

    // E — Subscriptions & digital services
    SakuBrandIcon(id: 'youtube', name: 'YouTube', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'youtube_premium', name: 'YouTube Premium', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'netflix', name: 'Netflix', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'spotify', name: 'Spotify', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'disney_plus', name: 'Disney+', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'vidio', name: 'Vidio', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'prime_video', name: 'Prime Video', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'canva', name: 'Canva', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'capcut', name: 'CapCut', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'zoom', name: 'Zoom', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'google_one', name: 'Google One', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'icloud', name: 'iCloud', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'microsoft_365', name: 'Microsoft 365', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'adobe', name: 'Adobe', group: SakuIconGroup.subscription),
    SakuBrandIcon(id: 'notion', name: 'Notion', group: SakuIconGroup.subscription),

    // F — AI tools
    SakuBrandIcon(id: 'chatgpt', name: 'ChatGPT', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'gemini', name: 'Gemini', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'claude', name: 'Claude', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'perplexity', name: 'Perplexity', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'midjourney', name: 'Midjourney', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'github_copilot', name: 'GitHub Copilot', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'grok', name: 'Grok', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'cursor', name: 'Cursor', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'openrouter', name: 'OpenRouter', group: SakuIconGroup.ai),
    SakuBrandIcon(id: 'deepseek', name: 'DeepSeek', group: SakuIconGroup.ai),

    // G — Telco & internet
    SakuBrandIcon(id: 'telkomsel', name: 'Telkomsel', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'byu', name: 'by.U', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'im3', name: 'IM3', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'xl', name: 'XL', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'axis', name: 'AXIS', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'smartfren', name: 'Smartfren', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'tri', name: 'Tri', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'first_media', name: 'First Media', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'indihome', name: 'IndiHome', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'biznet', name: 'Biznet', group: SakuIconGroup.telco),
    SakuBrandIcon(id: 'myrepublic', name: 'MyRepublic', group: SakuIconGroup.telco),

    // H — Utilities & bills
    SakuBrandIcon(id: 'pln', name: 'PLN', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'pdam', name: 'PDAM', group: SakuIconGroup.utility),
    SakuBrandIcon(id: 'bpjs', name: 'BPJS', group: SakuIconGroup.utility),
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
