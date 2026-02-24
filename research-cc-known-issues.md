# Claude Code: известные баги и ограничения

> Companion-документ к `research-claude-code-implementation.md`. Содержит все известные баги, workarounds и рекомендации по реализации.
> Справочник по примитивам — см. `research-cc-primitives-reference.md`.

> Верифицировано по открытым issues в anthropics/claude-code (11 раундов ревью). Актуально на 24 февраля 2026. 11-й раунд ревью (24 февраля 2026): #18837 закрыт (дубликат #14956), #27044 закрыт (контекст для #27778 обновлён). Добавлено 5 новых issues (#17637, #28048, #27881, #27429, #27946). Итого: 50 issues.

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

Комбинация `claude --tmux --worktree` создаёт worktree, но tmux-сессия немедленно завершается без запуска Claude. ⚠️ Дополнительно: `--tmux` теперь **требует** `--worktree` — без него выдаёт ошибку "Error: --tmux requires --worktree".

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

**Обходной путь:** не полагаться на встроенные task lists для координации между worktree-субагентами. Использовать файловые артефакты вместо task system. Альтернатива: `CLAUDE_CODE_TASK_LIST_ID=my-feature claude` для изоляции task list per worktree.

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

### [Issue #24421] Background subagent completion некорректно триггерит родительский Stop hook
**Статус:** открыт

При завершении background-субагентов некорректно срабатывает **родительский Stop hook** (вместо SubagentStop). В сочетании с #25147 (SubagentStop обходится для background) создаёт двойную проблему: SubagentStop НЕ срабатывает, но Stop родителя срабатывает ложно.

**Влияние на методологию:** Stop hook основного агента может сработать преждевременно при завершении любого background-субагента.

**Обходной путь:** не использовать `background: true` для агентов с quality gates. Проверять в Stop hook, не является ли trigger ложным.

---

### [Issue #17591] TaskOutput возвращает raw JSONL вместо summary (regression since 2.0.77)
**Статус:** открыт (10 thumbs-up)

`TaskOutput` для background-субагентов возвращает полный JSONL транскрипт вместо чистого summary. Раздувает контекстное окно родительского агента.

**Влияние на методологию:** Research-фаза с background-субагентами — результаты субагентов загрязняют контекст Lead-агента.

**Обходной путь:** использовать файловые артефакты (субагент пишет результат в файл) вместо прямого `TaskOutput`.

---

### [Issue #27778] `--worktree` flag silently broken в v2.1.50
**Статус:** открыт

Флаг `--worktree` молча ничего не делает в v2.1.50. Worktree не создаётся. Возможный регресс после фикса #27044 (закрыт 23 февраля 2026, но #27778 по-прежнему воспроизводится).

**Влияние на методологию:** `isolation: worktree` в frontmatter может быть единственным работающим механизмом. CLI `--worktree` ненадёжен.

**Обходной путь:** использовать `isolation: worktree` в frontmatter субагента вместо CLI-флага.

---

### [Issue #27974] EnterWorktree создаёт nested worktrees из существующего worktree
**Статус:** открыт

`EnterWorktree` использует `git rev-parse --show-toplevel` (возвращает root worktree) вместо `git rev-parse --git-common-dir`. При вызове из worktree создаёт вложенные worktrees.

**Влияние:** проблема при nested субагентах с `isolation: worktree`.

---

### [Issue #27134] EnterWorktree branches от default branch, не HEAD
**Статус:** открыт

EnterWorktree создаёт worktree от `origin/<defaultBranch>` вместо HEAD. Если вы на feature branch, worktree получает main.

**Влияние на методологию:** Research-субагенты с `isolation: worktree` могут исследовать **не ту ветку** — main вместо текущей feature branch.

**Обходной путь:** убедиться, что Research запускается из main или явно указать ветку.

---

### [Issue #27985] Skills загружаются из repo root, не из worktree directory
**Статус:** открыт

