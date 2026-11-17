import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for the existing SM mart Supabase schema.
///
/// Keep this client-side service on the signed-in admin session so existing
/// RLS and admin RPC permissions remain authoritative. Never use service_role.
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> loadProducts() async {
    final rows = await _client
        .from('products')
        .select('product_id,name,description,price,mrp,unit,stock_quantity,image_url,is_active,category_id,home_page_status,inventory_quantity,inventory_unit,created_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadCategories() async {
    final rows = await _client
        .from('product_category')
        .select('id,name,is_active,img_url')
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadHomeStatuses() async {
    final rows = await _client.from('enum_table').select('id,name').order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadOrders() async {
    final rows = await _client
        .from('orders')
        .select('id,order_number,user_id,status,payment_method,payment_status,total_cents,created_at,delivery_date,address_label,address_line,apartment,landmark,city,state,postal_code,latitude,longitude,order_items(id,product_name,product_unit,quantity,unit_price_cents)')
        .order('created_at', ascending: false);
    final orders = List<Map<String, dynamic>>.from(rows);
    final userIds = orders.map((row) => row['user_id']).whereType<String>().toSet().toList();
    if (userIds.isNotEmpty) {
      final phoneRows = await _client.rpc('admin_customer_phones', params: {'p_user_ids': userIds});
      final phoneByUser = <String, String>{};
      for (final row in (phoneRows as List<dynamic>)) {
        if (row is Map && row['user_id'] is String && row['phone'] is String) {
          phoneByUser[row['user_id'] as String] = row['phone'] as String;
        }
      }
      for (final order in orders) {
        order['customer_phone'] = phoneByUser[order['user_id']];
      }
    }
    return orders;
  }

  Future<Map<String, dynamic>> loadShopSettings() async {
    return await _client
        .from('shop_settings')
        .select('is_open,closed_message,accepting_online_orders')
        .eq('id', 1)
        .single();
  }

  Future<List<Map<String, dynamic>>> loadVariants() async {
    final rows = await _client
        .from('product_variants')
        .select('variant_id,product_id,variant_name,unit_label,price,mrp,inventory_quantity_per_pack,is_active,sort_order')
        .order('sort_order')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> uploadProductImage(File image) async {
    final extension = image.path.split('.').last.toLowerCase().replaceAll('jpeg', 'jpg');
    final fileName = 'product/images/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('royalwood').upload(
          fileName,
          image,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
    return _client.storage.from('royalwood').getPublicUrl(fileName);
  }

  Future<void> setProductVisibility(String productId, bool visible) async {
    await _client.from('products').update({'is_active': visible}).eq('product_id', productId);
  }

  Future<void> setCategoryVisibility(String categoryId, bool visible) async {
    await _client.from('product_category').update({'is_active': visible}).eq('id', categoryId);
  }

  Future<void> addCategory(String name) async {
    await _client.from('product_category').insert({'name': name.trim(), 'is_active': true});
  }

  Future<void> updateOrderStatus(String orderId, String nextStatus) async {
    await _client.rpc('admin_update_order_status', params: {
      'p_order_id': orderId,
      'p_status': nextStatus,
    });
    if (nextStatus == 'confirmed') {
      await _client.functions.invoke(
        'whatsapp-order-confirmation',
        body: {'order_id': orderId},
      );
    }
  }

  Future<void> updateShopSettings({
    required bool isOpen,
    required bool acceptingOnlineOrders,
    required String closedMessage,
  }) async {
    await _client.from('shop_settings').update({
      'is_open': isOpen,
      'accepting_online_orders': acceptingOnlineOrders,
      'closed_message': closedMessage.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', 1);
  }
}
