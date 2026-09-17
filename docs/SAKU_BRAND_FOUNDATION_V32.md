# SAKU — Brand Foundation V32

Status: **LOCKED for implementation**, with individual third-party brand artwork still subject to exact-asset review.

## Product name

Public product name: **SAKU**.

The internal repository/package/class history may still contain `arus` identifiers during migration. Renaming technical identifiers is not allowed to break upgrade compatibility, signing, local storage, or existing user data.

## Core palette

- **NOTURNO** `#001621` — primary dark background / privacy surface.
- **VULCANICO** `#FF4103` — primary brand accent.
- **SAND** `#F0EDE4` — primary light background.
- White — high-contrast wordmark/content on Noturno.

The approved logo direction is the hand-in-pocket Design 4: orange pocket, white sleeve, warm skin tone, SAKU wordmark, and Noturno background.

## Typography

Primary UI family: **Plus Jakarta Sans**.

SAKU bundles the font into the application. Runtime typography must not depend on Google Fonts, a CDN, or any network request. Build tooling pins the upstream font source and verifies the expected Git blob identity before Flutter bundles it.

## Launch splash contract

The SAKU launch splash is a cold-launch transition:

1. Solid NOTURNO background.
2. Approved SAKU pocket/hand mark.
3. White `SAKU` wordmark.
4. No tagline.
5. Shown while cold-launch initialization is completing, with only a small minimum presentation time to avoid visual flashing.
6. It must **not replay** merely because the app went to background and resumed while the process is still alive.
7. The splash is static and non-sensitive. Once it leaves, the existing root lock/privacy protection remains responsible for financial UI.

## Icon system

Stable icon keys are separated from artwork. Financial history stores a stable key; artwork can be improved later without rewriting transaction/account history.

The agreed catalog covers all of these groups:

### A — Indonesian banks
BCA, Mandiri, BRI, BNI, BTN, BSI, CIMB Niaga, PermataBank, Danamon, OCBC, Maybank Indonesia, PaninBank, Bank Mega, Bank Jago, SeaBank, blu by BCA Digital, neobank/BNC, UOB Indonesia, HSBC Indonesia, Standard Chartered, Bank Sinarmas, KB Bank/Bukopin, Bank Muamalat, Allo Bank, Bank Raya, Jenius, digibank by DBS, LINE Bank, Bank Saqu, MotionBanking.

### B — E-wallet/payment
DANA, OVO, GoPay, ShopeePay, LinkAja, i.saku, Sakuku, AstraPay, PayPal, QRIS.

### C — Transport/travel
Gojek, Grab, Maxim, inDrive, Traveloka, Tiket.com.

### D — Marketplace
Tokopedia, Shopee, Lazada, Blibli, Bukalapak, TikTok Shop.

### E — Subscription/media/productivity
YouTube, YouTube Premium, Netflix, Spotify, Disney+, Vidio, Prime Video, Canva, CapCut, Zoom, Google One, iCloud, Microsoft 365, Adobe, Notion.

### F — AI
ChatGPT, Gemini, Claude, Perplexity, Midjourney, GitHub Copilot, Grok, Cursor, OpenRouter, DeepSeek.

### G — Telco/internet
Telkomsel, by.U, IM3, XL Axiata, AXIS, Smartfren, Tri, First Media, IndiHome, Biznet, MyRepublic.

### H — Utilities
PLN, PDAM, BPJS, PBB, pajak kendaraan, internet rumah, listrik, air, gas, cicilan.

### I — Generic SAKU icons
Tunai, rekening bank, dompet digital, kartu kredit, pinjaman, tabungan, investasi, gaji, bonus, makanan, minuman, transport, belanja, kesehatan, pendidikan, hiburan, rumah tangga, bisnis/keuangan, hadiah, donasi, langganan, tagihan, top-up/QR, transfer, refund, pajak, dan lainnya.

## Original third-party logos

Brand entries are marked separately from generic SAKU icons. Exact third-party logos must be bundled locally only after the artwork source and usage are reviewed. Until an exact bundled asset is approved, SAKU must show a neutral generic fallback rather than fabricate or approximate an official logo.

SAKU does not require network access to fetch a logo at runtime.

## Custom icon contract

Users can choose a custom local image for an account/category visual identity.

- Accepted input: PNG, JPG/JPEG, WEBP.
- Stored locally only.
- Encoded into the existing visual identity data rather than saved as a fragile absolute filesystem path.
- Therefore it survives SAKU portable backup/restore together with the account/category row.
- Invalid/oversized custom data fails closed and falls back safely.
- User custom assets never become a mandatory external/cloud dependency.

## Local-first invariant

Branding changes must not modify the core rule: primary financial data is device-owned. SAKU remains usable without an account, login, server, or mandatory cloud service.
