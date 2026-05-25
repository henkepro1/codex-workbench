# Token Usage Tracking

This workbench can keep an optional token usage ledger for requests where cost matters.

The runtime does not expose hidden platform limit accounting to project scripts. That means exact numbers can only be recorded when the model/tool runtime explicitly reports them. Otherwise, records must be marked as estimates.

## Opt In

Tracking is off by default. Enabling tracking does not automatically read Codex's hidden token/limit usage. It only allows manual records to be written.

Enable it for the workspace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\record-token-usage.ps1 -Enable -Scope workspace
```

Enable it for Tower Heroes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\record-token-usage.ps1 -Enable -Scope project -Slug tower-heroes
```

Disable it again:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\record-token-usage.ps1 -Disable -Scope project -Slug tower-heroes
```

## What Gets Stored

Records are compact JSONL entries under:

- `.ai/token-usage/ledger.jsonl`
- `projects/<slug>/.ai/token-usage/ledger.jsonl`

Do store:

- request title and short summary
- exact or estimated input/output/tool-output token counts
- culprit categories such as `large_context_load`, `unity_mcp_validation`, `long_tool_output`, `broad_source_search`, `diff_review`, or `live_debugging_loop`
- mitigation notes for next time

Do not store:

- full transcripts
- full command output
- full diffs
- screenshots or logs
- copied source files

## Recording A Request

After a Codex prompt finishes, ask Codex for a non-zero estimate:

```text
Estimate token usage for the request we just completed.
Return a PowerShell record-token-usage command for tower-heroes with:
- Measurement estimated
- non-zero InputTokens, OutputTokens, and ToolOutputTokens
- culprit categories
- mitigation notes
Do not use 0 token counts unless the request truly used no tokens.
```

Then record the request. Replace the numbers with the estimate from Codex or your own estimate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\record-token-usage.ps1 `
  -Scope project `
  -Slug tower-heroes `
  -Title "Tower placement performance and stuck-enemy pass" `
  -Measurement estimated `
  -InputTokens 65000 `
  -OutputTokens 12000 `
  -ToolOutputTokens 28000 `
  -Culprit conversation_history,large_context_load,unity_mcp_validation,broad_source_search,long_tool_output,live_debugging_loop `
  -Mitigation "Start with a retrieval plan; cap diagnostic/log output; prefer targeted rg reads; summarize Unity validation instead of carrying full outputs."
```

## Summaries

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\summarize-token-usage.ps1 -Scope project -Slug tower-heroes
```

The summary ranks culprit categories by recorded token volume and writes `summary.json` next to the ledger.

## Interpreting Culprits

Common high-cost factors:

- `large_context_load`: too many indexes, docs, logs, or source files loaded into context
- `long_tool_output`: command output was large or repeated
- `broad_source_search`: search scope was too wide or repeated
- `unity_mcp_validation`: Unity MCP calls, console reads, validation, profiler output
- `live_debugging_loop`: repeated profile, edit, compile, and validation cycles
- `diff_review`: large diffs or generated patches reviewed in context
- `conversation_history`: long active thread carried forward

Best reductions usually come from starting broad tasks with a retrieval plan, using targeted `rg`, limiting log excerpts, and recording summaries instead of carrying raw outputs.
