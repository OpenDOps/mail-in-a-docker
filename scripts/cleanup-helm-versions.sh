#!/bin/bash
#
# Script to list and delete old Helm chart versions from GitHub Container Registry
# Requires GitHub PAT with 'delete:packages' and 'read:packages' scopes
#
# Usage: ./cleanup-helm-versions.sh <github-token> [keep-versions]
#   github-token: GitHub Personal Access Token (required)
#   keep-versions: Number of latest versions to keep (default: 5)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Show usage if no arguments provided
if [ $# -eq 0 ]; then
  echo -e "${BLUE}Usage:${NC} $0 <github-token> [keep-versions]"
  echo ""
  echo "Arguments:"
  echo "  github-token   GitHub Personal Access Token (required)"
  echo "                 Must have 'delete:packages' and 'read:packages' scopes"
  echo "  keep-versions  Number of latest versions to keep (default: 5)"
  echo ""
  echo "Examples:"
  echo "  $0 ghp_xxxxxxxxxxxxx"
  echo "  $0 ghp_xxxxxxxxxxxxx 10"
  echo ""
  echo "Alternatively, set GITHUB_TOKEN environment variable:"
  echo "  export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx"
  echo "  $0"
  exit 1
fi

# Configuration
ORG="opendops"
PACKAGE_NAME="mail-in-a-pods"

# Get token from argument or environment variable
GITHUB_TOKEN="${1:-${GITHUB_TOKEN:-}}"
if [ -z "$GITHUB_TOKEN" ]; then
  echo -e "${RED}Error:${NC} GitHub token is required"
  echo "Provide it as an argument or set GITHUB_TOKEN environment variable"
  exit 1
fi

# Get keep versions from argument or environment variable (default: 5)
KEEP_VERSIONS="${2:-${KEEP_VERSIONS:-5}}"
if ! [[ "$KEEP_VERSIONS" =~ ^[0-9]+$ ]] || [ "$KEEP_VERSIONS" -lt 1 ]; then
  echo -e "${RED}Error:${NC} keep-versions must be a positive integer"
  exit 1
fi

echo "Fetching package versions for ${ORG}/${PACKAGE_NAME}..."

# List all package versions
VERSIONS_JSON=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/orgs/${ORG}/packages/container/${PACKAGE_NAME}/versions")

# Check for errors
if echo "$VERSIONS_JSON" | grep -q '"message"'; then
  echo -e "${RED}Error:${NC} $(echo "$VERSIONS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('message', 'Unknown error'))")"
  exit 1
fi

# Extract version IDs and tags, sort by created date (newest first)
VERSIONS=$(echo "$VERSIONS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
versions = []
for v in data:
    tags = v.get('metadata', {}).get('container', {}).get('tags', [])
    version_id = v['id']
    created_at = v.get('created_at', '')
    for tag in tags:
        versions.append((created_at, version_id, tag))
# Sort by created_at descending (newest first)
versions.sort(key=lambda x: x[0], reverse=True)
for created, vid, tag in versions:
    print(f'{vid}|{tag}|{created}')
")

# Count total versions
TOTAL_COUNT=$(echo "$VERSIONS" | wc -l | tr -d ' ')
echo -e "${GREEN}Found ${TOTAL_COUNT} versions${NC}"
echo ""

# Display all versions
echo "All versions (newest first):"
echo "$VERSIONS" | nl -w2 -s'. ' | while IFS='|' read -r num id tag created; do
  echo "  $num. Version: $tag (ID: $id, Created: $created)"
done
echo ""

# Calculate versions to delete
VERSIONS_TO_DELETE=$(echo "$VERSIONS" | tail -n +$((KEEP_VERSIONS + 1)))

DELETE_COUNT=$(echo "$VERSIONS_TO_DELETE" | grep -c . || echo "0")

if [ "$DELETE_COUNT" -eq 0 ]; then
  echo -e "${GREEN}No old versions to delete. Keeping all ${TOTAL_COUNT} versions.${NC}"
  exit 0
fi

echo -e "${YELLOW}Versions to delete (keeping latest ${KEEP_VERSIONS}):${NC}"
echo "$VERSIONS_TO_DELETE" | while IFS='|' read -r id tag created; do
  echo "  - $tag (ID: $id)"
done
echo ""

# Ask for confirmation
read -p "Do you want to delete these ${DELETE_COUNT} old versions? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

# Delete versions
DELETED=0
FAILED=0

while IFS='|' read -r id tag created; do
  [ -z "$id" ] && continue  # Skip empty lines

  echo -n "Deleting version $tag (ID: $id)... "

  # Use separate calls to get response and status code
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/orgs/${ORG}/packages/container/${PACKAGE_NAME}/versions/${id}")

  if [ "$HTTP_CODE" = "204" ]; then
    echo -e "${GREEN}✓ Deleted${NC}"
    DELETED=$((DELETED + 1))
  else
    echo -e "${RED}✗ Failed (HTTP $HTTP_CODE)${NC}"
    FAILED=$((FAILED + 1))
  fi

  # Rate limiting: wait a bit between requests
  sleep 0.5
done <<EOF
$VERSIONS_TO_DELETE
EOF

echo ""
echo -e "${GREEN}Cleanup complete!${NC}"
echo "  Deleted: ${DELETED} versions"
echo "  Failed: ${FAILED} versions"
echo "  Kept: ${KEEP_VERSIONS} latest versions"
