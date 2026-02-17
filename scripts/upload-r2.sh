#!/bin/bash
set -euo pipefail

# Upload large files to R2 via Worker multipart upload API
# Usage: ./scripts/upload-r2.sh <file-path> <r2-filename>
# Example: ./scripts/upload-r2.sh releases/LoopMaker-1.0.0.dmg LoopMaker-1.0.0.dmg

FILE_PATH="${1:?Usage: upload-r2.sh <file-path> <r2-filename>}"
R2_FILENAME="${2:?Usage: upload-r2.sh <file-path> <r2-filename>}"

UPDATES_URL="${UPDATES_URL:-https://loopmaker-updates.tarunyadav9761.workers.dev}"
ADMIN_SECRET="${LOOPMAKER_ADMIN_SECRET:?Set LOOPMAKER_ADMIN_SECRET}"
CHUNK_SIZE=$((95 * 1024 * 1024)) # 95 MB per part (under Workers 100MB limit)

FILE_SIZE=$(stat -f%z "$FILE_PATH")
TOTAL_PARTS=$(( (FILE_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE ))

echo "[*] Uploading $R2_FILENAME ($FILE_SIZE bytes) in $TOTAL_PARTS parts..."

# Step 1: Init multipart upload
echo "[*] Initializing multipart upload..."
INIT_RESPONSE=$(curl -sf "$UPDATES_URL/admin/upload/init" \
  -H "Authorization: Bearer $ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d "{\"filename\": \"$R2_FILENAME\"}")

UPLOAD_ID=$(echo "$INIT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['uploadId'])")
KEY=$(echo "$INIT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['key'])")
echo "  Upload ID: $UPLOAD_ID"

# Step 2: Upload parts
PARTS="["
for ((i = 1; i <= TOTAL_PARTS; i++)); do
  OFFSET=$(( (i - 1) * CHUNK_SIZE ))
  echo -n "[*] Uploading part $i/$TOTAL_PARTS..."

  PART_RESPONSE=$(dd if="$FILE_PATH" bs=$CHUNK_SIZE skip=$((i - 1)) count=1 2>/dev/null | \
    curl -sf -X PUT \
      "$UPDATES_URL/admin/upload/part?uploadId=$UPLOAD_ID&key=$KEY&partNumber=$i" \
      -H "Authorization: Bearer $ADMIN_SECRET" \
      -H "Content-Type: application/octet-stream" \
      --data-binary @-)

  PART_NUM=$(echo "$PART_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['partNumber'])")
  PART_ETAG=$(echo "$PART_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['etag'])")

  if [ $i -gt 1 ]; then PARTS="$PARTS,"; fi
  PARTS="$PARTS{\"partNumber\":$PART_NUM,\"etag\":\"$PART_ETAG\"}"
  echo " done (etag: $PART_ETAG)"
done
PARTS="$PARTS]"

# Step 3: Complete multipart upload
echo "[*] Completing multipart upload..."
COMPLETE_RESPONSE=$(curl -sf "$UPDATES_URL/admin/upload/complete" \
  -H "Authorization: Bearer $ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d "{\"uploadId\":\"$UPLOAD_ID\",\"key\":\"$KEY\",\"parts\":$PARTS}")

echo "$COMPLETE_RESPONSE" | python3 -m json.tool
echo "[*] Upload complete! File available at: $UPDATES_URL/releases/$R2_FILENAME"
