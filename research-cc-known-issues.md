# Claude Code: известные баги и ограничения

> Companion-документ к `research-claude-code-implementation.md`. Содержит все известные баги, workarounds и рекомендации по реализации.
> Справочник по примитивам — см. `research-cc-primitives-reference.md`.

> Верифицировано по открытым issues в anthropics/claude-code. Актуально на 24 февраля 2026.

---

## 🔴 Активные баги

### [Issue #27755] SubagentStart/SubagentStop hooks ненадёжны (даже `type: command`)
**Статус:** открыт (22 февраля 2026)

SubagentStart и SubagentStop hooks не срабатывают надёжно при конфигурации через settings.json. SubagentStart "часто отсутствует", SubagentStop срабатывает с пустым `agent_type` или не срабатывает вовсе. Reporter имеет 370+ трейсов агентов с **~42% failure rate**.

**Влияние на методологию:** **КРИТИЧНО** — quality gates через SubagentStop hooks, на которые опирается вся Implementation фаза, могут не сработать в ~42% случаев.

**Обходной путь:** `type: command` SubagentStop **необходим** (prompt/agent точно не работают), но **не гарантирован**. Для critical quality gates необходим fallback: CI pipeline как последний рубеж, ручная проверка перед merge.

---

### [Issue #25147] Background-агенты обходят Stop hooks
**Статус:** открыт (12 февраля 2026)

При запуске субагентов с `run_in_background=True` (или `background: true` в frontmatter), Stop hooks **полностью обходятся**. Quality gates (тесты, линтинг, policy checks) не выполняются для фоновых агентов.

**Влияние на методологию:** параллельный запуск Research-субагентов с `background: true` не позволит применить quality gates.

**Обходной путь:** не использовать `background: true` для агентов, требующих проверки через Stop/SubagentStop hooks. Либо добавить внешний контроль (CI).

---

### [Issue #17249] `type: prompt` hooks — экспоненциальный рост payload
**Статус:** открыт (январь 2026), stale

При сбое prompt hook вызывает бесконечный retry loop с экспоненциальным ростом payload (1KB → 2KB → 4KB → ... → 453MB), генерируя 800MB+ debug логов за минуты.

**Влияние на методологию:** `type: "prompt"` опасен для **всех** событий, не только SubagentStop. Может привести к OOM или заполнению диска.

**Обходной путь:** **не использовать `type: "prompt"` hooks в production**. Только `type: "command"`.

---

### [Issue #20221] `type: "prompt"` SubagentStop hooks не блокируют завершение
**Статус:** открыт (январь 2026), stale

SubagentStop hooks с `type: "prompt"` корректно оценивают и отправляют feedback субагенту, но **не предотвращают его завершение**. Субагент всё равно останавливается.

**Влияние на методологию:** quality gates через prompt-хуки не работают как блокирующие гейты.

**Обходной путь:** для quality gates использовать **только** `type: "command"` с exit code 2 или JSON `{"decision": "block"}`. Но см. также #27755 — даже command hooks ненадёжны.

---

### [Issue #25589] `disallowedTools` не блокирует MCP-инструменты
**Статус:** открыт (февраль 2026)

`--disallowedTools` и `disallowedTools` в субагентах блокируют только built-in tools. MCP tools остаются доступны независимо от ограничений.

**Влияние на методологию:** security-reviewer или другие субагенты с ограниченными `tools` могут получить доступ к MCP-инструментам, которые не должны использовать.

**Обходной путь:** не подключать ненужные MCP-серверы к субагентам (не указывать `mcpServers` в frontmatter). Без явного подключения субагент не получит MCP-инструменты.

---

### [Issue #25135] Agent Teams: SendMessage молча теряет сообщения
**Статус:** открыт (12 февраля 2026)

Если teammate использует alias или character name вместо точного зарегистрированного имени, сообщение записывается в orphaned inbox file, который никто не читает. `SendMessage` возвращает `success: true`.

**Влияние на методологию:** ненадёжная коммуникация в Agent Teams. Координация между агентами может молча ломаться.

**Обходной путь:** убедиться, что все teammates используют точные имена при отправке сообщений. Предпочесть Subagents для надёжной координации.

---

