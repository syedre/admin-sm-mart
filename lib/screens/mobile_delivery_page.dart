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
  String _search = '';
  String _assignmentFilter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _api.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final delivery = await _api.load();
      final orders = await Supabase.instance.client.from('orders')
          .select('id,order_number,status,total_cents,created_at,delivery_date,address_label,address_line,apartment,landmark,city,state,postal_code')
          .eq('status', 'out_for_delivery')
          .order('created_at', ascending: false);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
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
    final query = _search.trim().toLowerCase();
    final visibleOrders = _orders.where((order) {
      final id = order['id'].toString();
      final raw = _assignments[id];
      final assigned = raw is Map && raw['partnerUid'] != null;
      final matchesAssignment = _assignmentFilter == 'all' ||
          (_assignmentFilter == 'assigned' && assigned) ||
          (_assignmentFilter == 'unassigned' && !assigned);
      final searchable = '${order['order_number']} ${_address(order)}'.toLowerCase();
      return matchesAssignment && (query.isEmpty || searchable.contains(query));
    }).toList();
    final assignedCount = _orders.where((order) {
      final raw = _assignments[order['id'].toString()];
      return raw is Map && raw['partnerUid'] != null;
    }).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF174C32), Color(0xFF28764D)]),
          ),
          child: Row(children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivery operations', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('Assign eligible orders to active partners.', style: TextStyle(color: Color(0xFFDCEBE1), fontSize: 11)),
            ])),
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white), tooltip: 'Refresh'),
          ]),
        ),
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
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Metric(label: 'Active partners', value: '${_partners.length}', icon: Icons.people_alt_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _Metric(label: 'Awaiting assignment', value: '${_orders.length - assignedCount}', icon: Icons.assignment_late_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _Metric(label: 'Assigned', value: '$assignedCount', icon: Icons.assignment_turned_in_outlined)),
        ]),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search order or delivery address',
            isDense: true,
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 9),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('All'), selected: _assignmentFilter == 'all', onSelected: (_) => setState(() => _assignmentFilter = 'all')),
          ChoiceChip(label: const Text('Assigned'), selected: _assignmentFilter == 'assigned', onSelected: (_) => setState(() => _assignmentFilter = 'assigned')),
          ChoiceChip(label: const Text('Unassigned'), selected: _assignmentFilter == 'unassigned', onSelected: (_) => setState(() => _assignmentFilter = 'unassigned')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Out for delivery · ${visibleOrders.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          Text('${_orders.length} total', style: const TextStyle(fontSize: 11, color: _deliveryMuted)),
        ]),
        if (_orders.isEmpty && _error == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(
            child: Text('No orders are currently marked Out for Delivery.', style: TextStyle(color: _deliveryMuted)),
          )),
        if (_orders.isNotEmpty && visibleOrders.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(
            child: Text('No orders match this search or filter.', style: TextStyle(color: _deliveryMuted)),
          )),
        ...visibleOrders.map((order) {
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
                initialValue: selected,
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