Skills в `.claude/skills/` загружаются из main working tree, не из worktree branch. Изменения skills на feature branch не отражаются в worktree.

**Влияние:** при модификации skills на feature branches worktrees используют старые skills.

---

### [Issue #21460] [SECURITY] PreToolUse hooks обходятся субагентами
**Статус:** открыт (28 января 2026), stale

Субагенты **полностью обходят** PreToolUse hooks, настроенные в `settings.json`. Security-ограничения, применяемые к основному агенту, не распространяются на субагентов. Если PreToolUse hook используется как security boundary — субагент может выполнить любой tool call без проверки.

**Влияние на методологию:** **КРИТИЧНО** — PreToolUse hooks НЕ являются надёжной security boundary при использовании субагентов. Quality gates на базе PreToolUse для конкретных tool calls (например, блокировка `Bash` для определённых паттернов) не сработают для субагентов.

**Обходной путь:** ограничивать инструменты субагентов через `tools` / `disallowedTools` в frontmatter (работает для built-in tools). Для MCP tools — не подключать mcpServers. CI pipeline как дополнительный рубеж.

---

### [Issue #27657] Read tool file_path dropped в background subagents
**Статус:** открыт (22 февраля 2026)

В `general-purpose` background субагентах параметр `file_path` инструмента `Read` молча теряется — вызов приходит с пустым `input: {}`. Приводит к бесконечным retry loops. Race condition: затрагивает ~6 из 9 параллельных субагентов.

**Влияние на методологию:** Research-фаза с параллельными background-субагентами ненадёжна — субагенты не могут читать файлы.

**Обходной путь:** не использовать `background: true` для Research-субагентов, которые активно читают файлы. Использовать foreground субагенты или Agent Teams.

---

### [Issue #28017] Worktree CWD leaks в parent session
**Статус:** открыт (24 февраля 2026)

После завершения worktree-субагента (с `isolation: worktree`), CWD Bash-инструмента родительской сессии **перманентно** дрейфует на путь worktree. Все последующие Bash-вызовы в родительской сессии выполняются в (возможно уже удалённом) worktree.

**Влияние на методологию:** после Research-фазы с `isolation: worktree` Lead-агент может потерять корректный CWD, что сломает все последующие фазы.

**Обходной путь:** после завершения worktree-субагентов явно проверять и восстанавливать CWD в промте Lead-агента. Использовать абсолютные пути.

---

### [Issue #19100] JavaScript heap OOM при параллельных Explore subagents
**Статус:** открыт (18 января 2026)

Запуск нескольких Explore-субагентов параллельно вызывает исчерпание heap (4GB) и fatal crash. Критично для Research-фазы, где параллельный запуск — ключевой паттерн.

**Влияние на методологию:** параллельный запуск большого числа Research-субагентов может привести к OOM crash всего CLI.

**Обходной путь:** ограничивать число параллельных субагентов (2-3 максимум). Использовать `model: haiku` для снижения memory footprint. При необходимости — последовательный запуск.

---

### [Issue #23463] Subagent results overflow context → unrecoverable session crash
**Статус:** открыт (5 февраля 2026)

При 7+ параллельных субагентах, возвращающих большие результаты, родительский контекст переполняется — сессия входит в неизлечимый "Prompt is too long" loop. Связан с #19100 (OOM), но другой root cause: не memory exhaustion, а context overflow.

**Влияние на методологию:** **КРИТИЧНО** — Research-фаза с параллельными субагентами уязвима при большом объёме результатов.

**Обходной путь:** ограничивать объём ответов субагентов, использовать файловые артефакты вместо прямого возврата больших результатов. Ограничивать параллельные субагенты до 2-3.

---

### [Issue #27794] Compaction cascade loop при массовом параллельном запуске субагентов
**Статус:** открыт (23 февраля 2026)

При 10-15+ параллельных субагентах компакция входит в feedback loop, сессия становится нерабочей. Связан с #23463, но другой root cause (compaction cascade, а не просто overflow).