### [Issue #17927] Worktree path resolution bug
**Статус:** открыт (январь 2026), stale

При запуске агента из git worktree относительные пути разрешаются в **main repo**, а не в worktree. Пример:
```bash
git worktree add /path/to/worktree -b my-branch
cd /path/to/worktree && claude "Edit parsers.py"
# → редактирует /main-repo/parsers.py вместо /worktree/parsers.py
```

**Влияние на методологию:** `isolation: worktree` у Research-субагентов может писать файлы артефактов в неправильное место.

**Обходной путь:** при использовании worktree всегда указывать абсолютные пути. В промтах субагентов заменить относительные пути на `$(pwd)/...`.

---

### [Issue #27562] `--tmux --worktree` — Claude не стартует
**Статус:** открыт (22 февраля 2026)

Комбинация `claude --tmux --worktree` создаёт worktree, но tmux-сессия немедленно завершается без запуска Claude.

**Влияние:** tmux-based swarm coordination pattern (через `tmux send-keys`) нельзя комбинировать с `--worktree` через CLI-флаг.

**Обходной путь:** использовать `isolation: worktree` в frontmatter субагента — работает отдельно от `--tmux`.

---

### [Issue #14956] `allowed-tools` в Skills ненадёжен
**Статус:** открыт

Поле `allowed-tools` в SKILL.md frontmatter не выдаёт разрешения на Bash-команды, которые должно разрешать. Связанный Issue #18837 (закрыт как дубликат #14956) описывал обратную проблему. В целом механизм ненадёжен в обоих направлениях.

**Влияние на методологию:** нельзя надёжно контролировать инструменты через Skills.

**Обходной путь:** использовать субагентов с `tools` / `disallowedTools` — у них ограничения работают корректно для built-in tools.

---

### [Issue #24754] Task list state leaks across worktrees
**Статус:** открыт (февраль 2026)

`TaskCreate`/`TodoWrite` state привязан к git repository (shared `.git` directory), а не к отдельному worktree.

**Влияние на методологию:** при `isolation: worktree` для параллельных Research-субагентов, их task lists будут конфликтовать.

**Обходной путь:** не полагаться на встроенные task lists для координации между worktree-субагентами. Использовать файловые артефакты вместо task system.

---

### [Issue #20942] Subagent resume fails с 3+ tool uses
**Статус:** открыт (январь 2026), stale

Если субагент выполнил 3+ tool uses в первом вызове, последующий `resume` вызывает 400 API error. Порог детерминирован: ≤2 tool uses = resume работает, ≥3 = fails.

**Влияние:** ломает long-running субагенты, которые нужно resume.

---

### [Issue #18057] Subagent crash при вызове несуществующего skill
**Статус:** открыт (январь 2026), stale

Если субагент вызывает skill, который не существует, весь Claude Code **аварийно завершается** (Abort()), убивая parent process.

**Влияние:** hard crash всего CLI. Не делегировать skill invocation субагентам без проверки наличия skill.

---

### [Issue #27069] Skills/commands дублируются в worktrees
**Статус:** открыт (февраль 2026)

При использовании git worktrees, commands из `.claude/commands/` появляются дважды в списке `/skills`.

**Влияние:** косметическая проблема, не блокирует работу, но может путать.

---

### [Issue #27756] Infinite CPU loop при удалении `.claude/commands/`
**Статус:** открыт (февраль 2026)

Если агент удаляет директорию `.claude/commands/` при наличии дублирующихся slash commands из вложенных директорий, CLI входит в бесконечный CPU loop.

**Влияние:** критическая проблема стабильности. Не удалять `.claude/commands/` программно.

---

## 🟡 Ограничения экспериментальных фич

### Agent Teams: known limitations (официальная документация)

