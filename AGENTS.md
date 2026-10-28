# Dakhl_Restaurant — project rules and agent workflow

Adopted by the owner on 2026-10-28 from the supplied universal rules and phase-tracker template. Applies to this project; the source Vault files and other projects are not modified.

Read AGENTS.md, [PLANS.md](PLANS.md) and [PHASES.md](PHASES.md) before phase work. [PROMPTS.md](PROMPTS.md) contains the joint engine/app workflow prompts. The [workflow source record](docs/reference/workflow/README.md) preserves provenance.

## Application to this project

- Canonical project name: **Dakhl_Restaurant** (owner correction, 2026-10-28). Use it for current project, planning, agent and Penpot names. Legacy Electron names, source/screenshot hashes, archived evidence, `project-daftar`, `daftar_memory` and the memory selector `daftar` remain compatibility identifiers, not the current project name. [Naming record](docs/decisions/0016-dakhl-restaurant-project-name.md).

- Current user instructions govern scope. The adopted universal workflow and the restaurant-specific rules below apply together. Retain single-restaurant, Arabic RTL/IQD, offline-data and historical-record protections; do not import the stack or product scope of another project.
- Owner direction2026-10-28: develop Madar_Engine alongside this app. Shared engine contracts/business capabilities/reusable adapters live only in Madar_Engine; consume its packages here, never copy/fork engine source. App UI, restaurant workflows, document composition and app-specific safeguards stay here. Read both projects' current scope before cross-project changes; do not add Madar's proposed cloud stack or unresolved financial policies to this offline app. [Boundary decision](docs/decisions/0018-madar-engine-boundary.md).
- Flutter work belongs at the root. Preserve electron-reference/ and keep the detailed plan/screenshots in docs/planning/flutter-rebuild/.
- PLANS.md defines the current 12 phases (00–11) and incorporates their detailed scope. PHASES.md is authoritative for execution status and completion evidence. Published plan pages do not override the tracker.
- The owner's screenshot-reproduction direction is approved as intent, not evidence of design validation or approval. On 2026-10-28 the owner explicitly replaced Figma with **Penpot**. Penpot is the design/reference-validation destination for this project; the approval gate remains mandatory. The Figma wording in the preserved universal source below is superseded only as to the tool. Non-UI phases record Design: N/A; reassess when UI enters scope.
- Reuse one Penpot project/file/page for all future create/recreate-design requests: project **Dakhl_Restaurant**, file **Dakhl_Restaurant · Phase designs & wireframes**, page **Dakhl_Restaurant · Designs & Wireframes / التصاميم**. [Canonical page](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455). Keep phase versions in named boards on that page, preserve prior work, and use computer use if MCP is blocked. Phase 00's current design prerequisite covers only its three listed desktop screenshots and matching wireframes. [Decision and scope](docs/decisions/0015-penpot-design-workspace.md).
- For each implementation phase, create a dedicated branch/worktree and a traceable PR, preserving existing work. Never reset, discard or silently include unrelated changes. The current rules adoption is a documentation/configuration chore, not the start or completion of phase 00.
- DONE requires all applicable tests/CI, independent review, user approval, merged PR and applicable release/rollback evidence. Missing design, hardware, signing or access remains pending/blocked, never passed. Never merge without the owner’s approval; never automatically start the next phase.
- Use the Lead plus appropriate specialist agents automatically as described below; independent Workers have non-overlapping ownership and cannot self-approve. Custom role instructions do not establish separate permissions. Do not change model/provider or permission settings merely to configure these roles.
- The 12 phases initially started as TODO; use PHASES.md for current execution state. Earlier Electron tests, captures and folder preparation are reference evidence, not proof that any Flutter phase passed.

## Standing rule: engine and app develop side by side

Owner instruction,2026-10-28; always applicable to work on these projects, not only to extraction or a particular phase. Apply it during research, design, planning, coding, execution, testing, review, documentation, dependency upgrades and delivery. Follow the joint PROMPTS.md workflow; the Lead must include this rule in every specialist brief.

