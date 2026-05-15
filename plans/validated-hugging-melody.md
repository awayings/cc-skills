# Plan: Hex Deserialization + * Cluster Sampling

## Context

The MemoryIncrementAnalyzer processes Redis MONITOR output. Two issues exist:
1. Keys containing `\xNN` hex escapes (Java serialized objects) are not deserialized — they appear as raw hex garbage in reports
2. The `*` cluster (uncategorized no-colon keys from PrefixTrie) shows no sample keys — users can't see what's in it

A `KeyDeserializer` class already exists at `KeyDeserializer.java:14` with JDK deserialization logic (`deserializeJdk` at line 57), UTF-8 fallback, and hex fallback. It takes `byte[]` directly. It is simply not wired in.

## Changes

### 1. CommandParser — fix tokenizer + wire KeyDeserializer

**File:** `redis-monitor-analyzer/src/main/java/com/yj/redis/monitor/analyzer/increment/CommandParser.java`

- **Fix `tokenize()` (line 74):** The while loop at line 90 scans for `"` without handling `\"`. Change it to skip `\` + next char (treating `\"`, `\\`, `\xNN` etc. as inside-token content). This prevents truncated tokens.

- **Add `static byte[] decodeEscapesToBytes(String escaped)`:** Convert `\xNN` → byte, `\"` → `"`, `\\` → `\`, `\n` → newline, `\r` → CR, `\t` → tab. Returns the raw byte array for the token content.

- **In `parse()` (line 43):** After extracting the key, if it contains `\x`, call `decodeEscapesToBytes(key)` then `new KeyDeserializer(true).deserialize(bytes)` to get the real key. Use the result to replace the key string in the ParsedCommand.

### 2. PatternStats — add sample key storage

**File:** `redis-monitor-analyzer/src/main/java/com/yj/redis/monitor/analyzer/increment/PatternStats.java`

- Add `private final List<String> sampleKeys = new ArrayList<>();` and `private static final int MAX_SAMPLE_KEYS = 10;`
- Add `public void addSampleKey(String key)` — adds if under `MAX_SAMPLE_KEYS`
- Add `public List<String> getSampleKeys()` — returns the list

### 3. PatternStatsAggregator — delegate sample key storage

**File:** `redis-monitor-analyzer/src/main/java/com/yj/redis/monitor/analyzer/increment/PatternStatsAggregator.java`

- Add `public void addSampleKey(String pattern, String key)` — delegates to `statsMap.get(pattern).addSampleKey(key)` if stats entry exists

### 4. MemoryIncrementAnalyzer — collect * samples

**File:** `redis-monitor-analyzer/src/main/java/com/yj/redis/monitor/analyzer/increment/MemoryIncrementAnalyzer.java`

- In `processLine()` at line 279, after `clusterer.cluster()`, add: if `"*".equals(pattern)`, call `aggregator.addSampleKey("*", cmd.getKey())`

### 5. ReportPrinter — display * samples

**File:** `redis-monitor-analyzer/src/main/java/com/yj/redis/monitor/analyzer/increment/ReportPrinter.java`

- **`printConsole()` and `printConsoleFile()`:** After the main table, if any pattern in `topPatterns` is `"*"` and has non-empty `getSampleKeys()`, print a "Sample keys for *" section showing the 10 sample keys
- **`printJson()` and `printJsonFile()`:** For the `*` pattern entry, include `"sampleKeys": [...]` array

## Verification

1. Run existing tests: `mvn test -pl redis-monitor-analyzer`
2. The `KeyDeserializerTest` already covers `testJdkFirstThenStringFallback` — this validates the deserialization logic works
3. `CommandParserTest` covers basic parsing — add a test for `\"` in tokens and for `\xNN` hex escape handling
4. Create a small `.log` file with `INCRBY "\xac\xed\x00\x05t\x00\x02\"\"" "1"` and verify file mode produces a human-readable key in the report
5. Verify `*` cluster shows sample keys in both console and JSON output
