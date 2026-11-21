# Dr Hair Flutter app

## Run against the local API

Start the backend with `cd ../backend && npm run dev`. This runs Wrangler on port `8787` in the isolated testing environment, using the testing D1/R2/KV resources and the Shiprocket simulator.

```bash
# USB-connected Android device; reverse forwards device localhost to this computer
adb reverse tcp:8787 tcp:8787
flutter run --dart-define=APP_ENV=testing

# Android emulator (the same reverse tunnel can be used)
adb reverse tcp:8787 tcp:8787
flutter run --dart-define=APP_ENV=testing
```

Testing builds load the bundled `assets/env.testing` file. To target a deployed testing Worker instead of local Wrangler, override it with `--dart-define=DRHAIR_BACKEND_URL=https://<testing-worker>.workers.dev`. Production builds continue to use the configured `.env` or `https://api.drhairindia.com` fallback; `DRHAIR_BACKEND_URL` remains available for explicit build-time overrides.

## API documentation

The canonical OpenAPI contract is in `../backend/docs/openapi.yaml` and is served by the backend at `/api/openapi.yaml` (interactive docs: `/api/docs`). Flutter integration notes are in [API_DOCUMENTATION.md](./API_DOCUMENTATION.md).

OTP verification returns the registered profile in the same response; restoring a session returns the profile in one request. Profile photos and progress-check-in photos travel with their domain save request as multipart form data, so each save uses one API call. Hair assessments keep answers and image paths in Hive, preserve originals in app-private storage, and submit answers plus original/optimized photo files together as one multipart `/hair-tests/submit_form` request. The backend streams photos directly to private R2 and returns the saved assessment result in the same response when AI generation succeeds or uses its fallback.

For real OTP testing on a USB-connected Android device, configure `FAST2SMS_API_KEY` in the backend environment, run the backend with `PORT=5127 npm start`, run `adb reverse tcp:5127 tcp:5127`, then launch Flutter with `--dart-define=DRHAIR_BACKEND_URL=http://localhost:5127`. Debug Android builds allow cleartext traffic to `localhost` only; release builds keep the normal HTTPS-only policy. OTPs are delivered by Fast2SMS in every environment and are never returned by the API.
