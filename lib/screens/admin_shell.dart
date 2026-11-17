import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

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
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
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
        children: const [
          _OverviewPage(),
          _FeaturePlaceholder(title: 'Catalogue', detail: 'Products, categories, images and visibility management.'),
          _FeaturePlaceholder(title: 'Orders', detail: 'Customer orders, date filters, contact details and status transitions.'),
          _FeaturePlaceholder(title: 'Pack sizes', detail: 'Variant pricing and shared physical inventory.'),
          _FeaturePlaceholder(title: 'Delivery', detail: 'Delivery partner assignments and live sessions. Firebase Admin credentials remain server-side.'),
          _FeaturePlaceholder(title: 'Shop settings', detail: 'Shop open/closed state, online-order availability and customer closure message.'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: _destinations,
      ),
    );
  }
}

class _OverviewPage extends StatefulWidget {
  const _OverviewPage();

  @override
  State<_OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<_OverviewPage> {
  bool _loading = true;
  String? _error;
  int _products = 0;
  int _activeProducts = 0;
  int _activeOrders = 0;
  int _todayOrders = 0;
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final products = await client.from('products').select('product_id,is_active');
      final orders = await client.from('orders')
          .select('id,order_number,status,total_cents,created_at,delivery_date')
          .order('created_at', ascending: false);
      final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _products = products.length;
      _activeProducts = products.where((p) => p['is_active'] == true).length;
      _activeOrders = orders.where((o) => !['delivered', 'cancelled'].contains(o['status'])).length;
      _todayOrders = orders.where((o) => o['delivery_date'] == today).length;
      _recentOrders = orders.take(5).cast<Map<String, dynamic>>().toList();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) _ErrorCard(message: _error!),
          const Text('Store management · Channapatna', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _MetricCard(label: 'Active products', value: '$_activeProducts', note: '$_products total catalogue items', icon: Icons.inventory_2_outlined),
              _MetricCard(label: 'Active orders', value: '$_activeOrders', note: 'Not delivered or cancelled', icon: Icons.receipt_long_outlined),
              _MetricCard(label: "Today's deliveries", value: '$_todayOrders', note: 'Scheduled in India time', icon: Icons.local_shipping_outlined),
              const _MetricCard(label: 'Store', value: 'Live', note: 'Existing Supabase project', icon: Icons.storefront_outlined),
            ],
          ),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(child: Text('Recent orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
          ]),
          if (_recentOrders.isEmpty) const _EmptyState(message: 'No customer orders yet.'),
          ..._recentOrders.map((order) => Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE8F1E9), child: Icon(Icons.receipt_long, color: SmMartAdminApp.brandGreen)),
              title: Text('Order #${order['order_number']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${order['status']} · ${order['created_at']}'),
              trailing: Text('₹${((order['total_cents'] ?? 0) / 100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          )),
        ],
      ),
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  const _FeaturePlaceholder({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.construction_rounded, size: 42, color: SmMartAdminApp.brandGreen),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          const Text('Feature parity implementation is next; no existing backend has been changed.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        ]),
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.note, required this.icon});
  final String label;
  final String value;
  final String note;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))), Icon(icon, color: SmMartAdminApp.brandGreen, size: 19)]),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFF1F0),
    child: Padding(padding: const EdgeInsets.all(14), child: Text(message, style: const TextStyle(color: Colors.red))),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(child: Text(message, style: const TextStyle(color: Colors.black54))),
  );
}