- Before changing anything, identify the Madar responsibility, the app responsibility and their public contract. Read the relevant current rules/plans/trackers and source documentation from both projects. Record N/A with a reason when one side is unaffected; do not add unnecessary changes.
- Madar_Engine is the sole source of shared business rules, contracts and reusable adapters. Keep its pure Dart code independent of Flutter, databases/cloud and hardware; optional integrations live in separate adapters. Reuse existing capabilities before adding them and implement new shared behavior there with concrete consumer/conformance tests. No copied/forked engine implementation inside apps, and no engine dependency on consumer code.
- Dakhl_Restaurant owns its UI/ViewModels, restaurant workflows, presentation/document composition and app-specific safeguards. It consumes a reviewed, versioned engine revision. Preserve one-restaurant/offline/Arabic RTL/IQD/history constraints; shared engine work does not add cloud/auth/multitenancy or settle open financial/recovery policies.
- Keep each project's own plan/tracker, contracts/API/usage examples, decisions, tests and dated evidence current for its affected scope. Cross-link work and engine revisions; do not substitute one project's evidence for another's or duplicate writable engine authority in the app. Keep project-madar and project-daftar memory separate.
- The goal is an engine future apps can build on without rebuilding shared foundations. Validate reusable boundaries and consumer compatibility; avoid speculative abstractions and do not claim a supported release before its documented gates pass. Design, implementation, tests and delivery approvals remain separate.

## Adopted universal rules — full source text

# Universal Development Rules

Applies to AlDakhl, Dakhl_Restaurant, Madar Engine, and future projects.

All agents must follow AGENTS.md, PLANS.md, and PHASES.md.

## 1. Agent Responsibilities

### Lead / Architect Agent

- Orchestrates the entire workflow.
    
- Launches and coordinates specialized agents.
    
- Assigns tasks and manages dependencies.
    
- Maintains Git isolation and the phase tracker.
    
- Integrates worker results and resolves conflicts.
    
- Prepares pull requests and manages completion.
    

### UX Agent

- Researches suitable UI/UX references.
    
- Creates or adjusts designs in Figma.
    
- Validates usability, accessibility, responsiveness, and all relevant UI states.
    
- Requires user approval before implementation.
    
- Only used for phases involving UI/UX.
    

### Planner Agent

- Read-only planning; never implements code.
    
- Inspects relevant project files and requirements.
    
- Defines exactly what needs implementation.
    
- Identifies required references, dependencies, tests, benchmarks, and CI changes.
    
- Produces short, actionable plans without unnecessary context.
    
- Never suggests unrelated features or speculative improvements.
    

### Worker Agents

- Implement independently assigned tasks.
    
- Use fresh, focused context windows.
    
- May specialize in UI, business logic, backend, testing, or infrastructure.
    
- Write meaningful tests before implementing behavior.
    
- Establish measurable performance baselines before optimization.
    
- Respect assigned ownership and existing architecture.
    

### Independent Reviewer Agent

- Independently reviews work completed by Workers.
    
- Verifies logic, correctness, architecture, and MVVM compliance.
    
- Evaluates whether automated tests cover meaningful real-world scenarios.
    
- Identifies missing edge cases and regressions.
    
- Validates benchmark methodology, baseline measurements, and improvements.
    
- Reviews security, data integrity, and production readiness.
    
- Reports actionable findings and requires re-verification.
    
- Prefer a different model/provider where available.
    

## 2. Multi-Agent Orchestration

- The Lead launches appropriate agents automatically for each workflow step.
    
- Use parallel Workers only for independent tasks.
    
- Assign explicit task ownership, interfaces, and non-overlapping file boundaries.
    
- Never allow agents to overwrite or interfere with one another's work.
    
- Workers cannot approve their own implementations.
    
- The Reviewer must be independent of implementation.
    
- Keep agent context focused on the files and information relevant to its task.
    

## 3. Design Rules

- Every UI phase requires an approved Figma design or suitable reference validated in Figma.
    
- Validate responsive layouts, accessibility, usability, and loading, empty, error, and success states where relevant.
    
- Do not implement unapproved design changes.
    
- For non-UI phases, record Design: N/A.
    

## 4. Git Isolation

- Every phase has its own dedicated branch/worktree.
    
- Every phase must be traceable through a pull request.
    
- Protect `main` from unfinished changes.
    
- Never merge without user approval.
    
- Prevent cross-agent interference and unrelated modifications.
    

## 5. Architecture & Implementation

- Enforce MVVM for applicable application UI layers.
    
- Respect existing architecture, conventions, and module boundaries.
    
- Maintain clear separation of responsibilities.
    
- Avoid unnecessary dependencies, abstractions, or refactoring.
    
- Never alter unrelated features without authorization.
    

## 6. Testing & Numeric Benchmarks

### Automated Testing

- Write meaningful automated tests before implementing behavior.
    
- Cover normal usage, boundaries, invalid inputs, network errors, concurrency, race conditions, data failures, and recovery scenarios where relevant.
    
- Use appropriate unit, integration, and end-to-end tests.
    
- Reject superficial tests, meaningless assertions, and artificial coverage.
    
- Tests must validate actual requirements and realistic behavior.
    
- No implementation is considered complete until all required automated tests pass.
    

