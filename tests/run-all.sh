#!/usr/bin/env bash
# signet-first skill — fixture-based test runner
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   signet-first skill test suite      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

test_files=()
for f in "$TESTS_DIR"/test-*.sh; do
    [ -f "$f" ] || continue
    [[ "$(basename "$f")" == "test-helpers.sh" ]] && continue
    [[ "$(basename "$f")" == "test-install-docker.sh" ]] && continue
    test_files+=("$f")
done

if [ "${#test_files[@]}" -eq 0 ]; then
    echo -e "${RED}No test files found in $TESTS_DIR${NC}"
    exit 1
fi

echo -e "Found ${BOLD}${#test_files[@]}${NC} test suites."
echo ""

suite_pass=0
suite_fail=0
suite_results=()

for f in "${test_files[@]}"; do
    suite_name=$(basename "$f" .sh)
    echo -e "${BOLD}▶ ${suite_name}${NC}"
    echo ""

    if bash "$f"; then
        suite_pass=$((suite_pass + 1))
        suite_results+=("${GREEN}PASS${NC}  $suite_name")
    else
        suite_fail=$((suite_fail + 1))
        suite_results+=("${RED}FAIL${NC}  $suite_name")
    fi

    echo ""
done

echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        Aggregate Results             ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════╣${NC}"
for r in "${suite_results[@]}"; do
    echo -e "║  $r"
done
echo -e "${BOLD}╠══════════════════════════════════════╣${NC}"
echo -e "║  Suites: $((suite_pass + suite_fail))  ${GREEN}Pass: ${suite_pass}${NC}  ${RED}Fail: ${suite_fail}${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"

if [ "$suite_fail" -gt 0 ]; then
    echo -e "${RED}OVERALL: FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}OVERALL: PASSED${NC}"
    exit 0
fi
