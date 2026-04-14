#!/bin/bash
set -euo pipefail

INPUT_FILE="${PHS_FILE:?Error: PHS_FILE environment variable is not set}"
# NL_FORMAT controls natural-language output: html | md | both  (default: html)
NL_FORMAT="${NL_FORMAT:-html}"
# GBIF_FLAG: 1 = add -g flag to yphs2owl (queries GBIF API for taxonomy), 0 = skip
GBIF_FLAG="${GBIF_FLAG:-1}"

echo "=== PhenoScript → OWL + Natural Language conversion ==="
echo "Input file : ${INPUT_FILE}"
echo "NL format  : ${NL_FORMAT}"
echo "GBIF flag  : ${GBIF_FLAG}"

# phenospy requires all three files in the same directory:
#   <input>.phs / <input>.yphs
#   phs-config.yaml
#   phs-snippets.json
mkdir -p /app/work

cp "/app/input/${INPUT_FILE}"    /app/work/
cp /app/input/phs-config.yaml    /app/work/
cp /app/snippets/phs-snippets.json /app/work/

echo "Running phenospy yphs2owl..."
# Strip extension to get output basename (e.g. my_species.yphs → my_species)
BASENAME="${INPUT_FILE%.*}"
cd /app/work

# Build yphs2owl command — add -g if GBIF taxonomy enrichment is requested
if [ "${GBIF_FLAG}" = "1" ]; then
    phenospy yphs2owl "${INPUT_FILE}" "../output/${BASENAME}" -g
else
    phenospy yphs2owl "${INPUT_FILE}" "../output/${BASENAME}"
fi

echo "=== OWL written to output/owl_init/ ==="

# --- Natural language conversion ---
OWL_FILE="../output/${BASENAME}.owl"

if [ "${NL_FORMAT}" = "html" ] || [ "${NL_FORMAT}" = "both" ]; then
    echo "Running phenospy owl2text (html)..."
    phenospy owl2text -f 'html' -s '_ORG_*' -o "${OWL_FILE}" -d /app/nl_output
fi

if [ "${NL_FORMAT}" = "md" ] || [ "${NL_FORMAT}" = "both" ]; then
    echo "Running phenospy owl2text (md)..."
    phenospy owl2text -f 'md' -s '_ORG_*' -o "${OWL_FILE}" -d /app/nl_output
fi

echo "=== Done. NL output written to output/nl/ ==="

# --- SHACL validation ---
SHAPES_FILE="/app/utils/phenoscript.shacl.ttl"
LOG_FILE="/app/log-shacl/${BASENAME}.shacl.txt"

if [ -f "${SHAPES_FILE}" ]; then
    echo "Running SHACL validation..."
    mkdir -p /app/log-shacl

    # shacl always exits 0; conformance is indicated by "Conforms" in the output
    shacl validate --text --shapes "${SHAPES_FILE}" --data "../output/${BASENAME}.owl" > "${LOG_FILE}" 2>&1

    if grep -q "^Conforms$" "${LOG_FILE}"; then
        echo "=== SHACL validation: PASSED ==="
    else
        echo "=== SHACL validation: FAILED — see output/log-shacl/${BASENAME}.shacl.txt ==="
    fi
else
    echo "=== SHACL shapes file not found at ${SHAPES_FILE}, skipping validation ==="
fi

echo "=== All done ==="
