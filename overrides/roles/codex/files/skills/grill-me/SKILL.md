---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

# Grill Me

Use this skill to stress-test a plan, design, architecture, product decision, or implementation approach by interviewing the user until the plan is specific, internally consistent, and mutually understood.

## Workflow

1. Identify the current plan or design under discussion.
2. If any question can be answered by inspecting the codebase, inspect the codebase first instead of asking the user.
3. Ask one question at a time.
4. For each question, provide a recommended answer before waiting for the user's response.
5. Walk the design tree branch by branch, resolving dependencies between decisions before moving to downstream choices.
6. Keep asking until the important assumptions, tradeoffs, constraints, failure modes, implementation details, and success criteria are explicit.

## Question Style

- Be direct and specific.
- Prefer questions that force a decision over broad prompts.
- Make dependencies clear when a later decision depends on the current answer.
- When the user answers, restate the resolved decision briefly if needed, then move to the next unresolved branch.
- Do not ask multiple questions at once.

## Recommended Answer Format

For each turn, use:

```markdown
Question: ...

Recommended answer: ...
```

Then wait for the user.
