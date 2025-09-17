#!/bin/bash
# extract_chinese_natural.sh - Extract Chinese natural translations from processed JSON

# Check input parameters
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_JSON_file> [output_file]"
    echo "Example: $0 tosa-zh.json natural_translations.json"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-natural_translations.json}"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found, please install jq first"
    exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' does not exist"
    exit 1
fi

# Extract Chinese natural translations with metadata
jq '[.[] | {
  title: (.title // null),
  author: (.author // null),
  translations: [.paragraph[]? | {
    id: (.id // null),
    original: (."koutei-yamagen" // null),
    literal: (."translation-zh" // null),
    natural: (."translation-zh-natural" // null)
  } | select(.natural != null)]
}]' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Natural translation extraction completed, results saved to: $OUTPUT_FILE"
