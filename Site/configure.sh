#!/bin/zsh
# Fills in the domain and support address before deploying.
# Usage: ./configure.sh jeweljuggler.example support@jeweljuggler.example
set -e
cd "$(dirname "$0")"
[[ -n "$1" && -n "$2" ]] || { echo "usage: $0 <domain> <support-email>"; exit 1; }
sed -i '' "s/{{DOMAIN}}/$1/g; s/{{SUPPORT_EMAIL}}/$2/g" index.html
echo "index.html now uses $1 and $2"
