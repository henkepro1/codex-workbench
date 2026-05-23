# Model Providers

Use this guide when choosing a model/provider for a new workbench session.

## Policy

Allowed:

- Local/free models running on this machine.
- Already-active user subscriptions explicitly selected by the user.

Blocked:

- New metered API usage.
- Hosted cloud model billing.
- Provider credits.
- New subscriptions or upgrades.
- Ollama cloud models.
- Anthropic Console/API billing.
- OpenAI API key billing.

Codex may suggest a provider when it clearly helps, but the user chooses. Do not auto-switch providers.

## Default Local Lane

Default:

```powershell
scripts\start-local-codex.ps1 -Slug tower-heroes
```

This launches Codex with:

```text
codex --oss --local-provider ollama -m qwen2.5-coder:7b
```

Use this for simple implementation, mechanical edits, workbench maintenance, and default review passes.

Fallback for lighter local work:

```powershell
scripts\start-local-codex.ps1 -Small
```

Check local availability:

```powershell
scripts\check-local-model.ps1 -Model qwen2.5-coder:7b
```

If Ollama or the model is missing, install/start/pull it manually. The workbench scripts do not install providers or pull models automatically.

## Claude Code Subscription Lane

Claude Code is allowed only when the user explicitly wants to use the existing Claude subscription.

Required guardrail:

```json
{
  "forceLoginMethod": "claudeai"
}
```

Store that in:

```text
~/.claude/settings.json
```

Launch:

```powershell
scripts\start-claude-code.ps1 -Model sonnet -Slug tower-heroes
```

Reviewer:

```powershell
scripts\run-claude-review.ps1 -Slug tower-heroes -Scope uncommitted -Model sonnet
```

Do not use Claude Code through Anthropic Console/API billing, API keys, Bedrock, Vertex, provider credits, or a new subscription.

## No-Extra-Spend Guard

Provider scripts call:

```powershell
scripts\assert-no-extra-spend.ps1
```

The guard blocks API-key or cloud-billing indicators such as:

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`
- `AZURE_OPENAI_API_KEY`
- `OLLAMA_API_KEY`
- non-local `OLLAMA_HOST`
- Claude Code login modes other than `claudeai`
- Bedrock/Vertex Claude Code routing flags

If a guard fails, fix the provider setup manually. Do not bypass it to continue.
