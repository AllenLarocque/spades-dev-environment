#!/bin/bash
# Runtime firewall smoke test — run INSIDE the container after init-firewall.sh.
#   bash .devcontainer/test-firewall.sh
# Confirms the default-deny firewall blocks the outside world while the
# dnsmasq-driven dynamic allowlist lets the R package hosts (CRAN on rotating
# CloudFront IPs, Bioconductor, the r-universes) and GitHub through.
set -uo pipefail
fail=0

check_blocked() {
    if curl --connect-timeout 5 -s "$1" >/dev/null 2>&1; then
        echo "FAIL: $1 was reachable but should be BLOCKED"; fail=1
    else
        echo "OK:   $1 blocked as expected"
    fi
}
check_allowed() {
    if curl --connect-timeout 8 -sSf "$1" >/dev/null 2>&1; then
        echo "OK:   $1 reachable as expected"
    else
        echo "FAIL: $1 was blocked but should be ALLOWED"; fail=1
    fi
}

check_blocked  https://example.com
check_allowed  https://api.github.com/zen
check_allowed  https://cloud.r-project.org/src/contrib/PACKAGES.gz
check_allowed  https://bioc.r-universe.dev/src/contrib/PACKAGES.gz
check_allowed  https://predictiveecology.r-universe.dev/src/contrib/PACKAGES.gz

if [ "$fail" -ne 0 ]; then echo "FIREWALL TEST: FAILURES"; exit 1; fi
echo "FIREWALL TEST: ALL PASSED"
