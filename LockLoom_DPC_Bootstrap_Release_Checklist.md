# LockLoom DPC Bootstrap — Release Checklist

> Goal: cut a new **Device Owner bootstrap APK** and publish it at a **stable URL** that always points to the latest file.

**Stable download URL (never changes):**
```
https://github.com/Dontrell-Tate-Intelligence-LLC/LockLoom/releases/latest/download/lockloom-dpc.apk
```

> Keep signing with the **same keystore** so your provisioning **SIGNATURE_CHECKSUM** stays valid.

---

## 0) Preconditions

- Android Studio builds clean (CI or local).
- Keystore available (same one used previously).
- Package: `com.lockloom.dpc`  
- Receiver class: `.DeviceAdminReceiver`

---

## 1) Build (Release)

**Android Studio:**  
`Build → Generate Signed Bundle / APK → APK → release → (select keystore) → Finish`

**OR CLI:**
```bash
./gradlew clean assembleRelease
cp app/build/outputs/apk/release/app-release.apk lockloom-dpc.apk
```

---

## 2) Sign (already handled if you used the wizard)

If you built unsigned (rare), sign it now with your upload key:
```bash
# Example using apksigner (Android SDK build-tools on PATH)
apksigner sign --ks /path/to/upload-keystore.jks   --ks-key-alias upload   --out lockloom-dpc.apk   app-release-unsigned.apk
```

---

## 3) Upload to GitHub Releases (asset name must be **lockloom-dpc.apk**)

### Web UI (simple)
1. Open the **latest** release (or create a new one for this tag).
2. **Delete** any existing `lockloom-dpc.apk`.
3. **Upload** the new `lockloom-dpc.apk`.
4. **Update release**.

### GitHub CLI (repeatable)
```bash
# one-time auth
gh auth login

# tag for this release (example)
TAG=v0.1.4

# upload/replace asset with constant name
gh release upload "$TAG" lockloom-dpc.apk --clobber
```

---

## 4) Verify headers (the URL must serve a real APK, not 10 bytes)

```bash
curl -I -L "https://github.com/Dontrell-Tate-Intelligence-LLC/LockLoom/releases/latest/download/lockloom-dpc.apk"
```

**Expect:**
- Final status: `HTTP/2 200`
- `Content-Type: application/vnd.android.package-archive` (or `application/octet-stream`)
- **Content-Length: (MBs)** — not `10`

(Optional deep check):
```bash
curl -L -o /tmp/lockloom-dpc.apk "https://github.com/Dontrell-Tate-Intelligence-LLC/LockLoom/releases/latest/download/lockloom-dpc.apk"
unzip -l /tmp/lockloom-dpc.apk | head
```

---

## 5) (One-time) Provisioning checksum (only if signing key changed)

> **Do not** redo this every release if you kept the same keystore. The checksum is the **signing certificate SHA-256** in **base64url (no padding)**.

```bash
HEX=$(keytool -printcert -jarfile lockloom-dpc.apk | awk '/SHA256:/{print $2}')
python3 - <<'PY' "$HEX"
import sys, base64, binascii
h=sys.argv[1].strip().replace(':','')
b=binascii.unhexlify(h)
print(base64.urlsafe_b64encode(b).decode().rstrip('='))
PY
```

Update your QR JSON **only** if the key rotated.

---

## 6) Smoke test provisioning URL (optional but smart)

- Scan the QR containing:
  - `…DOWNLOAD_LOCATION` = `releases/latest/download/lockloom-dpc.apk`
  - `…SIGNATURE_CHECKSUM` = (from step 5, unchanged if same key)
- Ensure device downloads, verifies, installs, and becomes **Device Owner**.
- Confirm **BounceActivity** opens Play to `com.lockloom.android`.

---

## 7) Release notes (internal)

- Short note in the release body: “Bootstrap DPC updated. Asset name stable: `lockloom-dpc.apk`.”
- Link to this checklist.

---

## Troubleshooting

- **200 OK but Content-Length: 10** → wrong asset uploaded; re-upload real APK.  
- **Signature mismatch in provisioning** → recompute checksum **after signing**; must be **base64url** (no `=`).  
- **Provisioning can’t download** → network/captive portal or URL typo; test with `curl -I -L`.

---

**Done.** Your QR keeps working across versions because the URL and signing key stay stable.
