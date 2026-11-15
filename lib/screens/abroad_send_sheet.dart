// XAMEPAY_ABROAD_UI_V3: send from the wallet to a bank or mobile-money account in another country.
// Countries, banks, networks, limits and the quote all come from the server, which gets them live from the payment provider.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/auth_service.dart';

const _aTeal = Color(0xFF0FA66F);
const _aBg = Color(0xFF04231B);
const _aCard = Color(0xFF0A3327);
const _aMuted = Color(0xFF8FB5A5);
const _aGold = Color(0xFFE6C978);

String _aFlag(String cc) {
  final c = cc.toUpperCase();
  if (c.length != 2) return '';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 0x41));
}

String _aNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _AbroadArgs {
  final String serverUrl, userId, currency;
  final double balance;
  final bool pinEnabled;
  final Future<void> Function() onSuccess;
  final void Function(String) snack;
  const _AbroadArgs({required this.serverUrl, required this.userId, required this.currency,
      required this.balance, required this.pinEnabled, required this.onSuccess, required this.snack});
}

PreferredSizeWidget _aBar(String flag, String title) => AppBar(
      backgroundColor: _aCard,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: true,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        if (flag.isNotEmpty) Text(flag, style: const TextStyle(fontSize: 18)),
        if (flag.isNotEmpty) const SizedBox(width: 6),
        Flexible(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _aGold.withAlpha(110)),
      ),
    );

class AbroadSendLink extends StatefulWidget {
  final String serverUrl, userId, currency;
  final double balance;
  final bool pinEnabled;
  final Future<void> Function() onSuccess;
  final void Function(String) snack;
  const AbroadSendLink({super.key, required this.serverUrl, required this.userId,
      required this.currency, required this.balance, required this.pinEnabled,
      required this.onSuccess, required this.snack});
  @override
  State<AbroadSendLink> createState() => _AbroadSendLinkState();
}

class _AbroadSendLinkState extends State<AbroadSendLink> {
  List<Map<String, dynamic>> _dests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  _AbroadArgs get _args => _AbroadArgs(
      serverUrl: widget.serverUrl, userId: widget.userId, currency: widget.currency,
      balance: widget.balance, pinEnabled: widget.pinEnabled,
      onSuccess: widget.onSuccess, snack: widget.snack);

  Future<void> _load() async {
    try {
      final r = await http.get(
        Uri.parse('${widget.serverUrl}/api/wallet/abroad/destinations')
            .replace(queryParameters: {'userId': widget.userId}),
        headers: await AuthService().authenticatedHeaders(),
      ).timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body);
      if (!mounted) return;
      if (d is Map && d['success'] == true && d['enabled'] == true && d['destinations'] is List) {
        final list = (d['destinations'] as List)
            .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() => _dests = list);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_dests.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _AbroadCountryScreen(args: _args, dests: _dests))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: _aCard, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10)),
          child: Row(children: const [
            Text('🌍', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Send abroad', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Pay a bank or mobile money account in another country',
                  style: TextStyle(color: _aMuted, fontSize: 12)),
            ])),
            Icon(Icons.chevron_right, color: _aMuted),
          ]),
        ),
      ),
    );
  }
}

class _AbroadCountryScreen extends StatelessWidget {
  final _AbroadArgs args;
  final List<Map<String, dynamic>> dests;
  const _AbroadCountryScreen({required this.args, required this.dests});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _aBg,
      appBar: _aBar('🌍', 'Send abroad'),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: dests.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Choose the country your recipient is in',
                    style: TextStyle(color: _aMuted, fontSize: 13)));
          }
          final d = dests[i - 1];
          final t = d['types'];
          final keys = t is Map ? t.keys.map((e) => e.toString()).toList() : <String>[];
          final kinds = <String>[
            if (keys.contains('bank')) 'Bank',
            if (keys.contains('momo')) 'Mobile money',
          ];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => _AbroadBankScreen(args: args, dest: d))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                  color: _aCard, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10)),
              child: Row(children: [
                Text(_aFlag((d['country'] ?? '').toString()), style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['name']} (${d['currency']})',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  if (kinds.isNotEmpty)
                    Text(kinds.join(' · '), style: const TextStyle(color: _aMuted, fontSize: 12)),
                ])),
                const Icon(Icons.chevron_right, color: _aMuted),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _AbroadBankScreen extends StatefulWidget {
  final _AbroadArgs args;
  final Map<String, dynamic> dest;
  const _AbroadBankScreen({required this.args, required this.dest});
  @override
  State<_AbroadBankScreen> createState() => _AbroadBankScreenState();
}