### Benchmarks

- Establish numeric baselines before optimization.
    
- Never accept vague goals such as "make it faster."
    
- Measure relevant metrics such as latency, memory, startup time, rendering performance, or throughput.
    
- Record baseline values, measurement conditions, and acceptable targets.
    
- Automatically compare results after changes wherever practical.
    
- Reject meaningless benchmarks or improvements without evidence.
    
- Benchmarks are optional when no meaningful performance requirement exists; document N/A.
    

## 7. CI & Quality Gates

- Existing mandatory CI checks must pass for every PR.
    
- Add targeted CI tests, architecture checks, or regression checks when required.
    
- Validate linting, static analysis, automated tests, and builds as applicable.
    
- Avoid redundant or unnecessarily expensive CI pipelines.
    
- Never mark failed, skipped, or unverified required checks as passed.
    

## 8. Security & Production Readiness

- Review authorization, secrets, data integrity, and security-sensitive behavior.
    
- Validate database changes, migrations, and recovery where applicable.
    
- Run staging validation and smoke tests for deployable changes.
    
- Verify rollback procedures when necessary.
    
- Resolve blocking review findings before final approval.
    

## 9. Phase Tracking & Documentation

- `PLANS.md` defines the phases and their scope.
    
- `PHASES.md` records each phase's status, branch, PR, design approval, tests, benchmarks, and completion.
    
- Update the tracker as work progresses.
    
- Record important architecture decisions, benchmark results, discovered issues, and lessons learned.
    
- Keep documentation useful, concise, and relevant.
    
- Mark a phase DONE only after all required checks, approval, merge, and applicable release validation.
    
- Never automatically start the next phase.
    

## 10. Prompt & Communication Rules

- Prompts define the objective, acceptance criteria, and hard boundaries.
    
- Avoid micromanaging implementation details.
    
- Let the Lead and specialized agents determine the execution strategy.
    
- Keep plans, progress updates, and summaries concise.
    
- Report blockers and failed verification explicitly.
    
- Never claim work is verified when it has not been executed and checked.


Final structure:
Project/
├── AGENTS.md          # Permanent rules + agent roles
├── PLANS.md           # Project phases and scope
├── PHASES.md          # Phase tracker
├── PROMPTS.md         # 6 reusable execution prompts
├── docs/
│   └── phases/        # Evidence and decisions
└── .codex/
    └── agents/
        ├── planner.toml
        ├── ux.toml
        └── reviewer.toml

## Existing restaurant-specific rules — retained

# Dakhl_Restaurant — قواعد المشروع والتوثيق والذاكرة

الحالة: تعليمات معتمدة. التاريخ: 2026-10-16. المصدر: توجيه مالك المشروع ومراجعة الملفات الحالية.

## النطاق

### تنظيم المجلدات — 2026-10-28

جذر المشروع مخصص لإعادة البناء بـFlutter وDart. التطبيق القديم ومكتبته واختباراته في `electron-reference/` للرجوع إليها؛ لا تنفذ ميزات Flutter داخله. الخطة والصور تبقى في `docs/planning/flutter-rebuild/` خارج مجلد المرجع، والوثائق والذاكرة وGit تبقى مشتركة في الجذر. روابط `docs/`, `outputs/`, `dist/`, `design/` داخل المرجع تشير إلى مجلدات الجذر ولا تعني نقلها. اختبار المرجع من الجذر: `npm --prefix electron-reference test`. لا تشغّل التطبيق المعتاد لمجرد فحص النقل لأنه قد يقرأ حسابات المطعم. [قرار التنظيم](docs/decisions/0013-electron-reference-folder.md).

هذا المشروع خاص **بمطعم واحد فقط**. اقرأ `docs/reference/project-scope.md` و`docs/README.md` أولاً. لا تحوّله تلقائياً إلى منصة لعدة مطاعم أو منتج عام. الفواتير والحملات والأفكار والتطبيق الخاص تخدم المطعم نفسه. هذه التعليمات توثّق الاتجاه؛ لا تعني أن الحملات منفّذة داخل التطبيق.

## قبل العمل

1. استرجع ما يخص المهمة من بنك **project-daftar** باستخدام `daftar_memory` أو `./scripts/memory recall --query 'موضوع المهمة'`.
2. راجع الملفات الحالية التي تشير إليها الذاكرة. ملفات المشروع وتوجيه المستخدم الحالي تتقدم على الذاكرة التاريخية. لا تستخدم بنك AlDakhl أو تفترض أن تقنياته تخص Dakhl_Restaurant.
3. اقرأ `docs/reference/accounting-rules.md` قبل أي تغيير مالي، و`docs/reference/application.md` قبل تغيير الحفظ أو التقارير. للواجهة اقرأ `.impeccable.md`.
4. عند تعطل الذاكرة، تابع العمل المستقل الآمن وسجّل التعطل؛ لا تدّعِ استرجاعاً أو مزامنة ناجحين.

