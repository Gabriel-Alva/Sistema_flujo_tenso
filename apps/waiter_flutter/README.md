# Chifa Sipán · Waiter app

The API base URL is provided at build/run time with `--dart-define=API_BASE=...`.
Use the address for the target device:

```powershell
flutter run -d edge --web-port=5174 --dart-define=API_BASE=http://127.0.0.1:8000/api/v1
flutter run -d windows --dart-define=API_BASE=http://127.0.0.1:8000/api/v1
flutter run -d <android-device-id> --dart-define=API_BASE=http://10.0.2.2:8000/api/v1
```

The defaults are `http://127.0.0.1:8000/api/v1` for Edge/Windows and
`http://10.0.2.2:8000/api/v1` for Android Emulator. The Android emulator host
address is rewritten to `127.0.0.1` when mistakenly supplied to Edge/Windows.
For local Flutter Web development, CORS permits localhost origins on arbitrary
ports only when `APP_ENV=local`; production still requires an explicitly
configured `CORS_ALLOWED_ORIGINS`.

Authentication tokens and queued order requests are stored with
`flutter_secure_storage`. Orders submitted without a network response are kept
on-device with their original `client_request_id` and can be retried from the
catalog screen; API-rejected orders remain queued and show the server error.

The login's **Recordarme en este dispositivo** option is off by default. When
enabled, it stores the username and password using `flutter_secure_storage`;
turning it off removes the saved credentials. The Chifa Sipán logo is used for
the login, browser favicon, PWA, and native launcher icons.

## Waiter workflows

- Browse the product catalog, inspect product images and details, choose an
  active variant, add item notes, and preview the order before submitting it.
- Open orders for available tables or create delivery orders for existing
  customers with a registered address. Customer/address management is not part
  of this app.
- Track order rounds, preparation times, delivery address, and payment history;
  payment collection remains a Cashier responsibility.
- Review order history and the waiter profile. Cancellation is limited to the
  waiter's own open orders that have no items in preparation or issued/payment
  activity; a reason is required.

The backend routines for delivery-customer search, payment history, and order
cancellation must be installed from `backend/database/schema/030_procedures.sql`
with the configured database administrator account before these workflows can
be used against an existing database.

TLS certificate pinning is intentionally not configured: no production
certificate pin has been supplied. Configure a verified production pin before
adding pinning; do not ship a guessed or development certificate pin.
