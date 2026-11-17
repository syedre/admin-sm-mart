# SM mart Admin — Flutter

Cross-platform Flutter admin app for Android and iOS, intended to reach feature parity with the existing [SM mart Admin Dashboard](https://github.com/syedre/sm-mart-admin-dashboard).

## Scope

- Supabase Auth sign-in restricted to the existing `admin@gmail.com` administrator.
- Overview metrics and recent orders.
- Product and category management, including images in the existing `royalwood` Storage bucket.
- Order search, delivery-date filters, customer contact, address/map links, status transitions and WhatsApp confirmation through the existing Supabase Edge Function.
- Product pack sizes and shared physical inventory.
- Shop open/closed status, online-order availability and customer-facing closure message.
- Delivery partner list, assignments and live delivery-session visibility via the existing Vercel server route.

## Backend safety contract

This app is a new client only. It must reuse the current Supabase project, existing schema, RLS policies, RPCs, Storage bucket and Edge Functions. It must not create migrations, alter tables/policies, use a service-role key, or embed Firebase service-account credentials.

Firebase Admin operations remain server-side. The current web dashboard's `/api/delivery` route uses cookie-based Supabase auth; a mobile-safe authenticated adapter may be needed for Flutter delivery screens. Do not weaken the route or expose Firebase Admin credentials to the app. Until that adapter is agreed and implemented, delivery admin operations should be shown as unavailable rather than bypassing authorization.

## Configuration

Use `--dart-define` for the public Supabase project URL and publishable key:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://jabzndbdybeeugoypboz.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Only the Supabase publishable/anon key belongs in the client. Never put a service-role key or Firebase service-account JSON in this app.

For admin order push notifications, add the Render realtime service base URL as a compile-time value:

```bash
flutter run \\
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \\
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \\
  --dart-define=ADMIN_PUSH_API_URL=https://YOUR_REALTIME_SERVICE.onrender.com
```

The app initializes Firebase using the Android/iOS app IDs and public client API keys from the Firebase app registrations. It requests notification permission after the existing `admin@gmail.com` Supabase session is available, registers the FCM token with the Render service, shows foreground notifications, and opens the matching order when a notification is tapped. On iOS, enable the **Push Notifications** capability for the Runner target and upload an APNs authentication key in Firebase Console > Project settings > Cloud Messaging. The Render service must be deployed with `FIREBASE_SERVICE_ACCOUNT_JSON` and the default Firestore database enabled in project `sm-delivery-app-10f03`.

## Development

Install Flutter and platform prerequisites using the [official Flutter setup guide](https://docs.flutter.dev/install), then:

```bash
flutter pub get
flutter analyze
flutter run
```

For iOS, use macOS with Xcode configured. Android and iOS are both supported from this codebase.

## Existing web dashboard reference

The feature and data contract source of truth is `syedre/sm-mart-admin-dashboard`. Keep its current production behavior intact while building the Flutter client.
