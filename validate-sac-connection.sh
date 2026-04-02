#!/bin/bash
# SAC Connection Validator
# Run this locally before rotating your OAuth secret

SAC_BASE_URL="https://itelligencegroup-2.eu10.hanacloudservices.cloud.sap"
TOKEN_URL="https://itelligencegroup-2.authentication.eu10.hana.ondemand.com/oauth/token"
CLIENT_ID="${SAC_CLIENT_ID}"
CLIENT_SECRET="${SAC_CLIENT_SECRET}"

echo "=== SAC Connection Validator ==="
echo "Tenant: $SAC_BASE_URL"
echo ""

# Step 1: Get OAuth token
echo "Step 1: Requesting OAuth token..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

if [ "$HTTP_CODE" != "200" ]; then
  echo "FAILED: Token request returned HTTP $HTTP_CODE"
  echo "Response: $BODY"
  exit 1
fi

TOKEN=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "FAILED: Could not extract access_token from response"
  echo "Response: $BODY"
  exit 1
fi

echo "OK: Token obtained (${#TOKEN} chars)"
echo ""

# Step 2: List stories
echo "Step 2: Listing stories..."
STORIES=$(curl -s -w "\n%{http_code}" \
  "$SAC_BASE_URL/api/v1/stories" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json")

HTTP_CODE=$(echo "$STORIES" | tail -1)
BODY=$(echo "$STORIES" | head -1)

if [ "$HTTP_CODE" == "200" ]; then
  COUNT=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('value', d.get('stories', []))))" 2>/dev/null || echo "?")
  echo "OK: Stories endpoint reachable ($COUNT stories found)"
else
  echo "WARN: Stories returned HTTP $HTTP_CODE (may need different scope)"
fi
echo ""

# Step 3: List planning models
echo "Step 3: Listing planning models..."
MODELS=$(curl -s -w "\n%{http_code}" \
  "$SAC_BASE_URL/api/v1/dataimport/models" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json")

HTTP_CODE=$(echo "$MODELS" | tail -1)
BODY=$(echo "$MODELS" | head -1)

if [ "$HTTP_CODE" == "200" ]; then
  COUNT=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('value', [])))" 2>/dev/null || echo "?")
  echo "OK: Models endpoint reachable ($COUNT models found)"
else
  echo "WARN: Models returned HTTP $HTTP_CODE"
  echo "Response: $BODY"
fi
echo ""

echo "=== Validation complete. If all steps show OK, rotate your secret. ==="
