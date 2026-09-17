# SAKU Design System — V32

Status: LOCKED DIRECTION / IMPLEMENTATION IN PROGRESS

## Brand

- Product name: **SAKU**.
- Primary logo direction: hand entering a pocket, Design 4.
- Primary dark background: **NOTURNO `#001621`**.
- Primary accent: **VULCANICO `#FF4103`**.
- Light neutral/base: **SAND `#F0EDE4`**.
- Primary wordmark on dark: white/off-white.
- Public tagline is intentionally omitted from the current logo lockup.

The app remains local-first/device-owned. Branding, fonts, icons, and user custom assets must not create a runtime network dependency.

## Typography

Primary family: **Plus Jakarta Sans**.

Usage:
- display / app identity: Bold or ExtraBold;
- page title: Bold;
- section title: SemiBold;
- body: Regular;
- labels / controls: Medium;
- buttons: SemiBold;
- captions: Regular.

The font must be bundled locally. Runtime fetching from Google Fonts or another CDN is prohibited.

## Shape language

- controls: 16dp corner radius;
- cards: 22dp corner radius;
- touch targets: minimum 48x48dp;
- geometry: rounded, friendly, uncluttered;
- visual density: light; financial information remains dominant over decoration.

## Splash / cold-start contract

The SAKU brand splash is a launch transition, not a normal application page.

- show on a true cold app launch while native/application initialization starts;
- do not replay after navigation to dashboard;
- do not replay on normal background -> resume;
- do not replace PIN/biometric locking behavior;
- never expose finance content while initialization/security gates are unresolved.

Visual direction: NOTURNO full-screen background, centered Design-4 pocket/hand mark, white `SAKU`, no tagline.

## Icon system

Priority order:
1. user custom icon;
2. vetted bundled brand icon;
3. generic local fallback icon.

All icons must resolve locally at runtime. Missing brand assets must fall back gracefully instead of downloading remotely.

### A — Banks / digital banks
BCA, Mandiri, BRI, BNI, BTN, BSI, CIMB Niaga, PermataBank, Danamon, OCBC, Maybank Indonesia, Panin, Bank Mega, Bank Jago, SeaBank, blu, neobank, UOB, HSBC, Standard Chartered, Bank Sinarmas, KB Bank, Bank Muamalat, Allo Bank, Bank Raya, Jenius, digibank by DBS, LINE Bank, Bank Saqu.

### B — E-wallet / payment
DANA, OVO, GoPay, ShopeePay, LinkAja, i.Saku, Sakuku, AstraPay, PayPal, QRIS.

### C — Transport / travel
Gojek, Grab, Maxim, inDrive, Traveloka, tiket.com.

### D — Marketplace
Tokopedia, Shopee, Lazada, Blibli, Bukalapak, TikTok Shop.

### E — Subscription / digital services
YouTube, YouTube Premium, Netflix, Spotify, Disney+, Vidio, Prime Video, Canva, CapCut, Zoom, Google One, iCloud, Microsoft 365, Adobe, Notion.

### F — AI tools
ChatGPT, Gemini, Claude, Perplexity, Midjourney, GitHub Copilot, Grok, Cursor, OpenRouter, DeepSeek.

### G — Telco / internet
Telkomsel, by.U, IM3, XL, AXIS, Smartfren, Tri, First Media, IndiHome, Biznet, MyRepublic.

### H — Utilities
PLN, PDAM, BPJS, PBB, Pajak Kendaraan, Internet Rumah, Listrik, Air, Gas, Cicilan.

### I — Generic
Tunai, Rekening Bank, Dompet Digital, Kartu Kredit, Pinjaman, Tabungan, Investasi, Gaji, Bonus, Makanan, Minuman, Transport, Belanja, Kesehatan, Pendidikan, Hiburan, Rumah Tangga, Bisnis, Hadiah, Donasi, Langganan, Tagihan, Top Up, Transfer, Refund, Pajak, Lainnya.

## Custom icon contract

User-owned custom icons are a first-class feature.

Target assignments:
- account;
- category;
- merchant;
- subscription;
- recurring bill/service.

Rules:
- imported from device-local user storage/gallery;
- copied into SAKU-owned application storage before use;
- original file path is not treated as durable identity;
- safe size/type validation before persistence;
- crop/preview/reset flow;
- custom asset remains local;
- custom assets must be included in portable backup/restore before the feature is considered complete;
- deleting a custom icon must not delete the financial entity it decorated;
- loss/corruption of an optional icon must degrade to a generic fallback, never block access to finance data.

## Trademark / brand asset rule

Brand names are used for user-recognition and local classification. Bundled third-party logos must be individually vetted for acceptable distribution/trademark usage. If an asset cannot be safely bundled, SAKU uses a neutral generic icon and still allows the user to assign a personal custom image locally.

## Deferred final-polish items

The exact spacing, typography scale, micro-animation, icon sizing, dashboard restyling, light/dark visual audit, and small-screen overflow pass remain in the dedicated pre-release UI/UX polish stage. Functional/security/data behavior must not be weakened for visual reasons.
