#!/usr/bin/env bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
in_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
out_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

parts=""
[ -n "$model" ] && parts="$model"

if [ -n "$used_pct" ]; then
    [ -n "$parts" ] && parts="$parts | "
    parts="${parts}Ctx: ${used_pct}%"
fi

if [ -n "$in_tokens" ]; then
    [ -n "$parts" ] && parts="$parts | "
    parts="${parts}In: $in_tokens"
fi

if [ -n "$out_tokens" ]; then
    [ -n "$parts" ] && parts="$parts | "
    parts="${parts}Out: $out_tokens"
fi

echo "$parts"
