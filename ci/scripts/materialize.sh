#!/bin/bash
# =============================================================================
# materialize.sh — global materialize pipeline (runs once across ALL submissions)
#
# Mounted into the CI container at /app/run.sh and executed via:
#   docker run --entrypoint bash ... /app/run.sh
#
# Expected volume mounts:
#   /app/outputs           — outputs/ dir (all <id>/owl_init/*.owl files)
#   /app/source_ontologies — source_ontologies/  (contains tbox.owl)
#   /app/utils             — ci/utils/       (contains annotate.ru)
#   /app/abox              — abox/  (receives merged + reasoned files)
#   /app/kb                — kb/    (receives insectKG100-kb.ttl)
# =============================================================================
set -euo pipefail

echo "=== Materialize: global pipeline ==="

# ---------------------------------------------------------------------------
# Step 1: Merge all OWL files from all submissions into abox-merged.owl
# OWL files are at /app/outputs/<id>/owl_init/*.owl
# ---------------------------------------------------------------------------
echo "--- Step 1: Merging all OWL files ---"

ROBOT_INPUTS=""
while IFS= read -r f; do
    ROBOT_INPUTS="${ROBOT_INPUTS} --input ${f}"
done < <(find /app/outputs -path "*/owl_init/*.owl" | sort)

if [[ -z "${ROBOT_INPUTS}" ]]; then
    echo "ERROR: No OWL files found in /app/outputs"
    exit 1
fi

# shellcheck disable=SC2086
robot merge ${ROBOT_INPUTS} --output /app/abox/abox-merged.owl
echo "    -> /app/abox/abox-merged.owl"

# ---------------------------------------------------------------------------
# Step 2: Materialize with whelk reasoner
# ---------------------------------------------------------------------------
echo "--- Step 2: Running materializer (whelk) ---"

materializer file \
    --ontology-file /app/source_ontologies/tbox.owl \
    --input /app/abox/abox-merged.owl \
    --output /app/abox/abox-whelk-raw.ttl \
    --reasoner whelk \
    > /app/abox/materializer.log

echo "--- Files in /app/abox after materializer ---"
ls -lh /app/abox/

echo "    -> /app/abox/abox-whelk-raw.ttl"

if grep -q "Inconsistent dataset" /app/abox/materializer.log 2>/dev/null; then
    echo "WARNING: Inconsistent dataset detected — see abox/materializer.log"
else
    echo "    Consistency check: OK"
fi

# ---------------------------------------------------------------------------
# Step 3: Annotate entailed axioms with SPARQL UPDATE
# (note: --data before --update, matching the Makefile pattern)
# ---------------------------------------------------------------------------
echo "--- Step 3: Annotating axioms ---"

update \
    --data /app/abox/abox-whelk-raw.ttl \
    --update /app/utils/annotate.ru \
    --dump \
    > /app/abox/abox-whelk-annotated.ttl

echo "    -> /app/abox/abox-whelk-annotated.ttl"

# ---------------------------------------------------------------------------
# Step 4: Final KB = tbox + abox-merged + entailments (matching Makefile order)
# ---------------------------------------------------------------------------
echo "--- Step 4: Building insectKG100-kb.ttl ---"

riot \
    /app/source_ontologies/tbox.owl \
    /app/abox/abox-merged.owl \
    /app/abox/abox-whelk-annotated.ttl \
    > /app/kb/insectKG100-kb.ttl

echo "    -> /app/kb/insectKG100-kb.ttl"
echo "=== Materialize complete ==="