**Влияние на методологию:** усиливает рекомендацию ограничивать параллельные субагенты до 2-3.

**Обходной путь:** ограничивать число параллельных субагентов. Разбивать на последовательные батчи по 2-3 субагента.

---

### [Issue #27655] Agent frontmatter hooks не работают для team-spawned agents
**Статус:** открыт (22 февраля 2026)

Hooks, определённые в `.claude/agents/*.md` YAML frontmatter, **никогда не срабатывают** для агентов, запущенных через Agent Teams. Root cause: session ID mismatch между регистрацией и dispatch.

**Влияние на методологию:** quality gates через frontmatter hooks в Agent Teams полностью нефункциональны.

**Обходной путь:** определять hooks в `settings.json` (а не в frontmatter) при использовании Agent Teams. Предпочесть Subagents.

---

### [Issue #27467] / [Issue #27963] WorktreeCreate hooks → silent hang
**Статус:** открыт (февраль 2026)

WorktreeCreate hooks зависают бесконечно (без timeout, без ошибки) если stdout содержит лишний output или hook завершается с exit code 1. Требуется Ctrl-C для прерывания.

**Влияние:** при использовании `isolation: worktree` с custom WorktreeCreate hooks — CLI может зависнуть.

**Обходной путь:** в WorktreeCreate hooks возвращать **только** абсолютный путь к worktree на stdout, ничего лишнего. Всегда exit 0 при успехе.

---

### [Issue #27474] `claude --worktree` перезаписывает `core.hooksPath`
**Статус:** открыт (21 февраля 2026)

При создании worktree Claude Code перезаписывает `core.hooksPath` в `$GIT_COMMON_DIR/config`. Деструктивно, если git hooks path указывает на нестандартное расположение (например, `.husky`).

**Влияние:** может сломать CI/CD pipeline и pre-commit hooks в основном репозитории.

**Обходной путь:** перед использованием worktrees убедиться, что `core.hooksPath` не настроен на нестандартный путь, или восстановить его после сессии.

---

### [Issue #25694] Team agents отправляют сообщения по agentType вместо name
**Статус:** открыт (14 февраля 2026)

Teammates создают orphan inboxes, отправляя сообщения по `agentType` вместо зарегистрированного `name`. Связан с #25135 (name mismatch), но имеет отдельный root cause — agentType vs name confusion.

**Влияние на методологию:** ещё один вектор потери сообщений в Agent Teams, помимо #25135.

**Обходной путь:** те же, что для #25135 — точные имена + предпочитать Subagents.

---

### [Issue #27423] SubagentStop fires без соответствующего SubagentStart
**Статус:** открыт (21 февраля 2026)

Orphaned `SubagentStop` события срабатывают с пустым `agent_type` и без matching `SubagentStart`. Связан с #27755 — усиливает ненадёжность SubagentStart/SubagentStop lifecycle.

**Влияние на методологию:** hooks, фильтрующие по `agent_type`, получают пустое значение. Quality gates на основе матчинга по типу агента могут не сработать.

**Обходной путь:** те же, что для #27755 — CI как fallback, проверка `agent_type` на пустоту в скрипте.

---

### [Issue #24920] Stop hooks с `type: "prompt"` молча теряют поле `prompt`
**Статус:** открыт (11 февраля 2026)

Stop hooks с `type: "prompt"` повторно теряют поле `prompt` из settings.json — оно молча удаляется, оставляя только `type`, `timeout`, `statusMessage`. Data-loss баг в конфигурации hooks.

