#!/bin/bash
# Проверка согласованности: все упомянутые issues должны быть в known-issues
# PostToolUse хук (matcher: Edit|Write) — вызывается после каждого редактирования .md файлов
# Если issue упоминается в файле, но отсутствует в research-cc-known-issues.md — предупреждение

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Только для .md файлов в корне (не prompts/, не .claude/)
if [[ -z "$FILE_PATH" ]] || [[ ! "$FILE_PATH" =~ ^[^/]*\.md$ ]] && [[ ! "$FILE_PATH" =~ research.*\.md$ ]]; then
  exit 0
fi

# Извлекаем номера issues из отредактированного файла
ISSUES=$(grep -oP '#\d{4,6}' "$FILE_PATH" 2>/dev/null | sort -u)
if [[ -z "$ISSUES" ]]; then
  exit 0
fi

# Проверяем каждый issue — есть ли он в known-issues
MISSING=""
for ISSUE in $ISSUES; do
  NUM=${ISSUE#\#}
  if ! grep -q "$NUM" research-cc-known-issues.md 2>/dev/null; then
    MISSING="$MISSING $ISSUE"
  fi
done

# Если есть неотслеживаемые issues — системное предупреждение
if [[ -n "$MISSING" ]]; then
  echo "{\"systemMessage\": \"Issues not in known-issues.md:$MISSING\"}"
fi
exit 0
