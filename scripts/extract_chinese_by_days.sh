#!/bin/bash
# extract_chinese_by_days.sh - Extract Chinese translations grouped by days from processed JSON

# Check input parameters
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_JSON_file> [output_file]"
    echo "Example: $0 tosa-zh.json translations_by_days.json"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-translations_by_days.json}"

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

# Extract translations grouped by days using jq
jq '[.[] | {
  title: (.title // null),
  author: (.author // null),
  translations: (
    [.paragraph[]? | select(."translation-zh-natural" != null)] |
    reduce .[] as $item (
      {current_chapter: null, chapters: []};
      
      # Determine chapter name based on id and content
      if $item.id == 1 then
        .current_chapter = "序" |
        .chapters += [{
          chapter: "序",
          contents: ($item."translation-zh-natural" // "")
        }]
      elif $item.id >= 2 and $item.id <= 6 then
        if .current_chapter != "二十一日" then
          .current_chapter = "二十一日" |
          .chapters += [{
            chapter: "二十一日",
            contents: ($item."translation-zh-natural" // "")
          }]
        else
          .chapters[-1].contents += "\n" + ($item."translation-zh-natural" // "")
        end
      elif $item.id == 335 then
        if .current_chapter != "二月一日" then
          .current_chapter = "二月一日" |
          .chapters += [{
            chapter: "二月一日",
            contents: ($item."translation-zh-natural" // "")
          }]
        else
          .chapters[-1].contents += "\n" + ($item."translation-zh-natural" // "")
        end
      else
        # Check if koutei-yamagen starts with a date pattern
        ($item."koutei-yamagen" // "") as $original |
        if ($original | test("^(元日|[一二三四五六七八九]日|十日|十[一二三四五六七八九]日|二十日|二十[一二三四五六七八九]日|三十日|三十[一二三四五六七八九]日|二月一日)")) then
          # Extract date from the beginning
          ($original | capture("^(?<date>元日|[一二三四五六七八九]日|十日|十[一二三四五六七八九]日|二十日|二十[一二三四五六七八九]日|三十日|三十[一二三四五六七八九]日|二月一日)").date) as $new_chapter |
          # Only create new chapter if different from current
          if .current_chapter != $new_chapter then
            .current_chapter = $new_chapter |
            .chapters += [{
              chapter: $new_chapter,
              contents: ($item."translation-zh-natural" // "")
            }]
          else
            .chapters[-1].contents += "\n" + ($item."translation-zh-natural" // "")
          end
        else
          # Add to current chapter if exists (continuation of current day)
          if .current_chapter != null and (.chapters | length > 0) then
            .chapters[-1].contents += "\n" + ($item."translation-zh-natural" // "")
          else
            # Skip this item if no current chapter exists
            .
          end
        end
      end
    ) | .chapters
  )
}]' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Day-grouped translation extraction completed, results saved to: $OUTPUT_FILE"