## الحفاظ على التطبيق

- التطبيق الحالي Electron وJavaScript، وبياناته محلية بصيغة JSON. لا تفرض تقنية أو قاعدة بيانات جديدة بسبب أمثلة من مشروع آخر.
- حافظ على الحسابات القديمة، والنسخ الاحتياطية، والتحقق قبل الحفظ والاستيراد. أي تغيير صيغة يحتاج ترحيلاً يحافظ على السجلات واختباراً مناسباً.
- سلفة العمال مستقلة عن المصاريف والقاصة. أعداد الدجاج خارج المبالغ المالية. قائمة المورد تسجل الدين؛ التسديد يظهر كمصروف ويخصم من مصدره مرة واحدة.
- الرصيد المتبقي والقاصة والرصيد الكلي ليست تسميات بديلة لصافي الربح. وثّق معنى أي تقرير قبل تنفيذه.
- استخدم العربية RTL والأخضر الهادئ والخلفية الفاتحة. أثناء التحقق لا تحفظ بيانات تجريبية في حسابات المطعم؛ استخدم الاختبارات ذات البيانات المعزولة.
- طلب توثيق أو تسجيل فكرة لا يفوّض نشر إعلان أو صرف ميزانية أو مراسلة أشخاص أو تعديل حسابات فعلية.

## أثناء العمل وقبل الإكمال

1. سجّل الأفكار والحملات في `docs/planning/`، والسياسات في `docs/reference/`، وخطوات العمل في `docs/how-to/`.
2. وثّق القرار المهم وسببه في `docs/decisions/`؛ احتفظ بالقرار السابق مع رابط ما حل محله.
3. حدّث الوثائق المتأثرة وسجّل نتيجة المهمة في `docs/log/YYYY-MM-DD-topic.md`: الطلب، التغيير، السبب، التحقق الفعلي، القيود والخطوة التالية.
4. ميّز مقترحاً، ومعتمداً، ومنفّذاً، ومتحققاً منه. لا تسجّل نتائج اختبارات أو حملات بلا دليل. لا تصنع أفكاراً أو حملات باسم المالك لمجرد ملء السجل.
5. شغّل التحقق المناسب للتغيير. تغييرات التطبيق تحتاج `npm test` وما يلزم للمسار المتأثر؛ التوثيق وحده يحتاج مراجعة المصدر والروابط ودقة الحالة.
6. شغّل `./scripts/memory sync` ثم `./scripts/memory check`؛ إرسال الطلب للطابور ليس اكتمالاً. أعد الفحص عند وجود عمليات معلقة وصرّح بأي فشل أو انتظار.

## حدود ذاكرة المشروع

Hindsight فهرس مشتق للتوثيق وقرارات التطوير، وليس مخزن حسابات المطعم أو جزءاً من تشغيل التطبيق. الإعداد المشترك الحالي يعطل حفظ المحادثات الخام (`retainSessions: false`)؛ احفظ المعرفة المفيدة في الوثائق ثم زامنها.

لا تفهرس ملفات الحسابات أو نسخها أو فواتير فعلية أو بيانات عملاء أو هواتف أو كلمات مرور أو مفاتيح أو `.env` أو تفريغ المحادثات. ضع فقط المعلومات اللازمة للمتابعة، وأبقِ أمثلة القوالب خالية. استخدم `<!-- hindsight:ignore -->` على سطر مستقل لاستثناء مستند؛ راجع دليل الذاكرة قبل إضافة مسارات للفهرسة.

## Selected project skills — 2026-10-28

Use the nine task-specific skills in [.agents/skills/README.md](.agents/skills/README.md) only when relevant. Prefer these project-local sources over global skills with the same names. Use local `flutter-testing` for test guidance and `documentation-and-adrs` instead of SLine `docs-sync`. Do not invoke SLine-specific scaffolders, architecture, integration-test or caching skills for Dakhl_Restaurant. Global skills are retained for other projects. Skills do not override project scope, financial contracts, approved architecture, design gates or merge approval.

For Penpot tasks, use the reusable [Penpot skill](/Users/eros/.codex/skills/penpot/SKILL.md). It contains a minimal native-export pilot workflow, the existing local connection, screenshot-recreation mechanics and the documented mistakes from phase00. Load detailed failure references only when relevant; the skill does not waive project scope or design approval.
