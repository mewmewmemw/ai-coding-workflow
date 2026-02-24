---
name: add-primitive
description: |
  Add a new primitive or section to research documentation. Full cycle:
  Research official docs -> Design section structure -> Plan content -> Write section.
---

# Добавление нового примитива

Аргументы: $ARGUMENTS (название примитива или URL docs страницы)

## Шаги

1. **Research:** Запусти `researcher-docs` для полного исследования нового примитива:
   - WebFetch official docs page
   - exa поиск по site:code.claude.com
   - context7 для дополнительного контекста
   - Поиск связанных GitHub issues

2. **Design:** Определи структуру новой секции:
   - Какие подсекции нужны (reference table, примеры, ограничения)
   - Где в каком файле разместить (primitives-reference или отдельный файл)
   - Какие cross-references добавить

3. Покажи мне план секции и жди одобрения

4. **Implementation:** `doc-writer` пишет секцию по плану

5. **Review:** `reviewer-facts` верифицирует новую секцию

6. **Validate:** Если новый примитив выявляет известные баги — добавь в known-issues "Принципы реализации" и CLAUDE.md "Guardrails"

7. Обнови MEMORY.md
