---
name: review
description: |
  Run independent critical review of all documentation files. Spawns 4 parallel verification agents,
  consolidates findings, validates via context7/exa, and presents corrections for approval.
---

# Независимое критическое ревью

## Шаги

1. Запусти 4 субагента параллельно:
   - `researcher-docs` — верификация секций Subagents и Skills/Plugins/Settings/CLI/Agent Teams в research-cc-primitives-reference.md через WebFetch official docs
   - `researcher-docs` (второй instance) — верификация секции Hooks в research-cc-primitives-reference.md через WebFetch official docs
   - `researcher-issues` — проверка статуса КАЖДОГО issue из research-cc-known-issues.md через gh CLI + поиск новых issues
   - `reviewer-consistency` — cross-reference между всеми research файлами (числа, имена, ссылки)

2. Собери результаты всех 4 агентов. Для каждого найденного расхождения:
   - **[CRITICAL]** — фактическая ошибка
   - **[WARNING]** — неполнота или неточность
   - **[INFO]** — пропущенная деталь

3. Запусти `reviewer-facts` для перепроверки CRITICAL и WARNING findings через context7 и exa

4. Покажи мне сводный отчёт с таблицей и жди одобрения

5. После одобрения — запусти `doc-writer` для применения исправлений

6. Обнови MEMORY.md с новыми findings

## Правила
- Не доверяй training data — загружай official docs для каждой проверки
- Не доверяй предыдущим ревью или пометкам "верифицировано"
- Для КАЖДОГО утверждения: CONFIRMED / CONTRADICTED / UNVERIFIABLE + URL
