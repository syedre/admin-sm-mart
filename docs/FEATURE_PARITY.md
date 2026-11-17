# Feature parity checklist

This is the implementation map extracted from the current Next.js dashboard. Do not change the existing web dashboard or backend while implementing the Flutter client.

| Area | Existing behavior to preserve | Flutter status |
|---|---|---|
| Authentication | Supabase email/password; only `admin@gmail.com` is authorized | Login foundation committed |
| Overview | Active products, active orders, today's deliveries (IST), assigned count, recent orders, shop state | Initial metrics and recent orders committed; assigned count/shop state pending |
| Catalogue | Product create/edit, description, price/MRP, unit, stock, category, homepage section, image upload to `royalwood/product/images/`, visibility toggle | Repository data layer committed; full UI/actions pending |
| Categories | Add category, prevent duplicate names, active/hidden toggle | Repository methods committed; full UI pending |
| Orders | Search order number, delivery-date filters (today/tomorrow/day after/yesterday, IST), customer phone via `admin_customer_phones`, items/address/map, COD payment status, ordered status transitions | Query/RPC foundation committed; full UI pending |
| WhatsApp | Invoke existing `whatsapp-order-confirmation` Edge Function after confirmation | Repository method committed |
| Pack sizes | Add/edit/enable/disable variants, shared stock consumption, synchronize default variant to product summary | Full UI and writes pending |
| Shop | `is_open`, `accepting_online_orders`, `closed_message` controls on `shop_settings.id = 1` | Repository method committed; full UI pending |
| Delivery | Firebase Auth partner list, assignments, partnerAssignments, deliverySessions; only out-for-delivery orders assignable; delivered/cancelled cannot be assigned | Blocked on secure mobile authentication to existing Vercel route |

## Delivery security constraint

The current `GET/POST /api/delivery` route authorizes the admin using the Next.js cookie session. A Flutter app's Supabase session is a bearer token and does not automatically carry that browser cookie. Firebase Admin credentials must never be placed in Flutter. Delivery parity therefore needs an additive, bearer-authenticated server adapter (or another explicitly approved secure bridge). Until then, do not call Firebase directly from the app and do not weaken the existing route.

## Existing database contract used

- `products`, `product_category`, `enum_table`, `product_variants`, `orders`, `order_items`, `shop_settings`
- RPC: `admin_customer_phones(p_user_ids)`
- RPC: `admin_update_order_status(p_order_id, p_status)`
- Storage bucket: `royalwood`
- Edge Function: `whatsapp-order-confirmation`

No migrations, schema changes, service-role keys, or Firebase secrets are part of this Flutter repository.
