---
name: update
description: |
  Update documentation after a new Claude Code release. Researches changelog and docs for changes,
  identifies what needs updating, and applies changes after approval.
---

# Актуализация после релиза Claude Code

Аргументы: $ARGUMENTS (номер версии или "latest")

## Шаги

1. Research фаза (параллельные субагенты):
   - `researcher-docs`: WebFetch https://code.claude.com/docs/en/changelog — найти изменения для указанной версии
   - `researcher-docs`: WebFetch всех official docs pages, сравнить с текущим содержимым reference файлов
   - `researcher-issues`: Проверить статус всех issues (новые closed? новые opened?)

2. Составь список изменений:
   - Новые фичи/примитивы
   - Изменённые поля/поведение
   - Закрытые issues (убрать из known-issues или пометить)
   - Новые issues

3. Покажи мне план изменений и жди одобрения

4. После одобрения — `doc-writer` применяет изменения ко всем файлам

5. Обнови MEMORY.md
