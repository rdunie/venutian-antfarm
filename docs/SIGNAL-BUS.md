# Signal Bus

Event communication libraries for the agent fleet harness. Provides shared read and write abstractions over the metrics event log.

## Write Path

### Using the emit library

Source `ops/lib/signal-emit.sh` and call `signal_emit`:

```bash
source ops/lib/signal-emit.sh
signal_emit '{"ts":"...","event":"my-event","agent":"my-agent"}'
```

The library reads backend config from `fleet-config.json` (jsonl, webhook, etc.) and dispatches accordingly. Always persists locally to `events.jsonl`.

### Using metrics-log.sh (CLI)

For structured event emission with validation, use the CLI entry point:

```bash
ops/metrics-log.sh <event-type> [--flags...]
```

This validates event types and constructs JSON before calling `signal_emit`.

## Read Path

### CLI usage

```bash
ops/lib/signal-read.sh --type feedback-proposed --since 7d
ops/lib/signal-read.sh --topic feedback --agent backend-specialist
ops/lib/signal-read.sh --topic item --format count --source local
```

### Sourceable library

```bash
source ops/lib/signal-read.sh
signal_query --topic feedback --since 30d
```

### Flags

| Flag       | Description                                          |
| ---------- | ---------------------------------------------------- |
| `--type`   | Exact event type match                               |
| `--topic`  | Prefix match (e.g., `feedback` matches `feedback-*`) |
| `--agent`  | Filter by agent field                                |
| `--since`  | Time window (`Nd` or `Nh`)                           |
| `--source` | Event source (`local` in v1)                         |
| `--format` | `json` (default) or `count`                          |

## Topics

Topics are derived from event-type prefixes (split on first `-`):

| Topic        | Matches                                                                       |
| ------------ | ----------------------------------------------------------------------------- |
| `feedback`   | feedback-proposed, feedback-formalized, feedback-rejected, feedback-escalated |
| `compliance` | compliance-proposed, compliance-approved, compliance-violation, ...           |
| `item`       | item-promoted, item-accepted                                                  |
| `reward`     | reward-issued                                                                 |
| `agent`      | agent-invoked                                                                 |

No configuration needed — the event-type prefix IS the topic.

## Extension Points

The `--source` flag abstracts the event store. v1 supports `local` (reads `events.jsonl`). Future sources can be added without changing the consumer API:

- `--source remote --endpoint <url>` — remote event store
- `--source aggregate` — merge multiple sources
