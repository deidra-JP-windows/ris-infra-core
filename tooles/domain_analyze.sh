#!/bin/sh
# Usage: sh domain_analyze.sh <domain_or_ip>

if [ $# -lt 1 ]; then
  echo "Usage: sh domain_analyze.sh <domain_or_ip>"
  exit 1
fi
TARGET="$1"

# ping
printf '\n--- ping result ---\n'
ping -c 3 "$TARGET" 2>&1 || ping -n 3 "$TARGET" 2>&1

# dig or nslookup
if command -v dig >/dev/null 2>&1; then
  printf '\n--- dig result ---\n'
  dig "$TARGET"
else
  printf '\n--- nslookup result ---\n'
  nslookup "$TARGET"
fi

# openssl cert chain
printf '\n--- SSL certificate chain ---\n'
echo | openssl s_client -showcerts -connect "$TARGET:443" 2>/dev/null