**Влияние:** дополнительный аргумент против `type: "prompt"` — помимо экспоненциального роста (#17249), конфигурация может быть молча повреждена.

**Обходной путь:** **не использовать `type: "prompt"` hooks** — это правило теперь подкреплено тремя отдельными багами (#17249, #20221, #24920).

---

### [Issue #23415] Agent Teams: Teammates не читают inbox (tmux backend, macOS)
**Статус:** открыт (5 февраля 2026, 7 thumbs-up)

Teammates, запущенные через tmux backend, никогда не читают свои inbox-файлы. Сообщения остаются `"read": false` бесконечно. Teammates ведут себя как standalone Claude Code сессии без team awareness.

**Влияние на методологию:** фундаментальная проблема Agent Teams помимо name-mismatch (#25135). Даже с правильными именами сообщения могут не доставляться на tmux backend.

**Обходной путь:** использовать `in-process` режим (`teammateMode: "in-process"`) или Subagents вместо Agent Teams.

---

### [Issue #24220] `/compact` блокируется при активном background task polling
**Статус:** открыт, stale

Когда background-субагент активен, `/compact` игнорируется — контекстное окно заполняется без возможности компакции.

**Влияние на методологию:** при длительных background-задачах контекст Lead-агента может переполниться без возможности ручной компакции.

**Обходной путь:** не запускать длительные background-задачи одновременно с интенсивной работой в основной сессии. Автокомпакция (~95%) продолжает работать.

---

### [Issue #19298] PermissionRequest hook не может заблокировать разрешения
**Статус:** открыт, stale

PermissionRequest hook выполняется, но его решение игнорируется — интерактивный диалог разрешения всегда появляется. Hook фактически информационный (logging, auditing), не управляющий.

**Влияние на методологию:** PermissionRequest hooks нельзя использовать для автоматического управления разрешениями. Для автоматических permission decisions используйте PreToolUse hooks (с учётом #21460 — обходятся субагентами).

**Обходной путь:** использовать PreToolUse hooks для блокировки tool calls; использовать `permissionMode` в frontmatter субагента для управления разрешениями.

---

### [Issue #28148] Субагент без maxTurns генерирует 153GB output file
**Статус:** открыт (24 февраля 2026)

Субагент без ограничения `maxTurns` может войти в бесконечный цикл и сгенерировать output file размером 153GB+, заполняя диск.

**Влияние на методологию:** **КРИТИЧНО** — все субагенты без `maxTurns` потенциально уязвимы к бесконечным циклам с заполнением диска.

**Обходной путь:** **всегда** указывать `maxTurns` в frontmatter каждого субагента.

---

### [Issue #28093] MCP calls маршрутизируются к неправильному серверу при параллельных сессиях
**Статус:** открыт (24 февраля 2026)

При запуске нескольких Claude Code сессий параллельно MCP-вызовы могут маршрутизироваться к неправильному серверу.

**Влияние на методологию:** при использовании Agent Teams или параллельных tmux-сессий с MCP-серверами данные могут утекать между сессиями.

**Обходной путь:** изолировать MCP-серверы между параллельными сессиями. Не запускать один MCP-сервер в нескольких параллельных сессиях.

---

### [Issue #28078] /rewind уничтожает uncommitted changes другой сессии
**Статус:** открыт (24 февраля 2026)

`/rewind` в одной сессии молча уничтожает uncommitted changes, сделанные другой параллельной сессией.

**Влияние на методологию:** при параллельных субагентах без `isolation: worktree` — `/rewind` в одной сессии может стереть работу другой.

**Обходной путь:** использовать `isolation: worktree` для параллельных субагентов. Не применять `/rewind` при активных параллельных сессиях в одном репозитории.

---

### [Issue #13890] Субагенты молча не могут писать файлы и вызывать MCP tools
**Статус:** открыт (декабрь 2025)

Субагенты молча не могут писать файлы и вызывать MCP tools — операции завершаются без ошибки, но эффекта нет (silent failure).

**Влияние на методологию:** субагенты, пишущие артефакты (Design, Plan), могут молча потерять результаты.

**Обходной путь:** проверять наличие output-файлов после завершения субагента. Связан с #25589 (MCP) и #27657 (Read tool).

---

### [Issue #7881] SubagentStop hook не идентифицирует конкретный субагент
**Статус:** открыт (сентябрь 2025), enhancement

SubagentStop hook не может различить, какой конкретный субагент завершился — shared session IDs не позволяют идентификацию.

**Влияние на методологию:** quality gates не могут применять разные проверки к разным типам субагентов (backend-developer vs tester) через один SubagentStop hook.

**Обходной путь:** использовать `agent_type` из входного JSON (с учётом #27423 — может быть пустым). Фильтровать по `agent_type` с fallback на transcript analysis.

---

### [Issue #22172] 100% CPU hang при параллельных instances с hooks (regression)
**Статус:** открыт (31 января 2026), stale, high-priority, regression

Запуск нескольких параллельных Claude Code instances с hooks вызывает 100% CPU hang. Регресс между v2.1.22 и v2.1.23. 10 thumbs-up.

**Влияние на методологию:** **КРИТИЧНО** — параллельные tmux-сессии и Agent Teams с hooks могут зависнуть.

**Обходной путь:** использовать v2.1.22 или отключить hooks при параллельном запуске. Мониторить CPU usage.

---

### [Issue #25168] [SECURITY] Edit tool permission bypass
**Статус:** открыт (12 февраля 2026)

Edit tool выполняется без запроса разрешения в ситуациях, когда permission settings должны его блокировать. 10+ последовательных Edit вызовов auto-approved. Возможный root cause: default permission mode auto-approves edits в `.claude/` directory.

**Влияние на методологию:** субагенты могут модифицировать конфигурацию (`.claude/settings.json`, `.claude/agents/`) без одобрения.

**Обходной путь:** мониторить Edit calls в hooks, использовать `disallowedTools` для Edit в субагентах, которые не должны редактировать файлы.

---

### [Issue #28008] [SECURITY] Permission deny rules bypass через Bash grep и Glob
**Статус:** открыт (23 февраля 2026)

Bash recursive grep из parent-директории и Glob patterns могут утекать содержимое файлов из deny-listed директорий, даже когда Read/Grep tools корректно блокируют доступ.

**Влияние на методологию:** **КРИТИЧНО** — deny rules для конфиденциальных директорий не обеспечивают полную изоляцию. Данные из `.env`, credentials и protected dirs могут утечь через Bash/Glob.

**Обходной путь:** помимо deny rules, не хранить секреты в рабочей директории. Использовать `disallowedTools: Bash` для субагентов, которым не нужен shell.

---

### [Issue #28075] Agent Teams: idle nudge timing — агенты уходят в idle до получения сообщений
**Статус:** открыт (24 февраля 2026)

Idle-nudge система не различает "ожидание сообщения от пира" и "нечего делать". Агенты уходят в idle раньше, чем приходят сообщения. Подробный repro с 3 моделями показывает consistent failure.

**Влияние на методологию:** ещё один фундаментальный баг Agent Teams коммуникации, помимо #25135 (wrong inbox) и #23415 (inbox not polled). Даже при правильных именах — timing/state machine проблемы.

**Обходной путь:** использовать Subagents вместо Agent Teams. Если Agent Teams необходимы — увеличить idle timeout через промт или TeammateIdle hook.

---

### [Issue #17637] Hooks не получают tool input для Read/Glob; permission patterns не матчат tilde paths
**Статус:** открыт (12 января 2026)

PreToolUse hooks для Read/Glob tools не получают параметры tool input через переменные окружения. `CLAUDE_TOOL_INPUT_FILE_PATH` и аналогичные переменные отсутствуют — hooks получают только `CLAUDE_PROJECT_DIR` и `CLAUDE_CODE_ENTRYPOINT`. Дополнительно: permission patterns с `~` не матчат пути с tilde, генерируемые моделью.

**Влияние на методологию:** невозможно валидировать пути файлов в PreToolUse hooks для Read/Glob. Переменные `$CLAUDE_TOOL_INPUT_*` не документированы и не гарантированы.

**Обходной путь:** использовать JSON на stdin (`cat | jq`) для получения tool input. Для permissions — использовать абсолютные пути вместо tilde.

---

### [Issue #28048] Agent Teams tools недоступны в VS Code extension
**Статус:** открыт (24 февраля 2026)

Agent Teams tools (TeammateTool, SendMessage, spawnTeam) недоступны в VS Code extension даже при наличии `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` в settings.json. System prompt сообщает "not available on this plan" даже на Enterprise plan. Feature gated внутренними функциями, которые не активируются env var в VS Code.

**Влияние на методологию:** Agent Teams workflow невозможен в VS Code extension. Только CLI.

**Обходной путь:** использовать Claude Code CLI для Agent Teams workflow. В VS Code — использовать Subagents через Task tool.

---

### [Issue #27881] EnterWorktree создаёт nested worktrees при CWD drift после compaction
**Статус:** открыт (23 февраля 2026)

При context compaction или session continuation CWD может дрейфовать внутрь предыдущего worktree. Последующие вызовы EnterWorktree создают worktrees вложенные в существующие (3+ уровней вглубь). При достаточной вложенности создание worktree может молча упасть, и агент fallback-ится на текущую CWD — потенциально main/develop branch, обходя isolation.

**Влияние на методологию:** **КРИТИЧНО** — worktree isolation может быть молча нарушена. Агенты могут коммитить напрямую в protected branches. Связан с #27974 (nested worktrees) и #28017 (CWD leak).

**Обходной путь:** после compaction явно проверять и восстанавливать CWD. Использовать абсолютные пути. Ограничивать длительность сессий с worktree-субагентами.

---

### [Issue #27429] MAX_THINKING_TOKENS глобальный — crash субагентов с другой моделью
**Статус:** открыт (21 февраля 2026)

`MAX_THINKING_TOKENS` — единый глобальный env var для main agent и всех субагентов. Если main agent использует Opus (128k output cap) с `MAX_THINKING_TOKENS=95000`, Explore-субагенты на Sonnet (64k cap) молча крашатся: `0 tool uses · Done`, без ошибки.

**Влияние на методологию:** Research-фаза с Explore-субагентами (model: haiku/sonnet) может молча ломаться при высоком MAX_THINKING_TOKENS.

**Обходной путь:** установить MAX_THINKING_TOKENS ниже минимального output cap используемых моделей (например, ≤30000 для совместимости с Haiku). Или не использовать MAX_THINKING_TOKENS при mixed-model workflows.

---

### [Issue #27946] Memory leak: Claude Code процесс потребляет ~58GB RAM → OOM kill
**Статус:** открыт (23 февраля 2026)

Claude Code процесс (особенно в VS Code extension) постепенно потребляет память до исчерпания (58-60GB), вызывая OOM killer. VS Code крашится с каскадным падением всех extension hosts. 3 OOM kill за 2 часа.

**Влияние на методологию:** длительные сессии могут привести к OOM crash. Связан с #19100 (heap OOM при параллельных субагентах), но другой root cause — постепенная утечка памяти основного процесса.

**Обходной путь:** периодически перезапускать Claude Code сессию. Мониторить потребление памяти. Использовать CLI вместо VS Code extension для длительных сессий.

---

## 🟡 Ограничения экспериментальных фич

### Agent Teams: known limitations (официальная документация)

- **Session resumption** — `/resume` и `/rewind` не восстанавливают in-process teammates
- **Task status lag** — teammates иногда не отмечают задачи как завершённые, блокируя зависимые задачи (task claiming использует file locking)
- **Shutdown behavior** — медленное завершение teammates (ждут окончания текущего запроса/tool-вызова)
- **Lead does work itself** — без явной инструкции lead часто сам пишет код вместо делегирования. Рекомендуется промт: "Wait for your teammates to complete their tasks before proceeding"
- **One team per session** — нельзя создать несколько teams в одной сессии
- **No nested teams** — teammates не могут спаунить свои teams
- **Lead is fixed** — нельзя передать лидерство другому агенту
- **Permissions set at spawn** — все teammates стартуют с permission mode лида. Можно изменить после старта, но нельзя задать индивидуально при спауне
- **Split panes** — требуется tmux или iTerm2 для отображения
- **SendMessage silent loss** — сообщения молча теряются при несовпадении имени получателя (Issue #25135)
- **Inbox polling broken on tmux** — teammates на tmux backend не читают inbox вообще (Issue #23415)
- **VS Code extension** — Agent Teams tools (TeammateTool, SendMessage, spawnTeam) недоступны в VS Code extension (Issue #28048)
- **Idle nudge timing** — агенты уходят в idle до получения сообщений, не различая "ожидание" и "нечего делать" (Issue #28075)

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
| Все субагенты | Бесконечный цикл без maxTurns, 153GB output (#28148) | **Всегда** указывать `maxTurns` в frontmatter |
| Research (параллельный запуск) | JavaScript heap OOM (#19100), context overflow (#23463), compaction cascade (#27794) | Ограничивать до 2-3 параллельных субагентов; `model: haiku`; файловые артефакты |
| Research (background: true) | Read tool file_path dropped (#27657) | Не использовать `background: true` для субагентов, активно читающих файлы |
| Research (isolation: worktree) | Worktree CWD leaks в parent (#28017) | После worktree-субагентов явно проверять CWD; абсолютные пути |
| Research (isolation: worktree) | Path resolution bug (#17927) | Использовать абсолютные пути в промтах субагентов |
| Research (isolation: worktree) | Task list leak (#24754) | Не полагаться на task lists; файловые артефакты или `CLAUDE_CODE_TASK_LIST_ID` |
| Research (isolation: worktree) | EnterWorktree branches от main, не HEAD (#27134) | Убедиться, что Research запускается из нужной ветки |
| Research (isolation: worktree) | Nested worktrees (#27974) | Не вызывать EnterWorktree из существующего worktree |
| Research (isolation: worktree) | Skills из repo root, не worktree (#27985) | Учитывать при модификации skills на feature branches |
| Research (isolation: worktree) | `--worktree` flag broken v2.1.50 (#27778) | Использовать `isolation: worktree` в frontmatter вместо CLI-флага |
| Research (isolation: worktree) | Commands duplication (#27069) | Косметическая проблема, не критично |
| Research (isolation: worktree) | Nested worktrees при CWD drift (#27881) | После compaction проверять CWD; ограничивать длительность сессий |
| Параллельные сессии | MCP calls к неправильному серверу (#28093) | Изолировать MCP-серверы между параллельными сессиями |
| Параллельные сессии | /rewind уничтожает changes другой сессии (#28078) | Использовать `isolation: worktree`; не применять /rewind при параллельных сессиях |
| Mixed-model workflows | MAX_THINKING_TOKENS crash субагентов (#27429) | Установить ≤30000 или не использовать при mixed models |
| Длительные сессии | Memory leak 58GB+ (#27946) | Периодический перезапуск; мониторинг памяти; CLI вместо VS Code |
| Design/Plan (write артефакты) | Субагенты молча не пишут файлы (#13890) | Проверять наличие output-файлов после завершения субагента |
| Research (background: true) | Background agents bypass Stop hooks (#25147) + ложный родительский Stop (#24421) | Не использовать `background: true` для агентов с quality gates |
| Research (background: true) | TaskOutput returns raw JSONL (#17591) | Использовать файловые артефакты вместо `TaskOutput` |
| Implementation (Agent Teams) | Experimental, silent message loss (#25135), inbox polling broken on tmux (#23415), idle nudge timing (#28075) | Использовать Subagents + SubagentStop вместо Agent Teams для начала |
| Coordination (tmux + --worktree) | --tmux --worktree bug (#27562); --tmux requires --worktree | Не комбинировать --tmux и --worktree через CLI |
| Coordination (worktree + git hooks) | `claude --worktree` перезаписывает core.hooksPath (#27474) | Проверить core.hooksPath до и после; не использовать с husky/custom hooks |
| Coordination (WorktreeCreate hooks) | WorktreeCreate hooks → silent hang (#27467/#27963) | Только абсолютный путь на stdout; всегда exit 0 при успехе |
| Agent Teams (SendMessage) | Messages sent to agentType instead of name (#25694) | Точные имена; предпочитать Subagents |
| Security (permission deny) | **[SECURITY]** Deny rules bypass через Bash grep/Glob (#28008) | Не хранить секреты в рабочей директории; `disallowedTools: Bash` для ограниченных субагентов |
| Security (Edit tool) | **[SECURITY]** Edit tool permission bypass (#25168) | Мониторить Edit calls; `disallowedTools: Edit` для read-only субагентов |
| Параллельные instances | 100% CPU hang с hooks (regression #22172) | Мониторить CPU; ограничить parallel instances с hooks |
| Quality gates (PreToolUse) | **[SECURITY]** PreToolUse hooks обходятся субагентами (#21460) | Ограничивать tools через frontmatter `tools`/`disallowedTools`, не через PreToolUse hooks |
| Quality gates (Agent Teams) | Frontmatter hooks не работают для team-spawned agents (#27655) | Определять hooks в settings.json, не в frontmatter |
| Quality gates (SubagentStop) | prompt/agent hooks не блокируют (#20221) | Использовать **только** `type: "command"` для quality gates |
| Quality gates (SubagentStop) | command hooks ~42% failure rate (#27755) | `type: command` необходим, но не гарантирован. **CI — обязательный fallback** |
| Quality gates (prompt hooks) | Экспоненциальный рост payload (#17249), data-loss конфигурации (#24920), не блокируют (#20221) | **Не использовать `type: "prompt"` в production** (подкреплено тремя багами) |
| Quality gates | — | SubagentStop надёжнее TeammateIdle для текущего состояния |
| Subagent tools/disallowedTools | Не блокирует MCP tools (#25589) | Не подключать ненужные mcpServers к субагентам |
| Skills allowed-tools | Не enforce-ится (#14956) | Ограничивать инструменты через subagent `tools`, не через skills |
| Subagent resume | Fails с 3+ tool uses (#20942) | Не полагаться на resume для долгих субагентов |
| Subagent + skills | Crash при несуществующем skill (#18057) | Проверять наличие skill перед делегированием |
| Background + /compact | `/compact` блокируется при активном background task (#24220) | Не запускать длительные background-задачи с интенсивной основной сессией |
| PermissionRequest hooks | Hook decisions ignored, диалог всегда появляется (#19298) | Использовать PreToolUse для блокировки; `permissionMode` в frontmatter |

---

## Принципы реализации

- **Всегда указывать `maxTurns` в frontmatter каждого субагента** — без ограничения субагент может генерировать 153GB+ output (#28148)
- **PreToolUse hooks НЕ являются security boundary для субагентов** — субагенты полностью обходят их (#21460)
- **Ограничивать параллельные субагенты до 2-3** — OOM crash при большем количестве (#19100)
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
- **Permission deny rules не обеспечивают полную изоляцию** — Bash grep/Glob могут утечь данные (#28008). Не хранить секреты в рабочей директории
- **Не комбинировать `--tmux` и `--worktree`** через CLI (#27562)
- **Файловые артефакты вместо task lists** при работе с worktrees — task state leaks (#24754)
- **Не делегировать skill invocation субагентам** без проверки наличия skill — crash всего CLI (#18057)
- **Проверять CWD после compaction** при использовании worktree-субагентов — CWD drift может нарушить isolation (#27881)
- **MAX_THINKING_TOKENS ≤30000** при mixed-model workflows — или не использовать, если субагенты на Sonnet/Haiku (#27429)