class _AbroadBankScreenState extends State<_AbroadBankScreen> {
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _err;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(
        Uri.parse('${widget.args.serverUrl}/api/wallet/abroad/banks').replace(
            queryParameters: {'userId': widget.args.userId, 'country': widget.dest['country'].toString()}),
        headers: await AuthService().authenticatedHeaders(),
      ).timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (!mounted) return;
      if (d is Map && d['success'] == true && d['banks'] is List) {
        final list = (d['banks'] as List)
            .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() { _banks = list; _filtered = list; _loading = false; _err = null; });
      } else {
        setState(() {
          _loading = false;
          _err = (d is Map ? d['message'] : null)?.toString() ?? 'Could not load the bank list.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _err = 'Could not load the bank list. Check your connection.'; });
    }
  }

  void _filter(String v) {
    final q = v.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _banks
          : _banks.where((b) => (b['name'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cc = (widget.dest['country'] ?? '').toString();
    return Scaffold(
      backgroundColor: _aBg,
      appBar: _aBar(_aFlag(cc), (widget.dest['name'] ?? '').toString()),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: _filter,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '🔍 Search bank or mobile money network',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: _aCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _aTeal))
              : _err != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_err!, textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFFB4A9), fontSize: 13)),
                          TextButton(
                            onPressed: () { setState(() { _loading = true; _err = null; }); _load(); },
                            child: const Text('Try again', style: TextStyle(color: _aTeal))),
                        ]),
                      ))
                  : _filtered.isEmpty
                      ? const Center(child: Text('No banks found', style: TextStyle(color: _aMuted, fontSize: 13)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final b = _filtered[i];
                            return InkWell(
                              onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                                  builder: (_) => _AbroadDetailsScreen(args: widget.args, dest: widget.dest, bank: b))),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06)))),
                                child: Row(children: [
                                  Expanded(
                                      child: Text((b['name'] ?? '').toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 14))),
                                  if (b['type'] == 'momo')
                                    const Text('Mobile money', style: TextStyle(color: _aMuted, fontSize: 11)),
                                ]),
                              ),
                            );
                          }),
        ),
      ]),
    );
  }
}

class _AbroadDetailsScreen extends StatefulWidget {
  final _AbroadArgs args;
  final Map<String, dynamic> dest;
  final Map<String, dynamic> bank;
  const _AbroadDetailsScreen({required this.args, required this.dest, required this.bank});
  @override
  State<_AbroadDetailsScreen> createState() => _AbroadDetailsScreenState();
}

class _AbroadDetailsScreenState extends State<_AbroadDetailsScreen> {
  Map<String, dynamic>? _q;
  bool _busy = false;
  String? _err;
  final _acc = TextEditingController();
  final _name = TextEditingController();
  final _amt = TextEditingController();
  final _pin = TextEditingController();

