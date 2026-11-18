# Dr Hair Flutter app

## Run against the local API

Start the Express backend on port `5001`, then choose a URL reachable from the device:

```bash
# Flutter web or iOS simulator
flutter run -d chrome --dart-define=DRHAIR_BACKEND_URL=http://localhost:5001

# Android emulator
flutter run --dart-define=DRHAIR_BACKEND_URL=http://10.0.2.2:5001
```

For a physical device, use the computer's LAN address and allow that origin in backend `CORS_ORIGINS`. Production uses `https://api.drhairindia.com` by default; `DRHAIR_BACKEND_URL` remains available for explicit build-time overrides.

## API documentation

The canonical OpenAPI contract is in `../backend/docs/openapi.yaml` and is served by the backend at `/api/openapi.yaml` (interactive docs: `/api/docs`). Flutter integration notes are in [API_DOCUMENTATION.md](./API_DOCUMENTATION.md).

OTP verification returns the registered profile in the same response; restoring a session returns the profile in one request. Standalone media uses the authenticated `POST /api/v1/media/upload` endpoint for up to ten images. Hair assessments keep answers and image paths in Hive, preserve originals in app-private storage, and submit answers plus original/optimized photo files together as one multipart `/hair-tests/submit_form` request. The backend streams photos directly to private R2 and returns the saved assessment result in the same response when AI generation succeeds or uses its fallback.

For real OTP testing on a USB-connected Android device, configure `FAST2SMS_API_KEY` in the backend environment, run the backend with `PORT=5127 npm start`, run `adb reverse tcp:5127 tcp:5127`, then launch Flutter with `--dart-define=DRHAIR_BACKEND_URL=http://localhost:5127`. Debug Android builds allow cleartext traffic to `localhost` only; release builds keep the normal HTTPS-only policy. OTPs are delivered by Fast2SMS in every environment and are never returned by the API.
