---
name: analyzing-root-field-access
description: Analyze root field read/write patterns of a complex function's entry parameter across its entire call chain. Classifies each field as read-only, write-then-read, read-then-write, or unused to determine external input requirements.
---

# Analyzing Root Field Access Patterns

## Overview

Analyze a complex function's entry parameter (typically a DTO/VO like `*Data` or `*Request`) to determine for each root field:
- Whether it is **read before written** (external input required)
- **written before read** (internally computed, no external input needed)
- **read-only** (consumed but never modified)
- **unused** (never touched in the call chain)

This is essential for understanding API contracts, refactoring DTOs, and eliminating unnecessary external parameters.

## When to Use

- Refactoring large DTOs and want to know which fields callers must provide
- Documenting API input requirements for a complex business operation
- Reviewing whether a field added to a DTO is actually consumed
- Migrating between service layers and need to verify data flow

**When NOT to use:**
- Simple CRUD operations with trivial parameter objects
- Fields inside nested collections (analyze the root DTO's direct fields only)

## Four Classifications

| Classification | Meaning | External Input? |
|---------------|---------|-----------------|
| **只读不写** (Read-only) | Only `getXxx()` calls, no `setXxx()` in call chain | **Required** |
| **先读后写** (Read-then-write) | First operation is `getXxx()`, later `setXxx()` overwrites | **Required** (may be overridden) |
| **先写后读** (Write-then-read) | First operation is `setXxx()`, later `getXxx()` consumes | **Not required** (internally computed) |
| **未使用** (Unused) | No `getXxx()` or `setXxx()` in the call chain | **Not required** |

## Analysis Workflow

### Step 1: Identify the Call Chain

Locate the target method and trace its downstream calls:

```
EntryMethod(ParameterType param)
  ├─ helperMethodA(param)
  ├─ helperMethodB(..., param)
  └─ service.call(..., param, ...)
     └─ serviceHelper(param)
```

Use `grep -rn "param\.\(get\|set\)"` across all files in the call chain.

### Step 2: Record All Access Points

For each file in the call chain, record every `getXxx()` and `setXxx()` on the parameter:

```
FileA.java:100  param.getFoo()    [READ]
FileA.java:120  param.setBar(x)   [WRITE]
FileB.java:80   param.getBar()    [READ]
```

### Step 3: Sort by Execution Order

Arrange all access points in code execution order (top-to-bottom within each method, following call order). The **first** operation on each field determines its classification:

- First = `get` → **先读后写** or **只读不写**
- First = `set` → **先写后读** or **只写不读**

### Step 4: Classify Each Field

| If first op is | And there is | Classification |
|---------------|-------------|----------------|
| `get` | a later `set` | **先读后写** |
| `get` | no `set` | **只读不写** |
| `set` | a later `get` | **先写后读** |
| `set` | no `get` | **只写不读** (treat as "未使用" for input purposes) |
| none | — | **未使用** |

### Step 5: Document with Evidence

For each field, document:
- Classification
- First access location (`File.java:line`)
- All access locations (if write-then-read, show where it's written and where consumed)
- Whether sub-fields are required (e.g., `addressDetailData.id` is required even if `addressDetailData` itself is read-then-write)

## Output Format

Produce a markdown report with these sections:

1. **Call Chain Overview** — method hierarchy diagram
2. **Read-only Fields** — fields callers must provide
3. **Read-then-write Fields** — fields callers provide but may be overridden
4. **Write-then-read Fields** — internally computed, callers need not provide
5. **Unused Fields** — present in DTO but not touched in call chain
6. **Summary Table** — all fields in one table

## Important Rules

1. **Follow code execution order, not file order.** A `set` in `FileB.java` may execute before a `get` in `FileA.java` if the call chain goes A → B → back to A.
2. **Check all downstream methods.** Don't stop at the entry method; follow the parameter through every method that receives it.
3. **Distinguish `set` on the DTO vs `set` on nested objects.** Only track operations on the root parameter itself.
4. **Sub-fields matter.** If `addressDetailData.id` is required, document it even though `addressDetailData` is classified as read-then-write.
5. **Conditional reads count.** A field accessed inside `if (gatewayNacosConfig.getWalletDisplay())` is still "read" for classification purposes.
