---
name: check-issues
description: |
  Quick check of all documented GitHub issue statuses via gh CLI.
  Reports closed issues and suggests updates. No full review — just status check.
---

# Быстрая проверка статуса issues

## Шаги

1. Запусти `researcher-issues` для проверки статуса ВСЕХ issues из research-cc-known-issues.md

2. Выведи таблицу:

| Issue | Документированный статус | Фактический статус | Действие |
|-------|------------------------|-------------------|----------|
| #NNNNN | open | closed | Убрать/пометить |

3. Если есть closed issues — спроси, применить ли изменения

4. Если да — `doc-writer` обновляет research-cc-known-issues.md
