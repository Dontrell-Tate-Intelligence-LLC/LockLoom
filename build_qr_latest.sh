#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
# build_qr_latest.sh — One-and-done QR builder for DO provisioning
#
# Usage:
#   ./build_qr_latest.sh
#   (Optionally override config via env vars)
#
# Outputs:
#   ./dist/lockloom-dpc.apk
#   ./dist/qr_provisioning.json
#   ./dist/qr_provisioning.png
#
# Requirements:
#   - Public GitHub release with asset named $ASSET_NAME
#   - Tools: curl, keytool (Java), python3 (+ pip). Script will try to
#            pip-install qrcode[pil] if it’s missing.
# =====================================================================

# ----- CONFIG (override via env if you like) --------------------------
OWNER="${OWNER:-Dontrell-Tate-Intelligence-LLC}"
REPO="${REPO:-LockLoom}"
ASSET_NAME="${ASSET_NAME:-lockloom-dpc.apk}"   # keep constant per release
COMPONENT_NAME="${COMPONENT_NAME:-com.lockloom.dpc/.DeviceAdminReceiver}"
SKIP_USER_SETUP="${SKIP_USER_SETUP:-false}"     # "true" or "false" (no quotes in JSON)
OUT_DIR="${OUT_DIR:-./dist}"
APK_LOCAL="${OUT_DIR}/${ASSET_NAME}"
QR_JSON="${OUT_DIR}/qr_provisioning.json"
QR_PNG="${OUT_DIR}/qr_provisioning.png"
# ---------------------------------------------------------------------

LATEST_URL="https://github.com/${OWNER}/${REPO}/releases/latest/download/${ASSET_NAME}"

fail() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: $1"; }

need curl
need keytool
need python3

mkdir -p "$OUT_DIR"

echo "==> Stable /latest/ URL:"
echo "    $LATEST_URL"
echo

echo "==> Downloading latest APK"
curl -fL --retry 3 --retry-delay 2 -o "$APK_LOCAL" "$LATEST_URL" ||       fail "Could not download $LATEST_URL (is the repo public and asset named ${ASSET_NAME}?)"

BYTES=$(wc -c < "$APK_LOCAL")
echo "    Downloaded ${BYTES} bytes."
(( BYTES >= 100000 )) || fail "APK looks too small (${BYTES} bytes). Re-upload a real signed APK named ${ASSET_NAME}."

echo "==> Extracting signing certificate SHA-256 (hex) with keytool"
HEX=$(keytool -printcert -jarfile "$APK_LOCAL" | awk '/SHA256:/{print $2}') || true
[ -n "${HEX:-}" ] || fail "keytool did not output SHA256. Is the APK valid and Java installed?"

echo "==> Converting to base64url (no padding) for SIGNATURE_CHECKSUM"
CHECKSUM=$(python3 - <<'PY' "$HEX"
import sys, base64, binascii
h=sys.argv[1].strip().replace(':','')
b=binascii.unhexlify(h)
print(base64.urlsafe_b64encode(b).decode().rstrip('='))
PY
) || fail "Failed to compute checksum"

echo "==> Writing QR JSON to: ${QR_JSON}"
cat > "$QR_JSON" <<JSON
{
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME": "${COMPONENT_NAME}",
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_DOWNLOAD_LOCATION": "${LATEST_URL}",
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_SIGNATURE_CHECKSUM": "${CHECKSUM}",
  "android.app.extra.PROVISIONING_SKIP_USER_SETUP": ${SKIP_USER_SETUP}
}
JSON

echo
echo "==> QR JSON contents:"
cat "$QR_JSON"
echo

echo "==> Generating QR PNG (python qrcode, auto-install if missing)"
python3 - <<'PY' "$QR_JSON" "$QR_PNG"
import sys, json, subprocess
from pathlib import Path

qr_json = Path(sys.argv[1]); out_png = Path(sys.argv[2])

try:
    import qrcode
except ModuleNotFoundError:
    print("   qrcode not found; installing: python -m pip install --user qrcode[pil]")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "qrcode[pil]"])
    import qrcode

data = qr_json.read_text(encoding="utf-8")
json.loads(data)  # sanity
img = qrcode.make(data)
out_png.parent.mkdir(parents=True, exist_ok=True)
img.save(out_png)
print(f"   Wrote {out_png}")
PY

echo
echo "==> Header check for /latest/ URL (final should be 200 with multi-MB Content-Length):"
curl -I -L "$LATEST_URL" || true

echo
echo "DONE."
echo "Artifacts:"
echo "  APK:   $APK_LOCAL"
echo "  JSON:  $QR_JSON"
echo "  PNG:   $QR_PNG"
