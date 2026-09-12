#!/usr/bin/env bash
# Verify the Qwen credentials and model the app is built with actually answer.
#
#   scripts/check_qwen.sh                      # key from build_documents/qwen_api.txt
#   QWEN_API_KEY=... scripts/check_qwen.sh     # or from the environment
#
# Overridable: QWEN_API_BASE_URL, QWEN_MODEL — keep these in step with the
# defaults in app/lib/main.dart.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
key_file="$repo_root/build_documents/qwen_api.txt"

key=${QWEN_API_KEY:-}
if [ -z "$key" ] && [ -f "$key_file" ]; then
  key=$(tr -d '\r\n' < "$key_file")
fi
if [ -z "$key" ]; then
  echo "No key: set QWEN_API_KEY or put one in $key_file" >&2
  exit 2
fi

base_url=${QWEN_API_BASE_URL:-https://api-inference.modelscope.cn/v1}
model=${QWEN_MODEL:-Qwen/Qwen2.5-72B-Instruct}

echo "endpoint: $base_url"
echo "model:    $model"
echo "key:      ${key:0:3}…(${#key} chars)"

body=$(cat <<JSON
{"model": "$model", "messages": [
  {"role": "system", "content": "Reply with ONLY a JSON object: {\"origin\": string|null, \"destination\": string|null, \"intent\": \"route\"|\"fare\"|\"other\"}."},
  {"role": "user", "content": "how do I get from uni town to saddar"}
]}
JSON
)

response=$(mktemp)
trap 'rm -f "$response"' EXIT
# curl already writes 000 on a connection failure; don't append another.
set +e
status=$(curl -sS -m 90 -o "$response" -w '%{http_code}' \
  "$base_url/chat/completions" \
  -H "Authorization: Bearer $key" \
  -H 'Content-Type: application/json' \
  --data "$body" 2>/dev/null)
set -e
status=${status:-000}

if [ "$status" = "000" ]; then
  echo "FAIL: could not reach $base_url (no response)." >&2
  echo "      The host may be blocked on this network — try another connection." >&2
  exit 1
fi
if [ "$status" != "200" ]; then
  echo "FAIL: HTTP $status" >&2
  head -c 600 "$response" >&2
  echo >&2
  exit 1
fi

python3 - "$response" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
content = data["choices"][0]["message"]["content"]
print("reply:   ", content.strip().replace("\n", " ")[:200])
start, end = content.find("{"), content.rfind("}")
parsed = json.loads(content[start:end + 1])
print("parsed:  ", parsed)
assert "origin" in parsed and "destination" in parsed, "missing origin/destination"
print("OK: the key, endpoint and model all work.")
PY
