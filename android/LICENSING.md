# Android club licensing

The Android app implements the same club-access contract as the iPhone app. SYC holds the licence;
members activate with a club invitation and do not create an account, make a payment, or provide an
email address.

## Configuration

The release configuration is compiled through `BuildConfig` in `app/build.gradle.kts`:

- `LICENSING_API_ENDPOINT` — Railway HTTPS service URL;
- `LICENSING_KEY_ID` — identifier in signed entitlement payloads;
- `LICENSING_PUBLIC_KEY_BASE64` — raw 32-byte Ed25519 public key.

Only the public verification key belongs in the app. The private signing key and invitation/refresh
HMAC secrets remain Railway service variables.

## Activation and local trust

1. A fresh installation creates a random installation UUID protected by Android Keystore.
2. The app sends the club invitation, installation UUID, version and `android` platform to
   `POST /v1/activations`.
3. The app verifies the returned Ed25519 signature over the exact decoded payload bytes.
4. Verification binds access to the installation UUID, permitted bundled pack, key ID, entitlement
   type and commercial dates.
5. The signed envelope is written atomically below `noBackupFilesDir`; the opaque refresh credential
   is AES-GCM encrypted with a non-exportable Android Keystore key.

Licensing files and encrypted preferences are excluded from cloud backup and device transfer. A
restored entitlement therefore cannot silently move club access to a different installation.

## Offline, refresh and legacy behavior

Valid signed access is evaluated locally at launch. Railway is not required on every launch.
Refresh-due, grace and expired states retain the bundled reference information with an appropriate
warning; update eligibility follows the same policy as iPhone. Refresh failure uses exponential
backoff from 15 minutes to 24 hours and never treats an outage as proof of licence expiry.

An installation upgraded from the previous freely accessible Android release receives legacy
access to the bundled SYC snapshot. A genuinely fresh installation has no universal-code path and
must use a current club invitation.

## Build and verification

The server must include `android` in its allowed activation platforms before testing a deployed
Android build. After deploying that server change:

```bash
cd android
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ./gradlew testDebugUnitTest assembleDebug
```

Tests cover the server-compatible Ed25519 wire format, tampering, installation/pack binding,
refresh/expiry/grace boundaries, persistent random installation identity, existing course models,
navigation and NMEA behavior. Test activation on a fresh emulator and a physical Android device,
then confirm aggregate installation counts through the Railway administration command.