- **Session resumption** — `/resume` и `/rewind` не восстанавливают in-process teammates
- **Task status lag** — teammates иногда не отмечают задачи как завершённые, блокируя зависимые задачи (task claiming использует file locking)
- **Shutdown behavior** — медленное завершение teammates (ждут окончания текущего запроса/tool-вызова)
- **Lead does work itself** — без Delegate Mode lead часто сам пишет код вместо делегирования
- **One team per session** — нельзя создать несколько teams в одной сессии
- **No nested teams** — teammates не могут спаунить свои teams
- **Lead is fixed** — нельзя передать лидерство другому агенту
- **Permissions set at spawn** — нельзя изменить разрешения teammate после старта
- **Split panes** — требуется tmux или iTerm2 для отображения
- **SendMessage silent loss** — сообщения молча теряются при несовпадении имени получателя (Issue #25135)

**Вывод:** Agent Teams не готовы для production-использования с жёсткими quality gates. Для надёжной реализации методологии предпочесть **Subagents + `SubagentStop` hook** вместо Agent Teams + `TeammateIdle`.

### `isolation: worktree` в frontmatter

Добавлена недавно. Вероятны неотловленные edge cases (см. баги worktree-экосистемы выше). Использовать осторожно в первых реализациях.

---

## 🟢 Новое в последних релизах

- **`claude agents`** — CLI-команда для просмотра всех настроенных агентов
- **`claude --remote`** / **`claude --teleport`** — создание и возобновление web-сессий на claude.ai

---

## Рекомендации по реализации с учётом рисков

| Фаза | Риск | Рекомендация |
| --- | --- | --- |
| Research (isolation: worktree) | Path resolution bug (#17927) | Использовать абсолютные пути в промтах субагентов |
| Research (isolation: worktree) | Task list leak (#24754) | Не полагаться на встроенные task lists; использовать файловые артефакты |
| Research (isolation: worktree) | Commands duplication (#27069) | Косметическая проблема, не критично |
| Research (background: true) | Background agents bypass Stop hooks (#25147) | Не использовать `background: true` для агентов с quality gates |
| Implementation (Agent Teams) | Experimental, known limitations, silent message loss (#25135) | Использовать Subagents + SubagentStop вместо Agent Teams для начала |
| Coordination (tmux + --worktree) | --tmux --worktree bug (#27562) | Не комбинировать --tmux и --worktree через CLI |
| Quality gates (SubagentStop) | prompt/agent hooks не блокируют (#20221) | Использовать **только** `type: "command"` для quality gates |
| Quality gates (SubagentStop) | command hooks ~42% failure rate (#27755) | `type: command` необходим, но не гарантирован. **CI — обязательный fallback** |
| Quality gates (prompt hooks) | Экспоненциальный рост payload (#17249) | **Не использовать `type: "prompt"` в production** |
| Quality gates | — | SubagentStop надёжнее TeammateIdle для текущего состояния |
| Subagent tools/disallowedTools | Не блокирует MCP tools (#25589) | Не подключать ненужные mcpServers к субагентам |
| Skills allowed-tools | Не enforce-ится (#14956) | Ограничивать инструменты через subagent `tools`, не через skills |
| Subagent resume | Fails с 3+ tool uses (#20942) | Не полагаться на resume для долгих субагентов |
| Subagent + skills | Crash при несуществующем skill (#18057) | Проверять наличие skill перед делегированием |

---

## Принципы реализации

- **Начать с Subagents-only** (без Agent Teams) — надёжнее, проверено community
- **Использовать exit code 2 + stderr** для quality gates — проще чем JSON, работает надёжно
- **Только `type: "command"` для SubagentStop quality gates** — prompt/agent хуки не блокируют завершение (#20221)
- **Не использовать `type: "prompt"` hooks в production** — экспоненциальный рост payload (#17249)
- **CI — обязательный fallback для quality gates** — SubagentStop hooks ненадёжны (~42% failure rate, #27755)
- **Не использовать `background: true` для агентов с quality gates** — Stop hooks обходятся (#25147)
- **Не использовать `allowed-tools` в Skills** — баг, не enforce-ится. Ограничения — только через subagent `tools`
- **Не подключать лишние `mcpServers` к субагентам** — `disallowedTools` не блокирует MCP tools (#25589)
- **Абсолютные пути в промтах субагентов** — обход бага worktree path resolution (#17927)
- **`stop_hook_active` проверка** в Stop/SubagentStop hooks — предотвращает бесконечные циклы
- **Не комбинировать `--tmux` и `--worktree`** через CLI (#27562)
- **Файловые артефакты вместо task lists** при работе с worktrees — task state leaks (#24754)
- **Не делегировать skill invocation субагентам** без проверки наличия skill — crash всего CLI (#18057)
