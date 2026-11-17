import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import 'admin_features.dart';
import 'mobile_delivery_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  int _ordersRefreshKey = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
    NavigationDestination(icon: Icon(Icons.widgets_outlined), selectedIcon: Icon(Icons.widgets), label: 'Packs'),
    NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Delivery'),
    NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Shop'),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = ['Overview', 'Catalogue', 'Orders', 'Pack sizes', 'Delivery', 'Shop settings'];
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SM mart', style: TextStyle(fontWeight: FontWeight.w800)),
          Text(titles[_index], style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _ordersRefreshKey++), icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _OverviewPage(
            onOpenOrders: () => setState(() => _index = 2),
            onOpenProducts: () => setState(() => _index = 1),
            onOpenDelivery: () => setState(() => _index = 4),
          ),
          CataloguePage(),
          OrdersPage(key: ValueKey(_ordersRefreshKey)),
          PacksPage(),
          MobileDeliveryPage(),
          ShopPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          if (value == 2) _ordersRefreshKey++;
          _index = value;
        }),
        destinations: _destinations,
      ),
    );
  }
}

class _OverviewPage extends StatefulWidget {
  const _OverviewPage({required this.onOpenOrders, required this.onOpenProducts, required this.onOpenDelivery});
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenDelivery;
  @override
  State<_OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<_OverviewPage> {
  bool _loading = true;
  String? _error;
  int _products = 0, _activeProducts = 0, _activeOrders = 0, _todayOrders = 0;
  int _newOrders = 0, _preparing = 0, _outForDelivery = 0;
  bool _shopOpen = false, _accepting = false;
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client.from('products').select('product_id,is_active'),
        client.from('orders').select('id,order_number,status,total_cents,created_at,delivery_date').order('created_at', ascending: false),
        client.from('shop_settings').select('is_open,accepting_online_orders').eq('id', 1).maybeSingle(),
      ]);
      final products = List<Map<String, dynamic>>.from(results[0]);
      final orders = List<Map<String, dynamic>>.from(results[1]);
      final settings = results[2] as Map<String, dynamic>?;
      final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final today = DateFormat('yyyy-MM-dd').format(now);
      _products = products.length;
      _activeProducts = products.where((p) => p['is_active'] == true).length;
      _activeOrders = orders.where((o) => !['delivered', 'cancelled'].contains(o['status'])).length;
      _todayOrders = orders.where((o) => o['delivery_date']?.toString() == today).length;
      _newOrders = orders.where((o) => o['status'] == 'placed').length;
      _preparing = orders.where((o) => ['confirmed', 'preparing'].contains(o['status'])).length;
      _outForDelivery = orders.where((o) => o['status'] == 'out_for_delivery').length;
      _shopOpen = settings?['is_open'] == true;
      _accepting = settings?['accepting_online_orders'] == true;
      _recentOrders = orders.take(5).toList();
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  String _status(String s) => switch (s) {
    'placed' => 'New', 'confirmed' => 'Confirmed', 'preparing' => 'Preparing',
    'out_for_delivery' => 'On the way', 'delivered' => 'Delivered',
    'cancelled' => 'Cancelled', _ => s.replaceAll('_', ' ')
  };

  Color _statusColor(String s) => switch (s) {
    'placed' => const Color(0xFFB7791F),
    'confirmed' || 'preparing' => const Color(0xFF2563A6),
    'out_for_delivery' => const Color(0xFF246B45),
    'cancelled' => const Color(0xFFB42318),
    _ => const Color(0xFF64748B)
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 28),
        children: [
          if (_error != null) _ErrorCard(message: _error!),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF174C32), Color(0xFF28764D)]),
              boxShadow: const [BoxShadow(color: Color(0x1A174C32), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('SM mart  /  ADMIN', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1))),
                IconButton(onPressed: _load, tooltip: 'Refresh dashboard', icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
              ]),
              const Text('Good to see you.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Here is what is happening at your store today.', style: TextStyle(color: Color(0xFFDCEBE1), fontSize: 12)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _WelcomeChip(label: _shopOpen ? 'Shop open' : 'Shop closed', active: _shopOpen),
                _WelcomeChip(label: _accepting ? 'Orders enabled' : 'Orders paused', active: _accepting),
              ]),
            ]),
          ),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(child: Text('Business overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            Text(DateFormat('EEE, d MMM').format(DateTime.now()), style: const TextStyle(fontSize: 12, color: Color(0xFF68736B))),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: wide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: wide ? 1.55 : 1.32,
            children: [
              _DashboardMetric(label: 'Active orders', value: _activeOrders.toString(), note: 'Orders in progress', icon: Icons.receipt_long_rounded, tint: const Color(0xFFE8F2EB), onTap: widget.onOpenOrders),
              _DashboardMetric(label: "Today's deliveries", value: _todayOrders.toString(), note: 'Scheduled for today', icon: Icons.local_shipping_rounded, tint: const Color(0xFFEAF1FA), onTap: widget.onOpenOrders),
              _DashboardMetric(label: 'Live products', value: _activeProducts.toString(), note: _products.toString() + ' total catalogue items', icon: Icons.inventory_2_rounded, tint: const Color(0xFFFFF3E3), onTap: widget.onOpenProducts),
              _DashboardMetric(label: 'Out for delivery', value: _outForDelivery.toString(), note: 'Currently with partners', icon: Icons.delivery_dining_rounded, tint: const Color(0xFFF1ECFA), onTap: widget.onOpenDelivery),
            ],
          ),
          const SizedBox(height: 22),
          _DashboardHeading(title: 'Order activity', subtitle: 'Orders by their current stage', action: 'View all', onTap: widget.onOpenOrders),
          const SizedBox(height: 10),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _StageRow(label: 'New orders', value: _newOrders, color: const Color(0xFFD69A32), icon: Icons.fiber_new_rounded),
            const SizedBox(height: 15),
            _StageRow(label: 'Confirmed / preparing', value: _preparing, color: const Color(0xFF3979B9), icon: Icons.soup_kitchen_outlined),
            const SizedBox(height: 15),
            _StageRow(label: 'Out for delivery', value: _outForDelivery, color: const Color(0xFF246B45), icon: Icons.local_shipping_outlined),
          ]))),
          const SizedBox(height: 22),
          _DashboardHeading(title: 'Recent orders', subtitle: 'Latest customer activity', action: 'See all', onTap: widget.onOpenOrders),
          const SizedBox(height: 10),
          if (_recentOrders.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('New customer orders will appear here.', style: TextStyle(color: Color(0xFF68736B))))))
          else
            ..._recentOrders.map((o) {
              final status = o['status']?.toString() ?? '';
              final created = DateTime.tryParse(o['created_at']?.toString() ?? '');
              final amount = ((o['total_cents'] as num?) ?? 0) / 100;
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEAF2EC), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.receipt_long_rounded, color: SmMartAdminApp.brandGreen, size: 21)),
                  title: Text('Order #' + (o['order_number']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text(created == null ? 'Date unavailable' : DateFormat('d MMM · h:mm a').format(created.toLocal()), style: const TextStyle(fontSize: 11, color: Color(0xFF68736B))),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 4),
                    _StatusPill(label: _status(status), color: _statusColor(status)),
                  ]),
                  onTap: widget.onOpenOrders,
                ),
              );
            }),
          const SizedBox(height: 12),
          const Text('Quick access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _QuickTile(icon: Icons.receipt_long_rounded, label: 'Orders', onTap: widget.onOpenOrders)),
            const SizedBox(width: 9),
            Expanded(child: _QuickTile(icon: Icons.inventory_2_rounded, label: 'Products', onTap: widget.onOpenProducts)),
            const SizedBox(width: 9),
            Expanded(child: _QuickTile(icon: Icons.local_shipping_rounded, label: 'Delivery', onTap: widget.onOpenDelivery)),
          ]),
        ],
      ),
    );
  }
}

