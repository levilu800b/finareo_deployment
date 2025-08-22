#!/bin/bash

echo "=== Testing SEO Endpoints ==="
echo "Date: $(date)"
echo

echo "1. Testing /sitemap.xml"
echo "Headers:"
curl -I https://livelens.space/sitemap.xml 2>/dev/null | head -10
echo -e "\nFirst 200 chars of content:"
curl -s https://livelens.space/sitemap.xml | head -c 200
echo -e "\n\n"

echo "2. Testing /robots.txt"
echo "Headers:"
curl -I https://livelens.space/robots.txt 2>/dev/null | head -10
echo -e "\nContent:"
curl -s https://livelens.space/robots.txt
echo -e "\n\n"

echo "3. Testing /seo-health/"
echo "Headers:"
curl -I https://livelens.space/seo-health/ 2>/dev/null | head -10
echo -e "\nContent:"
curl -s https://livelens.space/seo-health/
echo -e "\n\n"

echo "4. Testing backend API health (should work)"
echo "Content:"
curl -s https://livelens.space/api/health/ | head -c 200
echo -e "\n\n"

echo "=== End Test ==="
