// XAMEPAY_ABROAD_UI_V1: send from the wallet to a bank or mobile-money account in another country.
// Countries, banks, networks and limits all come from the server, which gets them live from the payment provider.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/auth_service.dart';

const _aTeal = Color(0xFF12A872);
const _aCard = Color(0xFF0A3327);
const _aBg = Color(0xFF062B21);
const _aMuted = Color(0xFF8FB3A6);

String _aFlag(String cc) {
  final c = cc.toUpperCase();
  if (c.length != 2) return '';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 0x41));
}

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
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: _aBg,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => _AbroadSheet(
            serverUrl: widget.serverUrl, userId: widget.userId, currency: widget.currency,
            balance: widget.balance, pinEnabled: widget.pinEnabled, dests: _dests,
            onSuccess: widget.onSuccess, snack: widget.snack),
        ),
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

class _AbroadSheet extends StatefulWidget {
  final String serverUrl, userId, currency;
  final double balance;
  final bool pinEnabled;
  final List<Map<String, dynamic>> dests;
  final Future<void> Function() onSuccess;
  final void Function(String) snack;
  const _AbroadSheet({required this.serverUrl, required this.userId, required this.currency,
      required this.balance, required this.pinEnabled, required this.dests,
      required this.onSuccess, required this.snack});
  @override
  State<_AbroadSheet> createState() => _AbroadSheetState();
}

class _AbroadSheetState extends State<_AbroadSheet> {
  Map<String, dynamic>? _dest;
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, dynamic>? _bank;
  Map<String, dynamic>? _q;
  bool _loadingBanks = false, _busy = false;
  String? _err;
  final _search = TextEditingController();
  final _acc = TextEditingController();
  final _name = TextEditingController();
  final _amt = TextEditingController();
  final _pin = TextEditingController();

