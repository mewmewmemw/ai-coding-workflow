# ai-coding-workflow

Методология контекстной инженерии для AI-assisted разработки. Документация + готовый `.claude/` scaffold. Проект поддерживает сам себя по собственной методологии.

## Ключевые файлы

| Файл | Содержание |
|---|---|
| `methodology.md` | Методология (4 фазы: Research -> Design -> Planning -> Implementation) |
| `research-cc-primitives-reference.md` | Справочник примитивов Claude Code (frontmatter, hooks, skills, plugins, settings, CLI, agent teams) |
| `research-cc-known-issues.md` | Известные баги (46 issues, все проверены open) |
| `research-claude-code-implementation.md` | Маппинг методологии на примитивы Claude Code |
| `prompts/critical-review.md` | Промт для независимого ревью |

## Команды

- `/review` -- критическое ревью всей документации (4 параллельных агента -> сведение -> валидация -> применение)
- `/update` -- обновление после нового релиза CC (changelog -> выявление изменений -> применение)
- `/add-primitive` -- добавление нового примитива/секции (полный цикл: research -> design -> plan -> implement)
- `/check-issues` -- быстрая проверка статуса issues через `gh` CLI

## Стандарты качества

- Каждое фактическое утверждение должно быть верифицировано по official docs (code.claude.com)
- Cross-reference consistency между файлами (числа, имена, ссылки на issues)
- Статусы GitHub issues должны быть актуальными
- НЕ доверяй training data -- всегда загружай official docs

## Правила

- **Scope:** только Claude Code CLI. Agent SDK (TS/Python) -- OUT OF SCOPE
- **Язык:** документация на русском, описания агентов (frontmatter) на английском
- **Факты, не мнения:** в research-файлах только факты. Без оценок, советов, рекомендаций
- **Issues:** каждый issue содержит: статус, описание, влияние, обходной путь
- **MEMORY.md:** обновлять после каждого значимого изменения
- **Поиск:** всегда `mcp__exa__web_search_exa` вместо WebSearch

## Маршрутизация субагентов

**Параллельно** (нет зависимостей между задачами):
- Верификация разных секций документации
- Проверка статуса issues + проверка docs одновременно
- Несколько `researcher-docs` по непересекающимся секциям

**Последовательно** (результат предыдущего шага нужен следующему):
- Research -> Design -> Planning -> Implementation
- Сбор findings от параллельных агентов -> сведение -> валидация
- Обнаружение расхождений -> перепроверка -> применение исправлений

**Ограничения:**
- Не более 2-3 параллельных субагентов (#19100: OOM при 4GB heap, #27794: compaction cascade)
- Всегда `maxTurns` в frontmatter (#28148: без лимита -- 153GB output)
- Не использовать `background: true` для агентов с quality gates (#25147)
- Результаты через файлы, не через возвращаемые данные (#23463: overflow context)
