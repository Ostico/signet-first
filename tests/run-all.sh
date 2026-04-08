#!/usr/bin/env bash
# signet-first skill — test runner
# Runs all test-*.sh files and reports aggregate results.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   signet-first skill test suite      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

# Pre-flight (source helpers just for the check, don't pollute globals)
(
    source "$TESTS_DIR/test-helpers.sh"
    preflight_check
) || exit 1

# Discover test files
test_files=()
for f in "$TESTS_DIR"/test-*.sh; do
    [ -f "$f" ] && test_files+=("$f")
done

if [ "${#test_files[@]}" -eq 0 ]; then
    echo -e "${RED}No test files found in $TESTS_DIR${NC}"
    exit 1
fi

echo -e "Found ${BOLD}${#test_files[@]}${NC} test suites."
echo ""

# Run each suite in a subshell to isolate counters
suite_pass=0
suite_fail=0
suite_results=()

for f in "${test_files[@]}"; do
    suite_name=$(basename "$f" .sh)
    echo -e "${BOLD}▶ Running: ${suite_name}${NC}"
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

# Aggregate summary
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
