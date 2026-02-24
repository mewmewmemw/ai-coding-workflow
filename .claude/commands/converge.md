---
name: converge
description: |
  Autonomous convergence loop: audit → verify → fix → re-audit until 0 issues remain.
  No human approval needed — runs until documentation is fully consistent and verified.
---

# Автономная конвергенция

Цикл: аудит → верификация → исправление → повторный аудит, пока не останется 0 проблем.
Без подтверждений — полностью автономный процесс.

**Максимум 5 итераций** (safety valve — #28148).

## Алгоритм

```
iteration = 0
while iteration < 5:
  iteration++

  === AUDIT ===
  Запусти 4 субагента параллельно (как в /audit):
  1. researcher-docs — верификация секций Subagents/Skills/Plugins/Settings/CLI/Agent Teams
  2. researcher-docs (второй instance) — верификация секции Hooks
  3. researcher-issues — проверка статуса КАЖДОГО issue + поиск новых
  4. reviewer-consistency — cross-reference между всеми файлами

  === EVALUATE ===
  Собери findings. Классифицируй:
  - [CRITICAL] — фактическая ошибка, CONTRADICTED
  - [WARNING] — неполнота, неточность, inconsistency
  - [INFO] — пропущенная деталь (НЕ исправлять автоматически)

  critical_count = количество CRITICAL
  warning_count = количество WARNING

  Покажи: "Итерация {iteration}: {critical_count} CRITICAL, {warning_count} WARNING"

  if critical_count == 0 AND warning_count == 0:
    break  // Конвергенция достигнута

  === VERIFY ===
  Для каждого CRITICAL finding — перепроверь через WebFetch official docs.
  Отбрось false positives. Обнови counts.

  if critical_count == 0 AND warning_count == 0:
    break

  === FIX ===
  Применяй исправления НАПРЯМУЮ (Edit/Write), без делегирования doc-writer.
  Только CRITICAL и WARNING. INFO — пропускай.

  Для каждого исправления логируй:
  - Файл, строка
  - Что было → что стало
  - Какой finding мотивировал

  === CONTINUE ===
  Следующая итерация проверит, не сломали ли исправления что-то другое
```

## После выхода из цикла

1. Покажи итоговый отчёт:

```
## Convergence Report

Итераций: N
Исправлений применено: M

### По итерациям:
| # | CRITICAL | WARNING | Исправлено |
|---|----------|---------|------------|
| 1 | X        | Y       | Z          |
| ...

### Все применённые исправления:
1. [файл:строка] что было → что стало (finding)
2. ...

### Оставшиеся INFO (не исправлялись):
- ...
```

2. Обнови MEMORY.md если были значимые исправления

## Правила

- **Не более 4 параллельных субагентов** за итерацию (#19100: лимит 2-3, но 4 работает на практике)
- **Не исправляй INFO** — только CRITICAL и WARNING
- **Не добавляй новый контент** — только исправления существующего
- **Не меняй структуру файлов** — только значения, числа, формулировки
- **Если 3 итерации подряд одинаковое количество findings** — остановись (осцилляция)
- **Не доверяй training data** — каждый CRITICAL перепроверяй через WebFetch
- Если findings требуют добавления новых issues или секций — выведи как рекомендацию, не применяй