  @override
  void dispose() {
    for (final c in [_acc, _name, _amt, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _type => (widget.bank['type'] ?? '').toString();
  String get _cur => (widget.dest['currency'] ?? '').toString();

  Map<String, dynamic>? get _limits {
    final t = widget.dest['types'];
    if (t is Map) {
      final l = t[_type];
      if (l is Map) return Map<String, dynamic>.from(l);
    }
    return null;
  }

  Future<Map<String, String>> _headers() => AuthService().authenticatedHeaders();

  String? _validate() {
    if (_acc.text.replaceAll(RegExp(r'\D'), '').length < 8) return 'Enter the account or mobile number.';
    if (_name.text.trim().length < 2) return 'Enter the recipient name.';
    final amount = double.tryParse(_amt.text.trim()) ?? 0;
    if (amount <= 0) return 'Enter the amount.';
    final l = _limits;
    if (l != null) {
      final mn = (l['min'] as num?)?.toDouble() ?? 0;
      final mx = (l['max'] as num?)?.toDouble() ?? double.infinity;
      if (amount < mn) return 'The minimum is ${_aNum(mn)} $_cur.';
      if (amount > mx) return 'The maximum is ${_aNum(mx)} $_cur for now.';
      if (l['wholeAmount'] == true && amount != amount.roundToDouble()) return 'Enter a whole amount.';
    }
    return null;
  }

  Future<bool> _getQuote() async {
    final amount = double.tryParse(_amt.text.trim()) ?? 0;
    try {
      final r = await http.get(
        Uri.parse('${widget.args.serverUrl}/api/wallet/abroad/quote').replace(queryParameters: {
          'userId': widget.args.userId,
          'country': widget.dest['country'].toString(),
          'bank': widget.bank['code'].toString(),
          'amount': amount.toString(),
        }),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (!mounted) return false;
      if (d is Map && d['success'] == true && d['needed'] == true && (d['token'] ?? '').toString().isNotEmpty) {
        setState(() { _q = Map<String, dynamic>.from(d); });
        return true;
      }
      if (d is Map && d['success'] == true && d['needed'] == false) {
        setState(() { _err = 'This destination uses your own currency. Use To Bank instead.'; });
        return false;
      }
      setState(() { _err = (d is Map ? d['message'] : null)?.toString() ?? 'Could not get a quote.'; });
    } catch (_) {
      if (mounted) setState(() { _err = 'Network error. Could not get a quote.'; });
    }
    return false;
  }

  Future<void> _onQuote() async {
    final v = _validate();
    if (v != null) { setState(() => _err = v); return; }
    setState(() { _busy = true; _err = null; });
    await _getQuote();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _send() async {
    final q = _q;
    if (q == null) return;
    if (!widget.args.pinEnabled) {
      setState(() => _err = 'Turn on your transaction PIN in Settings to send abroad.');
      return;
    }
    if (_pin.text.trim().isEmpty) { setState(() => _err = 'Enter your transaction PIN.'); return; }
    final cost = (q['cost'] as num).toDouble();
    if (cost > widget.args.balance) { setState(() => _err = 'Insufficient balance.'); return; }
    setState(() { _busy = true; _err = null; });
    final prefs = await SharedPreferences.getInstance();
    final key = 'xamepay_abroad_${widget.args.userId}';
    final amount = double.tryParse(_amt.text.trim()) ?? 0;
    final digits = _acc.text.replaceAll(RegExp(r'\D'), '');
    final fp = jsonEncode([widget.args.userId, widget.dest['country'], widget.bank['code'], digits, amount, _name.text.trim()]);
    String ref = '';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final sv = jsonDecode(raw);
        if (sv is Map && sv['fingerprint'] == fp) {
          ref = (sv['reference'] ?? '').toString();
        } else {
          setState(() { _busy = false; _err = 'A previous transfer is unresolved. Retry it before starting another.'; });
          return;
        }
      } catch (_) {
        setState(() { _busy = false; _err = 'A previous transfer needs review. Please do not send again yet.'; });
        return;
      }
    }
    if (ref.isEmpty) {
      ref = 'xame-ab-${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(key, jsonEncode({'fingerprint': fp, 'reference': ref}));
    }
    try {
      final r = await http.post(
        Uri.parse('${widget.args.serverUrl}/api/wallet/abroad/send'),
        headers: await _headers(),
        body: jsonEncode({
          'userId': widget.args.userId,
          'reference': ref,
          'token': q['token'],
          'pin': _pin.text.trim(),
          'account_number': _acc.text.trim(),
          'accName': _name.text.trim(),
          'bankName': (widget.bank['name'] ?? '').toString(),
        }),
      ).timeout(const Duration(seconds: 30));
      dynamic d;
      try { d = jsonDecode(r.body); } catch (_) { d = null; }
      final msg = (d is Map ? d['message'] : null)?.toString();
      final code = (d is Map ? d['code'] : null)?.toString();
      if (d is Map && d['success'] == true) {
        await prefs.remove(key);
        try { await widget.args.onSuccess(); } catch (_) {}
        if (!mounted) return;
        final to = q['to'];
        final got = (q['receive'] as num).toStringAsFixed(2);
        final who = _name.text.trim();
        var n = 0;
        Navigator.of(context).popUntil((_) => n++ >= 3);
        widget.args.snack('✅ Sent. $to $got is on its way to $who.');
        return;
      }
      if (code == 'QUOTE_INVALID') {
        final ok = await _getQuote();
        if (!mounted) return;
        setState(() {
          _busy = false;
          if (ok) _err = 'The rate was updated. Check the new amount, then confirm again.';
        });
        return;
      }
      if (d is Map && d['pending'] == true) {
        try { await widget.args.onSuccess(); } catch (_) {}
        if (!mounted) return;
        setState(() { _busy = false; _err = 'Transfer not confirmed. Do not send again. Reference: $ref'; });
        return;
      }
      final definite = [400, 401, 402, 403, 404, 409, 422, 423].contains(r.statusCode) ||
          (r.statusCode == 503 && (code == 'PAYOUT_TEMPORARILY_UNAVAILABLE' || code == 'RESERVE_FAILED'));
      if (definite) await prefs.remove(key);
      if (d is Map && d['refunded'] == true) {
        try { await widget.args.onSuccess(); } catch (_) {}
      }
      if (!mounted) return;
      setState(() { _busy = false; _err = msg ?? 'Transfer failed.'; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'Network error. Check your balance and history before trying again with the same details.';
        });
      }
    }
  }

  Widget _field(TextEditingController c, String hint, TextInputType kt, {bool obscure = false, int? maxLen}) =>
      TextField(
        controller: c, keyboardType: kt, obscureText: obscure, maxLength: maxLen,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
          filled: true, fillColor: _aCard, counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(t, style: const TextStyle(color: _aMuted, fontSize: 13, fontWeight: FontWeight.w600)));

  Widget _row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _aMuted, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
            child: Text(value, textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white, fontSize: bold ? 16 : 14,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
      ]));