  @override
  void dispose() {
    for (final c in [_search, _acc, _name, _amt, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _type => (_bank?['type'] ?? '').toString();

  Map<String, dynamic>? get _limits {
    final t = _dest?['types'];
    if (t is Map && _type.isNotEmpty) {
      final l = t[_type];
      if (l is Map) return Map<String, dynamic>.from(l);
    }
    return null;
  }

  Future<Map<String, String>> _headers() => AuthService().authenticatedHeaders();

  void _pickCountry(Map<String, dynamic> d) {
    setState(() {
      _dest = d; _bank = null; _banks = []; _filtered = []; _q = null; _err = null;
      _search.clear();
    });
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    final cc = (_dest?['country'] ?? '').toString();
    if (cc.isEmpty) return;
    setState(() { _loadingBanks = true; _err = null; });
    try {
      final r = await http.get(
        Uri.parse('${widget.serverUrl}/api/wallet/abroad/banks')
            .replace(queryParameters: {'userId': widget.userId, 'country': cc}),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));
      final d = jsonDecode(r.body);
      if (!mounted) return;
      if (d is Map && d['success'] == true && d['banks'] is List) {
        final list = (d['banks'] as List)
            .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() { _banks = list; _filtered = list; _loadingBanks = false; });
      } else {
        setState(() {
          _loadingBanks = false;
          _err = (d is Map ? d['message'] : null)?.toString() ?? 'Could not load the bank list.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _loadingBanks = false; _err = 'Could not load the bank list. Check your connection.'; });
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

  String? _validate() {
    if (_dest == null) return 'Choose a country.';
    if (_bank == null) return 'Choose a bank or network.';
    if (_acc.text.replaceAll(RegExp(r'\D'), '').length < 8) return 'Enter the account or mobile number.';
    if (_name.text.trim().length < 2) return 'Enter the recipient name.';
    final amount = double.tryParse(_amt.text.trim()) ?? 0;
    if (amount <= 0) return 'Enter the amount.';
    final l = _limits;
    if (l != null) {
      final mn = (l['min'] as num?)?.toDouble() ?? 0;
      final mx = (l['max'] as num?)?.toDouble() ?? double.infinity;
      if (amount < mn) return 'The minimum is $mn ${_dest!['currency']}.';
      if (amount > mx) return 'The maximum is $mx ${_dest!['currency']} for now.';
      if (l['wholeAmount'] == true && amount != amount.roundToDouble()) return 'Enter a whole amount.';
    }
    return null;
  }

  Future<bool> _getQuote() async {
    final amount = double.tryParse(_amt.text.trim()) ?? 0;
    try {
      final r = await http.get(
        Uri.parse('${widget.serverUrl}/api/wallet/abroad/quote').replace(queryParameters: {
          'userId': widget.userId,
          'country': _dest!['country'].toString(),
          'bank': _bank!['code'].toString(),
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
    if (!widget.pinEnabled) {
      setState(() => _err = 'Turn on your transaction PIN in Settings to send abroad.');
      return;
    }
    if (_pin.text.trim().isEmpty) { setState(() => _err = 'Enter your transaction PIN.'); return; }
    final cost = (q['cost'] as num).toDouble();
    if (cost > widget.balance) { setState(() => _err = 'Insufficient balance.'); return; }
    setState(() { _busy = true; _err = null; });
    final prefs = await SharedPreferences.getInstance();
    final key = 'xamepay_abroad_${widget.userId}';
    final amount = double.tryParse(_amt.text.trim()) ?? 0;
    final digits = _acc.text.replaceAll(RegExp(r'\D'), '');
    final fp = jsonEncode([widget.userId, _dest!['country'], _bank!['code'], digits, amount, _name.text.trim()]);
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
        Uri.parse('${widget.serverUrl}/api/wallet/abroad/send'),
        headers: await _headers(),
        body: jsonEncode({
          'userId': widget.userId,
          'reference': ref,
          'token': q['token'],
          'pin': _pin.text.trim(),
          'account_number': _acc.text.trim(),
          'accName': _name.text.trim(),
          'bankName': (_bank!['name'] ?? '').toString(),
        }),
      ).timeout(const Duration(seconds: 30));
      dynamic d;
      try { d = jsonDecode(r.body); } catch (_) { d = null; }
      final msg = (d is Map ? d['message'] : null)?.toString();
      final code = (d is Map ? d['code'] : null)?.toString();
      if (d is Map && d['success'] == true) {
        await prefs.remove(key);
        try { await widget.onSuccess(); } catch (_) {}
        if (!mounted) return;
        Navigator.pop(context);
        widget.snack('✅ Sent. ${q['to']} ${(q['receive'] as num).toStringAsFixed(2)} is on its way to ${_name.text.trim()}.');
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
        try { await widget.onSuccess(); } catch (_) {}
        if (!mounted) return;
        setState(() { _busy = false; _err = 'Transfer not confirmed. Do not send again. Reference: $ref'; });
        return;
      }
      final definite = [400, 401, 402, 403, 404, 409, 422, 423].contains(r.statusCode) ||
          (r.statusCode == 503 && (code == 'PAYOUT_TEMPORARILY_UNAVAILABLE' || code == 'RESERVE_FAILED'));
      if (definite) await prefs.remove(key);
      if (d is Map && d['refunded'] == true) {
        try { await widget.onSuccess(); } catch (_) {}
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

  Widget _field(TextEditingController c, String hint, TextInputType kt, {bool obscure = false, int? maxLen, void Function(String)? onChanged}) =>
      TextField(
        controller: c, keyboardType: kt, obscureText: obscure, maxLength: maxLen, onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
          filled: true, fillColor: _aCard, counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(t, style: const TextStyle(color: _aMuted, fontSize: 13, fontWeight: FontWeight.w600)));

  Widget _row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _aMuted, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white, fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
      ]));

  Widget _button(String text, VoidCallback? onTap) => SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: _aTeal, foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: onTap,
        child: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ));

  List<Widget> _formWidgets() {
    final l = _limits;
    final cur = (_dest?['currency'] ?? '').toString();
    return [
      _label('Country'),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: widget.dests.map<Widget>((d) {
          final sel = identical(_dest, d);
          return ChoiceChip(
            label: Text('${_aFlag((d['country'] ?? '').toString())} ${d['name']}'),
            selected: sel,
            selectedColor: _aTeal,
            backgroundColor: _aCard,
            labelStyle: TextStyle(color: sel ? Colors.black : Colors.white),
            onSelected: (_) => _pickCountry(d),
          );
        }).toList(),
      ),
      if (_dest != null) ...[
        _label('Bank or mobile money network'),
        if (_loadingBanks)
          const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: _aTeal, strokeWidth: 2)))
        else if (_bank != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: _aCard, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: Text('✅ ${_bank!['name']}', style: const TextStyle(color: _aTeal, fontWeight: FontWeight.w700))),
              TextButton(
                onPressed: () => setState(() { _bank = null; _q = null; _filtered = _banks; }),
                child: const Text('Change', style: TextStyle(color: _aMuted))),
            ]),
          )
        else ...[
          _field(_search, 'Search', TextInputType.text, onChanged: _filter),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
            child: _filtered.isEmpty
                ? const Padding(padding: EdgeInsets.all(16),
                    child: Text('Nothing found', style: TextStyle(color: _aMuted, fontSize: 13)))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final b = _filtered[i];
                      return InkWell(
                        onTap: () => setState(() { _bank = b; _q = null; _err = null; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
                          child: Row(children: [
                            Expanded(child: Text((b['name'] ?? '').toString(), style: const TextStyle(color: Colors.white, fontSize: 14))),
                            if (b['type'] == 'momo')
                              const Text('Mobile money', style: TextStyle(color: _aMuted, fontSize: 11)),
                          ]),
                        ),
                      );
                    }),
          ),
        ],
      ],
      if (_bank != null) ...[
        _label(_type == 'momo' ? 'Mobile number' : 'Account number'),
        _field(_acc, _type == 'momo' ? 'Mobile number' : 'Account number', TextInputType.number),
        _label(_type == 'momo' ? 'Name registered on this number' : 'Name on the account'),
        _field(_name, 'Recipient name', TextInputType.name),
        _label('Amount the recipient gets ($cur)'),
        _field(_amt, 'Amount', const TextInputType.numberWithOptions(decimal: true)),
        if (l != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Between ${l['min']} and ${l['max']} $cur',
                style: const TextStyle(color: _aMuted, fontSize: 12))),
        const SizedBox(height: 16),
        _button('Get quote', _busy ? null : _onQuote),
      ],
    ];
  }

  List<Widget> _quoteWidgets() {
    final q = _q!;
    return [
      _row('To', '${_name.text.trim()} (${_bank?['name'] ?? ''})'),
      _row('Recipient gets', '${q['to']} ${(q['receive'] as num).toStringAsFixed(2)}'),
      const Divider(color: Colors.white12, height: 24),
      _row('You pay', '${q['from']} ${(q['cost'] as num).toStringAsFixed(2)}', bold: true),
      const Text('Includes the transfer fee and the exchange margin. This quote is valid for about 90 seconds.',
          style: TextStyle(color: _aMuted, fontSize: 12)),
      _label('Transaction PIN'),
      _field(_pin, 'PIN', TextInputType.number, obscure: true, maxLen: 6),
      const SizedBox(height: 16),
      _button('Confirm and send', _busy ? null : _send),
      TextButton(
        onPressed: _busy ? null : () => setState(() { _q = null; _err = null; _pin.clear(); }),
        child: const Text('Back', style: TextStyle(color: _aMuted))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            const Text('🌍 Send abroad',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('You choose what the recipient gets. The cost is shown in your wallet currency before you confirm.',
                style: TextStyle(color: _aMuted, fontSize: 12)),
            if (_q == null) ..._formWidgets() else ..._quoteWidgets(),
            if (_err != null)
              Padding(padding: const EdgeInsets.only(top: 12),
                  child: Text(_err!, style: const TextStyle(color: Color(0xFFFFB4A9), fontSize: 13))),
          ]),
        ),
      ),
    );
  }
}
