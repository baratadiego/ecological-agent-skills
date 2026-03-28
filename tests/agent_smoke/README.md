# Agent Smoke Tests

Validation suite for verifying that the AI agent correctly routes prompts to the appropriate skills.

## Purpose

These tests are designed for **human validation**, not automated execution. Each test case contains a prompt that should be given to an AI agent operating with this skill library. The human evaluator then verifies whether the correct skills were invoked in the expected order.

## How to Run

1. Open a session with the AI agent (Claude Code, Gemini CLI, GitHub Copilot, Cursor, or any compatible agent)
2. Ensure the agent has loaded `AGENT_CONTEXT.md` and `skills/SKILL_INDEX.json`
3. For each test case in `smoke_test_cases.json`:
   a. Copy the `input_prompt` and send it to the agent
   b. Observe which skills the agent invokes
   c. Record whether the expected skills were invoked in the correct order
   d. Note any unexpected skill invocations
   e. For edge cases, verify the agent's response matches `expected_decision`

## Recording Results

Save results as `smoke_test_results_{YYYY-MM-DD}.json`:

```json
{
  "date": "2026-03-06",
  "agent": "Claude Code / Gemini CLI / Copilot / Cursor / etc.",
  "model": "model identifier",
  "results": [
    {
      "test_id": "smoke_001",
      "passed": true,
      "skills_invoked": ["ecological-data-foundation", "..."],
      "correct_order": true,
      "notes": ""
    }
  ],
  "summary": {
    "total": 15,
    "passed": 14,
    "failed": 1,
    "pass_rate": 0.93
  }
}
```

## When to Run

- After any change to `AGENT_CONTEXT.md`
- After any change to `skills/SKILL_INDEX.json` (trigger keywords, dependencies)
- After adding a new skill
- Before each major release

## Test Categories

| Category | Test IDs | Description |
|----------|---------|-------------|
| Standard routing | 001, 003, 004, 006, 008, 009, 010 | Correct skill for prompt type |
| Multi-skill ordering | 001, 007, 011 | Multiple skills invoked in correct order |
| Edge cases | 002, 005, 012, 013 | Boundary conditions and decision points |
| Data source routing | 014, 015 | Correct data handling recommendations |
