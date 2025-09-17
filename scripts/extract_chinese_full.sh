#!/bin/bash
# extract_chinese_full.sh - Extract Chinese annotations from Japanese classical literature

# Check input parameters
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_JSON_file> [output_file]"
    echo "Example: $0 tosa_nikki.json output.json"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-extracted_chinese.json}"

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

# Execute jq extraction with null fallback for missing fields
jq '[.[] | {
  title: (.title // null),
  author: (.author // null),
  paragraph: [.paragraph[]? | {
    id: (.id // null),
    "koutei-yamagen": (."koutei-yamagen" // null),
    "translation-zh": (."translation-zh" // null),
    "phrase-gloss": (if ."phrase-gloss" then [."phrase-gloss"[] | {
      phrase: (.phrase // null),
      "gloss-zh": (."gloss-zh" // null),
      "gloss-morph-zh": (."gloss-morph-zh" // null),
      words: (if .words then [.words[] | {
        word: (.word // null),
        "gloss-zh": (."gloss-zh" // null),
        "gloss-morph-zh": (."gloss-morph-zh" // null)
      }] else null end)
    }] else null end),
    "glossary-abbreviations": (."glossary-abbreviations" // null),
    "translation-zh-natural": (."translation-zh-natural" // null)
  }]
}]' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Extraction completed, results saved to: $OUTPUT_FILE"
