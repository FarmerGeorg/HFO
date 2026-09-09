#!/usr/bin/env bash
# Compile report.tex reproducibly: pdflatex -> bibtex -> pdflatex -> pdflatex.
# Run from anywhere; always operates on the report.tex next to this script.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
pwd
REPO_ROOT="$(cd "$(dirname "$(pwd)")/../.." && pwd)"

run() {
    local logfile="$1"
    shift
    if ! "$@" > "$logfile" 2>&1; then
        echo "FAILED: $*" >&2
        tail -n 40 "$logfile" >&2
        exit 1
    fi
}

# Every hardcoded number in report.tex's prose is checked against current
# OpticalCavity/ExampleCavities/ExampleModulationParameters output, and every
# physical quantity's glossary-table introduction is checked for duplicate
# definitions and undocumented forward references -- see the "Report Claim"
# and "Notation Ledger" entries in ../CONTEXT.md. Either kind of drift fails
# the build instead of shipping silently.
run reportclaims.log matlab -batch "openProject('$REPO_ROOT/Matlab.prj'); results = [runtests('ReportClaimsCavityTest'), runtests('ReportClaimsSidebandsTest'), runtests('ReportClaimsPdhTest'), runtests('ReportClaimsDotProductTest')]; notationOk = checkNotationLedger('report.tex'); exit(any([results.Failed]) || ~notationOk)"

run pdflatex1.log pdflatex -interaction=nonstopmode -halt-on-error report.tex

# bibtex exits non-zero (as designed) when report.aux has no \citation commands
# yet -- that's not a build failure, just nothing to look up yet.
if grep -q '^\\citation' report.aux; then
    run bibtex.log bibtex report
    run pdflatex2.log pdflatex -interaction=nonstopmode -halt-on-error report.tex
fi

run pdflatex3.log pdflatex -interaction=nonstopmode -halt-on-error report.tex

rm -f reportclaims.log pdflatex1.log pdflatex2.log pdflatex3.log bibtex.log
echo "Built report.pdf"
