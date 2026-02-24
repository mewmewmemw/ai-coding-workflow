#!/bin/bash
# Проверка статуса issues: извлекает все номера из known-issues и проверяет через gh CLI
# Используется командой /check-issues (не как hook, а как standalone скрипт)
# Сообщает обо всех закрытых issues, которые до сих пор числятся как открытые

KNOWN_ISSUES_FILE="research-cc-known-issues.md"

# Проверяем наличие файла
if [[ ! -f "$KNOWN_ISSUES_FILE" ]]; then
  echo "Ошибка: файл $KNOWN_ISSUES_FILE не найден"
  exit 1
fi

# Проверяем наличие gh CLI
if ! command -v gh &>/dev/null; then
  echo "Ошибка: gh CLI не установлен"
  exit 1
fi

# Извлекаем уникальные номера issues из файла
ISSUES=$(grep -oP '(?<=Issue #)\d{4,6}' "$KNOWN_ISSUES_FILE" | sort -u)

if [[ -z "$ISSUES" ]]; then
  echo "Не найдено ни одного issue в $KNOWN_ISSUES_FILE"
  exit 0
fi

TOTAL=0
CLOSED_COUNT=0
CLOSED_LIST=""
ERRORS=""

echo "Проверка статуса issues из $KNOWN_ISSUES_FILE..."
echo "================================================="

for NUM in $ISSUES; do
  TOTAL=$((TOTAL + 1))

  # Запрашиваем статус issue через gh CLI
  STATE=$(gh issue view "$NUM" --repo anthropics/claude-code --json state -q '.state' 2>/dev/null)

  if [[ $? -ne 0 ]] || [[ -z "$STATE" ]]; then
    ERRORS="$ERRORS\n  #$NUM — не удалось получить статус"
    continue
  fi

  if [[ "$STATE" == "CLOSED" ]]; then
    CLOSED_COUNT=$((CLOSED_COUNT + 1))
    CLOSED_LIST="$CLOSED_LIST\n  #$NUM — CLOSED"
  fi
done

echo ""
echo "Итого проверено: $TOTAL issues"

if [[ $CLOSED_COUNT -gt 0 ]]; then
  echo ""
  echo "ЗАКРЫТЫЕ issues ($CLOSED_COUNT):"
  echo -e "$CLOSED_LIST"
  echo ""
  echo "Необходимо обновить документацию!"
fi

if [[ -n "$ERRORS" ]]; then
  echo ""
  echo "Ошибки при проверке:"
  echo -e "$ERRORS"
fi

if [[ $CLOSED_COUNT -eq 0 ]] && [[ -z "$ERRORS" ]]; then
  echo "Все issues по-прежнему открыты. Документация актуальна."
fi
