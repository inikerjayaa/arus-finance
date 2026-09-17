import 'package:flutter/material.dart';

enum SakuIconGroup {
  bank,
  eWallet,
  transport,
  marketplace,
  subscription,
  ai,
  telco,
  utility,
  generic,
}

enum SakuIconSource { brand, builtin, custom }

class SakuIconEntry {
  const SakuIconEntry({
    required this.id,
    required this.label,
    required this.group,
    required this.fallback,
    this.keywords = const <String>[],
    this.brandSlug,
  });

  final String id;
  final String label;
  final SakuIconGroup group;
  final IconData fallback;
  final List<String> keywords;

  /// Stable slot for a bundled, vetted brand mark. The rendering layer may
  /// use it when an official/local asset is available; otherwise [fallback]
  /// is used. No remote image is required.
  final String? brandSlug;
}

class SakuIconSelection {
  const SakuIconSelection._({
    required this.source,
    this.catalogId,
    this.customLocalPath,
  });

  const SakuIconSelection.catalog(String catalogId)
      : this._(source: SakuIconSource.brand, catalogId: catalogId);

  const SakuIconSelection.builtin(String catalogId)
      : this._(source: SakuIconSource.builtin, catalogId: catalogId);

  const SakuIconSelection.custom(String localPath)
      : this._(source: SakuIconSource.custom, customLocalPath: localPath);

  final SakuIconSource source;
  final String? catalogId;
  final String? customLocalPath;
}

