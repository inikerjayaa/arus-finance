import 'package:flutter/material.dart';

enum IconCatalogGroup {
  finance,
  bank,
  wallet,
  subscription,
  food,
  shopping,
  transport,
  home,
  health,
  lifestyle,
  other,
}

class IconCatalogEntry {
  const IconCatalogEntry({
    required this.key,
    required this.label,
    required this.group,
    required this.fallbackIcon,
    this.aliases = const [],
    this.assetPath,
    this.isBrand = false,
  });

  final String key;
  final String label;
  final IconCatalogGroup group;
  final IconData fallbackIcon;
  final List<String> aliases;

  /// Optional local bundled asset for a brand/logo. Null means Arus uses the
  /// Material fallback icon. Keeping the stable key separate from the asset
  /// lets us replace artwork later without rewriting financial history.
  final String? assetPath;
  final bool isBrand;
}

class IconCatalog {
  const IconCatalog._();

  static const entries = <IconCatalogEntry>[
    // Finance primitives.
    IconCatalogEntry(key: 'finance.cash', label: 'Cash', group: IconCatalogGroup.finance, fallbackIcon: Icons.payments_rounded, aliases: ['tunai', 'uang tunai']),
    IconCatalogEntry(key: 'finance.wallet', label: 'Dompet', group: IconCatalogGroup.finance, fallbackIcon: Icons.account_balance_wallet_rounded, aliases: ['wallet', 'dompet']),
    IconCatalogEntry(key: 'finance.bank', label: 'Bank', group: IconCatalogGroup.finance, fallbackIcon: Icons.account_balance_rounded, aliases: ['rekening']),
    IconCatalogEntry(key: 'finance.transfer', label: 'Transfer', group: IconCatalogGroup.finance, fallbackIcon: Icons.swap_horiz_rounded, aliases: ['kirim uang', 'transfer bank']),
    IconCatalogEntry(key: 'finance.qris', label: 'QRIS', group: IconCatalogGroup.finance, fallbackIcon: Icons.qr_code_2_rounded, aliases: ['qr', 'qr payment']),
    IconCatalogEntry(key: 'finance.credit_card', label: 'Kartu kredit', group: IconCatalogGroup.finance, fallbackIcon: Icons.credit_card_rounded, aliases: ['credit card', 'kartu']),
    IconCatalogEntry(key: 'finance.savings', label: 'Tabungan', group: IconCatalogGroup.finance, fallbackIcon: Icons.savings_rounded, aliases: ['saving', 'simpanan']),
    IconCatalogEntry(key: 'finance.investment', label: 'Investasi', group: IconCatalogGroup.finance, fallbackIcon: Icons.trending_up_rounded, aliases: ['investment', 'saham', 'reksadana']),
    IconCatalogEntry(key: 'finance.loan', label: 'Pinjaman', group: IconCatalogGroup.finance, fallbackIcon: Icons.request_quote_rounded, aliases: ['loan', 'utang', 'hutang', 'cicilan']),
    IconCatalogEntry(key: 'finance.salary', label: 'Gaji', group: IconCatalogGroup.finance, fallbackIcon: Icons.work_rounded, aliases: ['salary', 'payroll', 'upah']),
    IconCatalogEntry(key: 'finance.bonus', label: 'Bonus', group: IconCatalogGroup.finance, fallbackIcon: Icons.redeem_rounded, aliases: ['insentif']),
    IconCatalogEntry(key: 'finance.refund', label: 'Refund', group: IconCatalogGroup.finance, fallbackIcon: Icons.currency_exchange_rounded, aliases: ['pengembalian', 'uang kembali']),
    IconCatalogEntry(key: 'finance.fee', label: 'Biaya', group: IconCatalogGroup.finance, fallbackIcon: Icons.receipt_long_rounded, aliases: ['fee', 'admin', 'biaya transfer']),

    // Indonesian banks. Brand assets can be bundled later after asset/legal review.
    IconCatalogEntry(key: 'bank.bca', label: 'BCA', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['bank central asia'], isBrand: true),
    IconCatalogEntry(key: 'bank.mandiri', label: 'Bank Mandiri', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['mandiri'], isBrand: true),
    IconCatalogEntry(key: 'bank.bri', label: 'BRI', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['bank rakyat indonesia'], isBrand: true),
    IconCatalogEntry(key: 'bank.bni', label: 'BNI', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['bank negara indonesia'], isBrand: true),
    IconCatalogEntry(key: 'bank.bsi', label: 'BSI', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['bank syariah indonesia'], isBrand: true),
    IconCatalogEntry(key: 'bank.bjb', label: 'Bank BJB', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['bjb', 'bank jawa barat banten'], isBrand: true),
    IconCatalogEntry(key: 'bank.ocbc', label: 'OCBC', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['ocbc nisp', 'nisp'], isBrand: true),
    IconCatalogEntry(key: 'bank.maybank', label: 'Maybank', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['mybank', 'may bank'], isBrand: true),
    IconCatalogEntry(key: 'bank.cimb_niaga', label: 'CIMB Niaga', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['cimb'], isBrand: true),
    IconCatalogEntry(key: 'bank.permata', label: 'PermataBank', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['permata'], isBrand: true),
    IconCatalogEntry(key: 'bank.danamon', label: 'Danamon', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['bank danamon'], isBrand: true),
    IconCatalogEntry(key: 'bank.jago', label: 'Bank Jago', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['jago'], isBrand: true),
    IconCatalogEntry(key: 'bank.seabank', label: 'SeaBank', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['sea bank'], isBrand: true),
    IconCatalogEntry(key: 'bank.blu', label: 'blu by BCA Digital', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['blu', 'bca digital'], isBrand: true),
    IconCatalogEntry(key: 'bank.btn', label: 'BTN', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['bank tabungan negara'], isBrand: true),
    IconCatalogEntry(key: 'bank.mega', label: 'Bank Mega', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['mega'], isBrand: true),
    IconCatalogEntry(key: 'bank.panin', label: 'PaninBank', group: IconCatalogGroup.bank, fallbackIcon: Icons.account_balance_rounded, aliases: ['panin'], isBrand: true),

    // Wallets and payment services.
    IconCatalogEntry(key: 'wallet.gojek', label: 'Gojek', group: IconCatalogGroup.wallet, fallbackIcon: Icons.two_wheeler_rounded, aliases: ['go-jek'], isBrand: true),
    IconCatalogEntry(key: 'wallet.gopay', label: 'GoPay', group: IconCatalogGroup.wallet, fallbackIcon: Icons.account_balance_wallet_rounded, aliases: ['go pay', 'gojek pay'], isBrand: true),
    IconCatalogEntry(key: 'wallet.dana', label: 'DANA', group: IconCatalogGroup.wallet, fallbackIcon: Icons.account_balance_wallet_rounded, aliases: ['dana wallet'], isBrand: true),
    IconCatalogEntry(key: 'wallet.ovo', label: 'OVO', group: IconCatalogGroup.wallet, fallbackIcon: Icons.account_balance_wallet_rounded, aliases: ['ovo cash'], isBrand: true),
    IconCatalogEntry(key: 'wallet.shopeepay', label: 'ShopeePay', group: IconCatalogGroup.wallet, fallbackIcon: Icons.account_balance_wallet_rounded, aliases: ['shopee pay'], isBrand: true),
    IconCatalogEntry(key: 'wallet.linkaja', label: 'LinkAja', group: IconCatalogGroup.wallet, fallbackIcon: Icons.account_balance_wallet_rounded, aliases: ['link aja'], isBrand: true),

    // Subscriptions/services.
    IconCatalogEntry(key: 'subscription.netflix', label: 'Netflix', group: IconCatalogGroup.subscription, fallbackIcon: Icons.movie_rounded, aliases: ['film', 'streaming'], isBrand: true),
    IconCatalogEntry(key: 'subscription.chatgpt', label: 'ChatGPT', group: IconCatalogGroup.subscription, fallbackIcon: Icons.auto_awesome_rounded, aliases: ['openai', 'chat gpt', 'ai'], isBrand: true),
    IconCatalogEntry(key: 'subscription.spotify', label: 'Spotify', group: IconCatalogGroup.subscription, fallbackIcon: Icons.music_note_rounded, aliases: ['music', 'musik'], isBrand: true),
    IconCatalogEntry(key: 'subscription.youtube', label: 'YouTube', group: IconCatalogGroup.subscription, fallbackIcon: Icons.smart_display_rounded, aliases: ['youtube premium', 'yt'], isBrand: true),
    IconCatalogEntry(key: 'subscription.disney', label: 'Disney+', group: IconCatalogGroup.subscription, fallbackIcon: Icons.movie_filter_rounded, aliases: ['disney plus', 'hotstar'], isBrand: true),
    IconCatalogEntry(key: 'subscription.apple', label: 'Apple', group: IconCatalogGroup.subscription, fallbackIcon: Icons.apple_rounded, aliases: ['icloud', 'apple one', 'app store'], isBrand: true),
    IconCatalogEntry(key: 'subscription.google', label: 'Google', group: IconCatalogGroup.subscription, fallbackIcon: Icons.cloud_rounded, aliases: ['google one', 'google drive'], isBrand: true),
    IconCatalogEntry(key: 'subscription.microsoft', label: 'Microsoft', group: IconCatalogGroup.subscription, fallbackIcon: Icons.window_rounded, aliases: ['office 365', 'microsoft 365'], isBrand: true),
    IconCatalogEntry(key: 'subscription.canva', label: 'Canva', group: IconCatalogGroup.subscription, fallbackIcon: Icons.brush_rounded, aliases: ['design'], isBrand: true),

    // Everyday categories.
    IconCatalogEntry(key: 'food.meal', label: 'Makanan', group: IconCatalogGroup.food, fallbackIcon: Icons.restaurant_rounded, aliases: ['makan', 'food', 'kuliner']),
    IconCatalogEntry(key: 'food.drink', label: 'Minuman', group: IconCatalogGroup.food, fallbackIcon: Icons.local_drink_rounded, aliases: ['drink', 'beverage']),
    IconCatalogEntry(key: 'food.coffee', label: 'Kopi', group: IconCatalogGroup.food, fallbackIcon: Icons.local_cafe_rounded, aliases: ['coffee', 'cafe']),
    IconCatalogEntry(key: 'food.groceries', label: 'Belanja bahan makanan', group: IconCatalogGroup.food, fallbackIcon: Icons.local_grocery_store_rounded, aliases: ['groceries', 'sembako', 'supermarket']),
    IconCatalogEntry(key: 'shopping.cart', label: 'Belanja', group: IconCatalogGroup.shopping, fallbackIcon: Icons.shopping_bag_rounded, aliases: ['shopping', 'belanja umum']),
    IconCatalogEntry(key: 'shopping.clothes', label: 'Baju', group: IconCatalogGroup.shopping, fallbackIcon: Icons.checkroom_rounded, aliases: ['pakaian', 'clothes', 'fashion']),
    IconCatalogEntry(key: 'shopping.shoes', label: 'Sepatu', group: IconCatalogGroup.shopping, fallbackIcon: Icons.hiking_rounded, aliases: ['shoes', 'sneaker', 'sandal']),
    IconCatalogEntry(key: 'home.house', label: 'Rumah', group: IconCatalogGroup.home, fallbackIcon: Icons.home_rounded, aliases: ['home', 'kost', 'kontrakan']),
    IconCatalogEntry(key: 'home.utilities', label: 'Tagihan rumah', group: IconCatalogGroup.home, fallbackIcon: Icons.receipt_long_rounded, aliases: ['utilities', 'tagihan']),
    IconCatalogEntry(key: 'home.electricity', label: 'Listrik', group: IconCatalogGroup.home, fallbackIcon: Icons.bolt_rounded, aliases: ['pln', 'electricity']),
    IconCatalogEntry(key: 'home.internet', label: 'Internet', group: IconCatalogGroup.home, fallbackIcon: Icons.wifi_rounded, aliases: ['wifi', 'broadband']),
    IconCatalogEntry(key: 'home.phone', label: 'Pulsa & telepon', group: IconCatalogGroup.home, fallbackIcon: Icons.smartphone_rounded, aliases: ['pulsa', 'data', 'telepon', 'phone']),
    IconCatalogEntry(key: 'health.medical', label: 'Kesehatan', group: IconCatalogGroup.health, fallbackIcon: Icons.health_and_safety_rounded, aliases: ['health', 'dokter', 'klinik']),
    IconCatalogEntry(key: 'health.pharmacy', label: 'Obat', group: IconCatalogGroup.health, fallbackIcon: Icons.medication_rounded, aliases: ['pharmacy', 'apotik', 'apotek']),
    IconCatalogEntry(key: 'transport.general', label: 'Transport', group: IconCatalogGroup.transport, fallbackIcon: Icons.directions_transit_rounded, aliases: ['transportasi', 'commute']),
    IconCatalogEntry(key: 'transport.car', label: 'Mobil', group: IconCatalogGroup.transport, fallbackIcon: Icons.directions_car_rounded, aliases: ['car', 'kendaraan']),
    IconCatalogEntry(key: 'transport.motorbike', label: 'Motor', group: IconCatalogGroup.transport, fallbackIcon: Icons.two_wheeler_rounded, aliases: ['motorbike', 'motorcycle']),
    IconCatalogEntry(key: 'transport.fuel', label: 'Bensin', group: IconCatalogGroup.transport, fallbackIcon: Icons.local_gas_station_rounded, aliases: ['bbm', 'fuel', 'pertalite', 'pertamax']),
    IconCatalogEntry(key: 'transport.parking', label: 'Parkir', group: IconCatalogGroup.transport, fallbackIcon: Icons.local_parking_rounded, aliases: ['parking']),
    IconCatalogEntry(key: 'lifestyle.travel', label: 'Travel', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.luggage_rounded, aliases: ['liburan', 'vacation', 'trip']),
    IconCatalogEntry(key: 'lifestyle.hotel', label: 'Hotel', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.hotel_rounded, aliases: ['penginapan', 'akomodasi']),
    IconCatalogEntry(key: 'lifestyle.flight', label: 'Pesawat', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.flight_rounded, aliases: ['flight', 'airline', 'tiket pesawat']),
    IconCatalogEntry(key: 'lifestyle.education', label: 'Pendidikan', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.school_rounded, aliases: ['education', 'sekolah', 'kuliah', 'kursus']),
    IconCatalogEntry(key: 'lifestyle.gift', label: 'Hadiah', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.card_giftcard_rounded, aliases: ['gift', 'kado']),
    IconCatalogEntry(key: 'lifestyle.entertainment', label: 'Hiburan', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.theater_comedy_rounded, aliases: ['entertainment', 'nonton']),
    IconCatalogEntry(key: 'lifestyle.game', label: 'Game', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.sports_esports_rounded, aliases: ['gaming']),
    IconCatalogEntry(key: 'lifestyle.sport', label: 'Olahraga', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.fitness_center_rounded, aliases: ['sport', 'gym', 'fitness']),
    IconCatalogEntry(key: 'lifestyle.pet', label: 'Hewan peliharaan', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.pets_rounded, aliases: ['pet', 'kucing', 'anjing']),
    IconCatalogEntry(key: 'lifestyle.beauty', label: 'Perawatan & beauty', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.spa_rounded, aliases: ['beauty', 'salon', 'skincare']),
    IconCatalogEntry(key: 'finance.tax', label: 'Pajak', group: IconCatalogGroup.finance, fallbackIcon: Icons.account_balance_rounded, aliases: ['tax']),
    IconCatalogEntry(key: 'finance.insurance', label: 'Asuransi', group: IconCatalogGroup.finance, fallbackIcon: Icons.verified_user_rounded, aliases: ['insurance']),
    IconCatalogEntry(key: 'lifestyle.charity', label: 'Donasi', group: IconCatalogGroup.lifestyle, fallbackIcon: Icons.volunteer_activism_rounded, aliases: ['charity', 'sedekah']),
    IconCatalogEntry(key: 'other.category', label: 'Lainnya', group: IconCatalogGroup.other, fallbackIcon: Icons.category_rounded, aliases: ['other', 'lain lain']),
  ];

