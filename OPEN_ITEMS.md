# XamePay open items (updated Nov 2, 2026)

## Waiting on a result or a person
- Build 50 test: stale bank-transfer reference no longer blocks new transfers.
- Builds 48 and 49 tests: history symbols after a conversion; wallet-send details wording.
- Reloadly: account setup fault (their side), live credentials, wallet currency and funding, rotate 2FA key.
- Ghana airtime lookup needs working Reloadly credentials (Render log line "Intl quote failed").
- Flutterwave dashboard: check Transfers for reference xame-1793460306722461; IP allow-list; NGN balance.

## To build or fix
- Per-currency bank fee table (bank sends from non-NGN wallets blocked until it exists).
- Creator payouts credit fixed naira sums into any wallet and filter by userId (check what it does today).
- Call-credit top-up moves wallet amount one-to-one into call credits, whatever the currency.
- creditWallet and debitWallet helpers have no currency check; review their callers.
- BVN is stored in a field named bvnPlain; check use and encrypt.
- No server-side reconciler for pending airtime, data and bill purchases.
- Saved display currency CMR needs mapping to XAF.
- Virtual-account currency check runs before login; add authentication.
- Set SQUAD_BASE_URL and MONNIFY_BASE_URL explicitly (Squad VA route defaults to live, others to sandbox).
- International router corridor rates are static; quotes should read live rates.
- Cross-currency sends between XamePay users (blocked by guard until built).
- Per-currency balances for partial conversions (large change).
- Second rate partner or locked-quote FX (Flutterwave v4).

## Before real users
- Conversion switch-on: XAMEPAY_CONVERSION_ENABLED and XAMEPAY_QUOTE_SECRET, tested on a throwaway wallet.
- Compliance review (holding currencies, cross-border).
- Keep builds 42 and later off Play until the above are done.