abstract final class SakuIconCatalog {
  static const all = <SakuIconEntry>[
    // A — Banks / digital banking.
    SakuIconEntry(id: 'bca', label: 'BCA', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'bca', keywords: ['bank central asia']),
    SakuIconEntry(id: 'mandiri', label: 'Bank Mandiri', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'mandiri'),
    SakuIconEntry(id: 'bri', label: 'BRI', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'bri'),
    SakuIconEntry(id: 'bni', label: 'BNI', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'bni'),
    SakuIconEntry(id: 'btn', label: 'BTN', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'btn'),
    SakuIconEntry(id: 'bsi', label: 'BSI', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'bsi'),
    SakuIconEntry(id: 'cimb_niaga', label: 'CIMB Niaga', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'cimb-niaga'),
    SakuIconEntry(id: 'permata', label: 'PermataBank', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'permata'),
    SakuIconEntry(id: 'danamon', label: 'Danamon', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'danamon'),
    SakuIconEntry(id: 'ocbc', label: 'OCBC', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'ocbc'),
    SakuIconEntry(id: 'maybank', label: 'Maybank Indonesia', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'maybank'),
    SakuIconEntry(id: 'panin', label: 'Panin Bank', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'panin'),
    SakuIconEntry(id: 'mega', label: 'Bank Mega', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'bank-mega'),
    SakuIconEntry(id: 'jago', label: 'Bank Jago', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'bank-jago'),
    SakuIconEntry(id: 'seabank', label: 'SeaBank', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'seabank'),
    SakuIconEntry(id: 'blu', label: 'blu by BCA Digital', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'blu'),
    SakuIconEntry(id: 'neo', label: 'neobank', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'neobank'),
    SakuIconEntry(id: 'uob', label: 'UOB Indonesia', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'uob'),
    SakuIconEntry(id: 'hsbc', label: 'HSBC Indonesia', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'hsbc'),
    SakuIconEntry(id: 'standard_chartered', label: 'Standard Chartered', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'standard-chartered'),
    SakuIconEntry(id: 'sinarmas', label: 'Bank Sinarmas', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'sinarmas'),
    SakuIconEntry(id: 'kb_bank', label: 'KB Bank', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'kb-bank'),
    SakuIconEntry(id: 'muamalat', label: 'Bank Muamalat', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'muamalat'),
    SakuIconEntry(id: 'allo', label: 'Allo Bank', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'allo-bank'),
    SakuIconEntry(id: 'raya', label: 'Bank Raya', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'bank-raya'),
    SakuIconEntry(id: 'jenius', label: 'Jenius', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'jenius'),
    SakuIconEntry(id: 'digibank', label: 'digibank by DBS', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'digibank'),
    SakuIconEntry(id: 'line_bank', label: 'LINE Bank', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'line-bank'),
    SakuIconEntry(id: 'saqu', label: 'Bank Saqu', group: SakuIconGroup.bank, fallback: Icons.account_balance_rounded, brandSlug: 'bank-saqu'),

    // B — E-wallet / payment.
    SakuIconEntry(id: 'dana', label: 'DANA', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'dana'),
    SakuIconEntry(id: 'ovo', label: 'OVO', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'ovo'),
    SakuIconEntry(id: 'gopay', label: 'GoPay', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'gopay'),
    SakuIconEntry(id: 'shopeepay', label: 'ShopeePay', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'shopeepay'),
    SakuIconEntry(id: 'linkaja', label: 'LinkAja', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'linkaja'),
    SakuIconEntry(id: 'isaku', label: 'i.saku', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'isaku'),
    SakuIconEntry(id: 'sakuku', label: 'Sakuku', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'sakuku'),
    SakuIconEntry(id: 'astrapay', label: 'AstraPay', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'astrapay'),
    SakuIconEntry(id: 'paypal', label: 'PayPal', group: SakuIconGroup.eWallet, fallback: Icons.account_balance_wallet_rounded, brandSlug: 'paypal'),
    SakuIconEntry(id: 'qris', label: 'QRIS', group: SakuIconGroup.eWallet, fallback: Icons.qr_code_2_rounded, brandSlug: 'qris'),

    // C — Transport / lifestyle.
    SakuIconEntry(id: 'gojek', label: 'Gojek', group: SakuIconGroup.transport, fallback: Icons.two_wheeler_rounded, brandSlug: 'gojek'),
    SakuIconEntry(id: 'grab', label: 'Grab', group: SakuIconGroup.transport, fallback: Icons.local_taxi_rounded, brandSlug: 'grab'),
    SakuIconEntry(id: 'maxim', label: 'Maxim', group: SakuIconGroup.transport, fallback: Icons.local_taxi_rounded, brandSlug: 'maxim'),
    SakuIconEntry(id: 'indrive', label: 'inDrive', group: SakuIconGroup.transport, fallback: Icons.local_taxi_rounded, brandSlug: 'indrive'),
    SakuIconEntry(id: 'traveloka', label: 'Traveloka', group: SakuIconGroup.transport, fallback: Icons.flight_takeoff_rounded, brandSlug: 'traveloka'),
    SakuIconEntry(id: 'tiket', label: 'tiket.com', group: SakuIconGroup.transport, fallback: Icons.airplane_ticket_rounded, brandSlug: 'tiket-com'),

    // D — Marketplace.
    SakuIconEntry(id: 'tokopedia', label: 'Tokopedia', group: SakuIconGroup.marketplace, fallback: Icons.shopping_bag_rounded, brandSlug: 'tokopedia'),
    SakuIconEntry(id: 'shopee', label: 'Shopee', group: SakuIconGroup.marketplace, fallback: Icons.shopping_bag_rounded, brandSlug: 'shopee'),
    SakuIconEntry(id: 'lazada', label: 'Lazada', group: SakuIconGroup.marketplace, fallback: Icons.shopping_bag_rounded, brandSlug: 'lazada'),
    SakuIconEntry(id: 'blibli', label: 'Blibli', group: SakuIconGroup.marketplace, fallback: Icons.shopping_bag_rounded, brandSlug: 'blibli'),
    SakuIconEntry(id: 'bukalapak', label: 'Bukalapak', group: SakuIconGroup.marketplace, fallback: Icons.shopping_bag_rounded, brandSlug: 'bukalapak'),
    SakuIconEntry(id: 'tiktok_shop', label: 'TikTok Shop', group: SakuIconGroup.marketplace, fallback: Icons.shopping_bag_rounded, brandSlug: 'tiktok-shop'),

    // E — Subscription / digital services.
    SakuIconEntry(id: 'youtube', label: 'YouTube', group: SakuIconGroup.subscription, fallback: Icons.play_circle_fill_rounded, brandSlug: 'youtube'),
    SakuIconEntry(id: 'youtube_premium', label: 'YouTube Premium', group: SakuIconGroup.subscription, fallback: Icons.play_circle_fill_rounded, brandSlug: 'youtube-premium'),
    SakuIconEntry(id: 'netflix', label: 'Netflix', group: SakuIconGroup.subscription, fallback: Icons.movie_rounded, brandSlug: 'netflix'),
    SakuIconEntry(id: 'spotify', label: 'Spotify', group: SakuIconGroup.subscription, fallback: Icons.music_note_rounded, brandSlug: 'spotify'),
    SakuIconEntry(id: 'disney_plus', label: 'Disney+', group: SakuIconGroup.subscription, fallback: Icons.movie_filter_rounded, brandSlug: 'disney-plus'),
    SakuIconEntry(id: 'vidio', label: 'Vidio', group: SakuIconGroup.subscription, fallback: Icons.live_tv_rounded, brandSlug: 'vidio'),
    SakuIconEntry(id: 'prime_video', label: 'Prime Video', group: SakuIconGroup.subscription, fallback: Icons.ondemand_video_rounded, brandSlug: 'prime-video'),
    SakuIconEntry(id: 'canva', label: 'Canva', group: SakuIconGroup.subscription, fallback: Icons.brush_rounded, brandSlug: 'canva'),
    SakuIconEntry(id: 'capcut', label: 'CapCut', group: SakuIconGroup.subscription, fallback: Icons.video_camera_back_rounded, brandSlug: 'capcut'),
    SakuIconEntry(id: 'zoom', label: 'Zoom', group: SakuIconGroup.subscription, fallback: Icons.video_call_rounded, brandSlug: 'zoom'),
    SakuIconEntry(id: 'google_one', label: 'Google One', group: SakuIconGroup.subscription, fallback: Icons.cloud_rounded, brandSlug: 'google-one'),
    SakuIconEntry(id: 'icloud', label: 'iCloud', group: SakuIconGroup.subscription, fallback: Icons.cloud_rounded, brandSlug: 'icloud'),
    SakuIconEntry(id: 'microsoft_365', label: 'Microsoft 365', group: SakuIconGroup.subscription, fallback: Icons.workspaces_rounded, brandSlug: 'microsoft-365'),
    SakuIconEntry(id: 'adobe', label: 'Adobe', group: SakuIconGroup.subscription, fallback: Icons.draw_rounded, brandSlug: 'adobe'),
    SakuIconEntry(id: 'notion', label: 'Notion', group: SakuIconGroup.subscription, fallback: Icons.description_rounded, brandSlug: 'notion'),

    // F — AI tools.
    SakuIconEntry(id: 'chatgpt', label: 'ChatGPT', group: SakuIconGroup.ai, fallback: Icons.auto_awesome_rounded, brandSlug: 'chatgpt'),
    SakuIconEntry(id: 'gemini', label: 'Gemini', group: SakuIconGroup.ai, fallback: Icons.auto_awesome_rounded, brandSlug: 'gemini'),
    SakuIconEntry(id: 'claude', label: 'Claude', group: SakuIconGroup.ai, fallback: Icons.psychology_alt_rounded, brandSlug: 'claude'),
    SakuIconEntry(id: 'perplexity', label: 'Perplexity', group: SakuIconGroup.ai, fallback: Icons.travel_explore_rounded, brandSlug: 'perplexity'),
    SakuIconEntry(id: 'midjourney', label: 'Midjourney', group: SakuIconGroup.ai, fallback: Icons.image_rounded, brandSlug: 'midjourney'),
    SakuIconEntry(id: 'github_copilot', label: 'GitHub Copilot', group: SakuIconGroup.ai, fallback: Icons.code_rounded, brandSlug: 'github-copilot'),
    SakuIconEntry(id: 'grok', label: 'Grok', group: SakuIconGroup.ai, fallback: Icons.auto_awesome_rounded, brandSlug: 'grok'),
    SakuIconEntry(id: 'cursor', label: 'Cursor', group: SakuIconGroup.ai, fallback: Icons.code_rounded, brandSlug: 'cursor'),
    SakuIconEntry(id: 'openrouter', label: 'OpenRouter', group: SakuIconGroup.ai, fallback: Icons.route_rounded, brandSlug: 'openrouter'),
    SakuIconEntry(id: 'deepseek', label: 'DeepSeek', group: SakuIconGroup.ai, fallback: Icons.psychology_rounded, brandSlug: 'deepseek'),

    // G — Telco / internet.
    SakuIconEntry(id: 'telkomsel', label: 'Telkomsel', group: SakuIconGroup.telco, fallback: Icons.cell_tower_rounded, brandSlug: 'telkomsel'),
    SakuIconEntry(id: 'byu', label: 'by.U', group: SakuIconGroup.telco, fallback: Icons.sim_card_rounded, brandSlug: 'byu'),
    SakuIconEntry(id: 'im3', label: 'IM3', group: SakuIconGroup.telco, fallback: Icons.sim_card_rounded, brandSlug: 'im3'),
    SakuIconEntry(id: 'xl', label: 'XL Axiata', group: SakuIconGroup.telco, fallback: Icons.sim_card_rounded, brandSlug: 'xl-axiata'),
    SakuIconEntry(id: 'axis', label: 'AXIS', group: SakuIconGroup.telco, fallback: Icons.sim_card_rounded, brandSlug: 'axis'),
    SakuIconEntry(id: 'smartfren', label: 'Smartfren', group: SakuIconGroup.telco, fallback: Icons.sim_card_rounded, brandSlug: 'smartfren'),
    SakuIconEntry(id: 'tri', label: 'Tri / 3', group: SakuIconGroup.telco, fallback: Icons.sim_card_rounded, brandSlug: 'tri'),
    SakuIconEntry(id: 'first_media', label: 'First Media', group: SakuIconGroup.telco, fallback: Icons.router_rounded, brandSlug: 'first-media'),
    SakuIconEntry(id: 'indihome', label: 'IndiHome', group: SakuIconGroup.telco, fallback: Icons.router_rounded, brandSlug: 'indihome'),
    SakuIconEntry(id: 'biznet', label: 'Biznet', group: SakuIconGroup.telco, fallback: Icons.router_rounded, brandSlug: 'biznet'),
    SakuIconEntry(id: 'myrepublic', label: 'MyRepublic', group: SakuIconGroup.telco, fallback: Icons.router_rounded, brandSlug: 'myrepublic'),

    // H — Utilities / bills.
    SakuIconEntry(id: 'pln', label: 'PLN', group: SakuIconGroup.utility, fallback: Icons.bolt_rounded, brandSlug: 'pln'),
    SakuIconEntry(id: 'pdam', label: 'PDAM', group: SakuIconGroup.utility, fallback: Icons.water_drop_rounded, brandSlug: 'pdam'),
    SakuIconEntry(id: 'bpjs', label: 'BPJS', group: SakuIconGroup.utility, fallback: Icons.health_and_safety_rounded, brandSlug: 'bpjs'),
    SakuIconEntry(id: 'pbb', label: 'PBB', group: SakuIconGroup.utility, fallback: Icons.receipt_long_rounded),
    SakuIconEntry(id: 'vehicle_tax', label: 'Pajak kendaraan', group: SakuIconGroup.utility, fallback: Icons.directions_car_rounded),
    SakuIconEntry(id: 'home_internet', label: 'Internet rumah', group: SakuIconGroup.utility, fallback: Icons.wifi_rounded),
    SakuIconEntry(id: 'electricity', label: 'Listrik', group: SakuIconGroup.utility, fallback: Icons.electric_bolt_rounded),
    SakuIconEntry(id: 'water', label: 'Air', group: SakuIconGroup.utility, fallback: Icons.water_drop_rounded),
    SakuIconEntry(id: 'gas', label: 'Gas', group: SakuIconGroup.utility, fallback: Icons.local_fire_department_rounded),
    SakuIconEntry(id: 'installment', label: 'Cicilan', group: SakuIconGroup.utility, fallback: Icons.payments_rounded),

    // I — Generic internal icons.
    SakuIconEntry(id: 'cash', label: 'Tunai', group: SakuIconGroup.generic, fallback: Icons.payments_rounded),
    SakuIconEntry(id: 'bank_account', label: 'Rekening bank', group: SakuIconGroup.generic, fallback: Icons.account_balance_rounded),
    SakuIconEntry(id: 'digital_wallet', label: 'Dompet digital', group: SakuIconGroup.generic, fallback: Icons.account_balance_wallet_rounded),
    SakuIconEntry(id: 'credit_card', label: 'Kartu kredit', group: SakuIconGroup.generic, fallback: Icons.credit_card_rounded),
    SakuIconEntry(id: 'loan', label: 'Pinjaman', group: SakuIconGroup.generic, fallback: Icons.request_quote_rounded),
    SakuIconEntry(id: 'savings', label: 'Tabungan', group: SakuIconGroup.generic, fallback: Icons.savings_rounded),
    SakuIconEntry(id: 'investment', label: 'Investasi', group: SakuIconGroup.generic, fallback: Icons.trending_up_rounded),
    SakuIconEntry(id: 'salary', label: 'Gaji', group: SakuIconGroup.generic, fallback: Icons.work_rounded),
    SakuIconEntry(id: 'bonus', label: 'Bonus', group: SakuIconGroup.generic, fallback: Icons.card_giftcard_rounded),
    SakuIconEntry(id: 'food', label: 'Makanan', group: SakuIconGroup.generic, fallback: Icons.restaurant_rounded),
    SakuIconEntry(id: 'drink', label: 'Minuman', group: SakuIconGroup.generic, fallback: Icons.local_cafe_rounded),
    SakuIconEntry(id: 'transport', label: 'Transport', group: SakuIconGroup.generic, fallback: Icons.directions_car_rounded),
    SakuIconEntry(id: 'shopping', label: 'Belanja', group: SakuIconGroup.generic, fallback: Icons.shopping_bag_rounded),
    SakuIconEntry(id: 'health', label: 'Kesehatan', group: SakuIconGroup.generic, fallback: Icons.favorite_rounded),
    SakuIconEntry(id: 'education', label: 'Pendidikan', group: SakuIconGroup.generic, fallback: Icons.school_rounded),
    SakuIconEntry(id: 'entertainment', label: 'Hiburan', group: SakuIconGroup.generic, fallback: Icons.sports_esports_rounded),
    SakuIconEntry(id: 'household', label: 'Rumah tangga', group: SakuIconGroup.generic, fallback: Icons.home_rounded),
    SakuIconEntry(id: 'business', label: 'Bisnis', group: SakuIconGroup.generic, fallback: Icons.business_center_rounded),
    SakuIconEntry(id: 'gift', label: 'Hadiah', group: SakuIconGroup.generic, fallback: Icons.card_giftcard_rounded),
    SakuIconEntry(id: 'donation', label: 'Donasi', group: SakuIconGroup.generic, fallback: Icons.volunteer_activism_rounded),
    SakuIconEntry(id: 'subscription', label: 'Langganan', group: SakuIconGroup.generic, fallback: Icons.subscriptions_rounded),
    SakuIconEntry(id: 'bill', label: 'Tagihan', group: SakuIconGroup.generic, fallback: Icons.receipt_long_rounded),
    SakuIconEntry(id: 'topup', label: 'Top up', group: SakuIconGroup.generic, fallback: Icons.add_card_rounded),
    SakuIconEntry(id: 'transfer', label: 'Transfer', group: SakuIconGroup.generic, fallback: Icons.swap_horiz_rounded),
    SakuIconEntry(id: 'refund', label: 'Refund', group: SakuIconGroup.generic, fallback: Icons.undo_rounded),
    SakuIconEntry(id: 'tax', label: 'Pajak', group: SakuIconGroup.generic, fallback: Icons.receipt_rounded),
    SakuIconEntry(id: 'other', label: 'Lainnya', group: SakuIconGroup.generic, fallback: Icons.category_rounded),
  ];

  static SakuIconEntry? byId(String id) {
    for (final entry in all) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static List<SakuIconEntry> search(String query) {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return all;
    return all.where((entry) {
      return entry.label.toLowerCase().contains(value) ||
          entry.id.contains(value) ||
          entry.keywords.any((keyword) => keyword.toLowerCase().contains(value));
    }).toList(growable: false);
  }
}