  static final Map<String, IconCatalogEntry> _byKey = {
    for (final entry in entries) entry.key: entry,
  };

  static IconCatalogEntry? byKey(String? key) => key == null ? null : _byKey[key];

  static IconCatalogEntry fallbackFor(String? key) =>
      byKey(key) ?? byKey('other.category')!;

  static List<IconCatalogEntry> search(
    String query, {
    IconCatalogGroup? group,
    int limit = 40,
  }) {
    if (limit <= 0) return const [];
    final normalizedQuery = _normalize(query);
    final candidates = entries.where((entry) => group == null || entry.group == group);
    if (normalizedQuery.isEmpty) return candidates.take(limit).toList(growable: false);

    final ranked = <({IconCatalogEntry entry, int score})>[];
    for (final entry in candidates) {
      final label = _normalize(entry.label);
      final key = _normalize(entry.key.replaceAll('.', ' '));
      final aliases = entry.aliases.map(_normalize);
      var score = -1;
      if (label == normalizedQuery || key == normalizedQuery) {
        score = 100;
      } else if (aliases.any((value) => value == normalizedQuery)) {
        score = 95;
      } else if (label.startsWith(normalizedQuery)) {
        score = 80;
      } else if (aliases.any((value) => value.startsWith(normalizedQuery))) {
        score = 75;
      } else if (label.contains(normalizedQuery) || key.contains(normalizedQuery)) {
        score = 60;
      } else if (aliases.any((value) => value.contains(normalizedQuery))) {
        score = 55;
      }
      if (score >= 0) ranked.add((entry: entry, score: score));
    }
    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.entry.label.toLowerCase().compareTo(b.entry.label.toLowerCase());
    });
    return ranked.take(limit).map((row) => row.entry).toList(growable: false);
  }

  static IconCatalogEntry suggest(String name, {IconCatalogGroup? group}) {
    final results = search(name, group: group, limit: 1);
    return results.isEmpty ? fallbackFor(null) : results.first;
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
