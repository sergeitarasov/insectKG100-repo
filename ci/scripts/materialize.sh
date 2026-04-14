#!/bin/bash
# =============================================================================
# materialize.sh — per-submission materialize pipeline
#
# Mounted into the CI container at /app/run.sh and executed via:
#   docker run --entrypoint bash ... /app/run.sh
#
# Expected volume mounts:
#   /app/owl_input         — outputs/<id>/   (contains <basename>/<basename>.owl)
#   /app/source_ontologies — source_ontologies/  (contains tbox.owl)
#   /app/utils             — ci/utils/       (contains annotate.ru)
#   /app/abox              — outputs/<id>/abox/
#   /app/kb                — outputs/<id>/kb/
#
# Required env vars:
#   SUBMISSION_ID          — submission folder name (used as KB filename prefix)
# =============================================================================
set -euo pipefail

NAME="${SUBMISSION_ID:?Error: SUBMISSION_ID env var is not set}"

echo "=== Materialize: ${NAME} ==="

# ---------------------------------------------------------------------------
# Step 1: Merge all per-yphs OWL files into a single abox-merged.owl
# OWL files are at /app/owl_input/<yphs-basename>/<yphs-basename>.owl
# ---------------------------------------------------------------------------
echo "--- Step 1: Merging OWL files ---"

ROBOT_INPUTS=""
while IFS= read -r f; do
    ROBOT_INPUTS="${ROBOT_INPUTS} --input ${f}"
done < <(find /app/owl_input -maxdepth 2 -name "*.owl" | sort)

if [[ -z "${ROBOT_INPUTS}" ]]; then
    echo "ERROR: No OWL files found in /app/owl_input"
    exit 1
fi

# shellcheck disable=SC2086
robot merge ${ROBOT_INPUTS} --output /app/abox/abox-merged.owl
echo "    → /app/abox/abox-merged.owl"

# ---------------------------------------------------------------------------
# Step 2: Materialize with whelk reasoner
# ---------------------------------------------------------------------------
echo "--- Step 2: Running materializer (whelk) ---"

materializer file \
    /app/abox/abox-merged.owl \
    /app/source_ontologies/tbox.owl \
    --reasoner whelk \
    --output /app/abox/abox-whelk-raw.ttl \
    > /app/abox/materializer.log 2>&1

echo "    → /app/abox/abox-whelk-raw.ttl"

if grep -q "Inconsistent dataset" /app/abox/materializer.log; then
    echo "WARNING: Inconsistent dataset detected in ${NAME} — see abox/materializer.log"
else
    echo "    Consistency check: OK"
fi

# ---------------------------------------------------------------------------
# Step 3: Annotate entailed axioms with SPARQL UPDATE
# ---------------------------------------------------------------------------
echo "--- Step 3: Annotating axioms ---"

update \
    --update /app/utils/annotate.ru \
    --data /app/abox/abox-whelk-raw.ttl \
    --dump \
    > /app/abox/abox-whelk-annotated.ttl

echo "    → /app/abox/abox-whelk-annotated.ttl"

# ---------------------------------------------------------------------------
# Step 4: Build submission KB (merged OWL + entailments + TBox → single TTL)
# ---------------------------------------------------------------------------
echo "--- Step 4: Building submission KB ---"

riot \
    /app/abox/abox-merged.owl \
    /app/abox/abox-whelk-annotated.ttl \
    /app/source_ontologies/tbox.owl \
    > /app/kb/"${NAME}-kb.ttl"

echo "    → /app/kb/${NAME}-kb.ttl"
echo "=== Materialize complete: ${NAME} ==="