  Widget _button(String text, VoidCallback? onTap) => SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: _aTeal, foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: onTap,
        child: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ));

  List<Widget> _formWidgets() {
    final l = _limits;
    final momo = _type == 'momo';
    return [
      _label(momo ? 'Mobile number' : 'Account number'),
      _field(_acc, momo ? 'Mobile number' : 'Account number', TextInputType.number),
      _label(momo ? 'Name registered on this number' : 'Name on the account'),
      _field(_name, 'Recipient name', TextInputType.name),
      _label('Amount the recipient gets ($_cur)'),
      _field(_amt, 'Amount', const TextInputType.numberWithOptions(decimal: true)),
      if (l != null)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Between ${_aNum((l['min'] as num?)?.toDouble() ?? 0)} and ${_aNum((l['max'] as num?)?.toDouble() ?? 0)} $_cur',
                style: const TextStyle(color: _aMuted, fontSize: 12))),
      const SizedBox(height: 20),
      _button('Get quote', _busy ? null : _onQuote),
    ];
  }

  List<Widget> _quoteWidgets() {
    final q = _q!;
    return [
      const SizedBox(height: 8),
      _row('To', '${_name.text.trim()} (${widget.bank['name'] ?? ''})'),
      _row('Recipient gets', '${q['to']} ${(q['receive'] as num).toStringAsFixed(2)}'),
      const Divider(color: Colors.white12, height: 24),
      _row('You pay', '${q['from']} ${(q['cost'] as num).toStringAsFixed(2)}', bold: true),
      const Text('Includes the transfer fee and the exchange margin. This quote is valid for about 90 seconds.',
          style: TextStyle(color: _aMuted, fontSize: 12)),
      _label('Transaction PIN'),
      _field(_pin, 'PIN', TextInputType.number, obscure: true, maxLen: 6),
      const SizedBox(height: 20),
      _button('Confirm and send', _busy ? null : _send),
      TextButton(
          onPressed: _busy ? null : () => setState(() { _q = null; _err = null; _pin.clear(); }),
          child: const Text('Edit details', style: TextStyle(color: _aMuted))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cc = (widget.dest['country'] ?? '').toString();
    return Scaffold(
      backgroundColor: _aBg,
      appBar: _aBar(_aFlag(cc), (widget.bank['name'] ?? '').toString()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sending to ${widget.dest['name']} · you pay in ${widget.args.currency}',
                style: const TextStyle(color: _aMuted, fontSize: 12)),
            ..._q == null ? _formWidgets() : _quoteWidgets(),
            if (_err != null)
              Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(_err!, style: const TextStyle(color: Color(0xFFFFB4A9), fontSize: 13))),
          ]),
        ),
      ),
    );
  }
}
