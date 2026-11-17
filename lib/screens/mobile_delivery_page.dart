import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/delivery_api.dart';

const _deliveryGreen = Color(0xFF246B45);
const _deliveryMuted = Color(0xFF68736B);

class MobileDeliveryPage extends StatefulWidget {
  const MobileDeliveryPage({super.key});
  @override
  State<MobileDeliveryPage> createState() => _MobileDeliveryPageState();
}

class _MobileDeliveryPageState extends State<MobileDeliveryPage> {
  final DeliveryApi _api = DeliveryApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _partners = [];
  Map<String, dynamic> _assignments = {};
  final Set<String> _busyOrders = {};

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _api.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = await Future.wait([
        _api.load(),
        Supabase.instance.client.from('orders')
            .select('id,order_number,status,total_cents,created_at,delivery_date,address_label,address_line,apartment,landmark,city,state,postal_code')
            .eq('status', 'out_for_delivery')
            .order('created_at', ascending: false),
      ]);
      final delivery = response[0] as Map<String, dynamic>;
      final orders = response[1] as List<dynamic>;
      _partners = List<Map<String, dynamic>>.from(delivery['partners'] ?? const []);
      _assignments = Map<String, dynamic>.from(delivery['assignments'] ?? const {});
      _orders = orders.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign(Map<String, dynamic> order, String partnerUid) async {
    final id = order['id'].toString();
    setState(() => _busyOrders.add(id));
    try {
      await _api.assign(id, partnerUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery partner assigned.')));
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busyOrders.remove(id));
    }
  }

  Future<void> _unassign(Map<String, dynamic> order) async {
    final id = order['id'].toString();
    setState(() => _busyOrders.add(id));
    try {
      await _api.unassign(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery assignment removed.')));
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busyOrders.remove(id));
    }
  }

  String _address(Map<String, dynamic> order) {
    final parts = [
      order['address_line'], order['apartment'],
      order['landmark'] == null ? null : 'near ${order['landmark']}',
      order['city'], order['state'], order['postal_code'],
    ];
    final value = parts.where((p) => p != null && p.toString().trim().isNotEmpty).join(', ');
    return value.isEmpty ? (order['address_label']?.toString() ?? 'Address not provided') : value;
  }

  String _money(dynamic cents) {
    final value = cents is num ? cents / 100 : 0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _orders.isEmpty && _error == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delivery operations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Assign eligible orders to active delivery partners.', style: TextStyle(color: _deliveryMuted, fontSize: 12)),
          ])),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ]),
        if (_error != null) Card(
          color: const Color(0xFFFFF1F0),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Delivery server unavailable', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red)),
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Check ADMIN_API_BASE_URL and Vercel deployment protection. Firebase credentials remain on the server.', style: TextStyle(fontSize: 12, color: _deliveryMuted)),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _load, child: const Text('Retry'))),
          ])),
        ),
        Row(children: [
          Expanded(child: _Metric(label: 'Active partners', value: '${_partners.length}', icon: Icons.people_alt_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _Metric(label: 'Orders to assign', value: '${_orders.length}', icon: Icons.local_shipping_outlined)),
        ]),
        const SizedBox(height: 16),
        Text('Out for delivery · ${_orders.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (_orders.isEmpty && _error == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(
            child: Text('No orders are currently marked Out for Delivery.', style: TextStyle(color: _deliveryMuted)),
          )),
        ..._orders.map((order) {
          final id = order['id'].toString();
          final raw = _assignments[id];
          final assignment = raw is Map ? Map<String, dynamic>.from(raw) : null;
          final assignedUid = assignment?['partnerUid']?.toString();
          final assignedName = assignment?['partnerName']?.toString();
          final busy = _busyOrders.contains(id);
          final selected = _partners.any((p) => p['uid'] == assignedUid) ? assignedUid : null;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Order #${order['order_number']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFE8F1E9), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Out for delivery', style: TextStyle(color: _deliveryGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 5),
              Text('${order['delivery_date'] ?? 'Delivery date not set'} · ${_money(order['total_cents'])}', style: const TextStyle(fontSize: 12, color: _deliveryMuted)),
              const SizedBox(height: 8),
              Text(_address(order), style: const TextStyle(fontSize: 12, height: 1.35)),
              const Divider(height: 20),
              if (assignedUid != null)
                Row(children: [
                  const Icon(Icons.check_circle, color: _deliveryGreen, size: 18),
                  const SizedBox(width: 7),
                  Expanded(child: Text('Assigned to ${assignedName ?? assignedUid}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                  TextButton(onPressed: busy ? null : () => _unassign(order), child: const Text('Unassign')),
                ])
              else
                const Text('Not assigned yet', style: TextStyle(color: _deliveryMuted, fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select delivery partner', isDense: true),
                items: _partners.map((p) => DropdownMenuItem<String>(
                  value: p['uid'].toString(),
                  child: Text('${p['name']} · ${p['email']}', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: busy || _partners.isEmpty ? null : (uid) {
                  if (uid != null && uid != assignedUid) _assign(order, uid);
                },
              ),
              if (_partners.isEmpty) const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No active @smmart.com delivery partner accounts were returned.', style: TextStyle(color: _deliveryMuted, fontSize: 11)),
              ),
              if (busy) const LinearProgressIndicator(minHeight: 2),
            ])),
          );
        }),
        const SizedBox(height: 8),
        const Card(child: ListTile(
          leading: Icon(Icons.verified_user_outlined, color: _deliveryGreen),
          title: Text('Server-enforced assignment safety'),
          subtitle: Text('Every change rechecks order status. Only Out for Delivery orders can be assigned; delivered and cancelled orders are rejected.'),
        )),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(children: [
      Icon(icon, color: _deliveryGreen),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 10, color: _deliveryMuted)),
      ])),
    ]),
  ));
}
