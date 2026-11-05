# XamePay open items (updated Nov 2, 2026)

## Waiting on a result or a person
- Bank-transfer test after f99dc88c: read the Render log line 'send-bank provider reply'.
- Build 50 test: stale bank-transfer reference no longer blocks new transfers.
- Builds 48 and 49 tests: history symbols after a conversion; wallet-send details wording.
- Reloadly: account setup fault (their side), live credentials, wallet currency and funding, rotate 2FA key.
- Ghana airtime lookup needs working Reloadly credentials (Render log line "Intl quote failed").
- Flutterwave dashboard: check Transfers for reference xame-1793460306722461; IP allow-list; NGN balance.

## Done
- Background reconciler settles pending airtime, data and bill purchases every 5 minutes, never refunding on unclear results (server 84ea8b33).
- Admin settle route verifies with Flutterwave; a transfer without a provider ID needs verifiedOutcome paid or never_sent (server 3fb960f7).
- Admin routes fail closed without ADMIN_SECRET, unauthenticated admin routes gated (server cfbda63d, 6eb5f77b, 4b24df9d).
- Outgoing transfers settle from Flutterwave's transfer.completed webhook after re-reading the transfer (server c92f7d2e); admin ledger, stuck-transfer and settle routes; 20s timeout on the transfer call.
- Bank payouts closed for non-NGN wallets and provider reply logged (server f99dc88c).
- Bank-transfer currency must match the wallet currency (server 0439eced).
- Stale bank-transfer reference check (build 50).

## To build or fix
- App lock review done. Stored hash is encrypted at rest once APP_LOCK_ENCRYPTION_KEY is set in Render (server 2a625324). Still open: the server does not check the old code when a code is replaced (needs a recent-session check); the 5-attempt limit is enforced only on the phone; setup and change screens not yet reviewed.
- Transfers that time out have no stored provider ID, so neither the webhook nor the status route can settle them; they stay unknown.
- Compare the Flutterwave webhook signature in constant time (both wallet webhook routes).
- Per-currency bank fee table (bank sends from non-NGN wallets blocked until it exists).
- Call-credit top-up moves wallet amount one-to-one into call credits, whatever the currency.
- creditWallet and debitWallet helpers have no currency check; review their callers.
- Saved display currency CMR needs mapping to XAF.
- Virtual-account currency check runs before login; add authentication.
- Set SQUAD_BASE_URL and MONNIFY_BASE_URL explicitly (Squad VA route defaults to live, others to sandbox).
- International router corridor rates are static; quotes should read live rates.
- Cross-currency sends between XamePay users (blocked by guard until built).
- Per-currency balances for partial conversions (large change).
- Second rate partner or locked-quote FX (Flutterwave v4).

## Outside the XamePay lane (assign when ready)
- Admin gate (xamepayAdminGate) covers 11 admin routes: ai-assist, delete-account, delete-announcement, delete-discovery-post, flw-bills, platform-revenue, reset-password, set-version, suspend-account, wallet-balance, wallet-credit. Remove any that break an admin tool.
- 13 admin routes use other checks and are unaudited (XameTel, official-account, a few tools).
- Manual credit route needs the admin secret (server bc8e1afd); creator payout job is paused. Check MongoDB for past use: wallets with transactions.ref starting 'manual-'.
- Creator payouts filter on userId (wallets use xameId); rebuild with a ledger if they should be paid.
- BVN encryption deployed (server 0b696574) but inactive until BVN_ENCRYPTION_KEY is set in Render; old BVNs stay plaintext until migrated.
- Android App Links lists one certificate fingerprint; add the Play app-signing one if Play installs are in use.

## Before real users
- Conversion switch-on: XAMEPAY_CONVERSION_ENABLED and XAMEPAY_QUOTE_SECRET, tested on a throwaway wallet.
- Compliance review (holding currencies, cross-border).
- Keep builds 42 and later off Play until the above are done.