class _WelcomeChip extends StatelessWidget {
  const _WelcomeChip({required this.label, required this.active});
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(active ? Icons.check_circle_outline : Icons.info_outline, size: 14, color: active ? const Color(0xFFBDE8C9) : const Color(0xFFFFD2C9)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.label, required this.value, required this.note, required this.icon, required this.tint, required this.onTap});
  final String label, value, note;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 35, height: 35, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: SmMartAdminApp.brandGreen, size: 19)),
        const Spacer(),
        const Icon(Icons.north_east_rounded, size: 15, color: Color(0xFF9AA39C)),
      ]),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.1)),
      const SizedBox(height: 4),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF68736B))),
    ]))),
  );
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading({required this.title, required this.subtitle, required this.action, required this.onTap});
  final String title, subtitle, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF68736B))),
    ])),
    TextButton(onPressed: onTap, child: Text(action)),
  ]);
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)),
    const SizedBox(width: 11),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    Text(value.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
  ]);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5), child: Column(children: [
        Icon(icon, color: SmMartAdminApp.brandGreen, size: 21),
        const SizedBox(height: 7),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      ]))),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(color: const Color(0xFFFFF1F0), child: Padding(padding: const EdgeInsets.all(14), child: Text(message, style: const TextStyle(color: Colors.red))));
}
