# ZLOG: implementation brief for Claude Code

## 1. Goal

Build a Log4j-style logging framework for ABAP on NetWeaver 7.5, for developer and operational logging.

It must provide:

- A one-line logging API, with hierarchical categories and levels
- Levels that can be changed in production at runtime, without a transport
- Pluggable appenders
- A run context, equivalent to Log4j's MDC / ThreadContext
- **A database table that stores complete JSON payloads and can be queried by people and AI tools**

BAL alone is not sufficient. It stays as one appender for support users, but `ZLOG_EVENT` is the system of record for developer, operational and AI access.

## 2. Clean-room rules

This is an original implementation.

- Do not open, search for, fetch, copy or translate source code from any existing logging project. This includes P-SLF4ABAP, ABAP Logger, abap-log, zlogging, ZCL_CLOUD_LOGGER, Log4j, Logback and SLF4J.
- Do not add any of these projects as a dependency.
- Work only from this brief, SAP's documentation and interfaces, and general logging concepts.
- Do not reuse object names, method signatures or file layouts from those projects.
- Record any external reference you use in `docs/references.md`, with its purpose. Stop and ask if a task appears to need third-party source code.

## 3. Constraints

- **Target:** ABAP 7.50. Do not use `CL_BALI_*`, ABAP Cloud-only APIs or syntax newer than 7.50.
- **Delivery format:** abapGit-serialized objects under `src/`.
- **Local checks:** add an `abaplint.json` set to version `v750` and keep it passing. Do not claim that code has been activated or that ABAP Unit tests have run unless they ran on an SAP system.
- **Failure behavior:** logging must never break the application. Catch `cx_root` at the appender boundary. A failing appender must not stop the other appenders, and it must not log through the framework.
- **Transaction behavior:** logging must never trigger a `COMMIT WORK` or `ROLLBACK WORK` in the caller's LUW. Use a secondary database connection for all persistence.

### Naming conventions

| Element | Rule | Example |
|---|---|---|
| Local variables | `l_` prefix | `l_event` |
| Importing parameters | `i_` prefix | `i_message` |
| Iterators | No prefix required | `LOOP AT m_appenders INTO DATA(appender)` |
| Returning parameters | `r_` prefix | `r_result` |
| Instance attributes | `m_` prefix | `m_threshold` |

## 4. Architecture

```text
Application code
   | l_log->info( i_message = 'Order {} imported' i_val1 = l_order_id )
   v
ZIF_LOG <-- ZCL_LOG_FACTORY=>get( 'ZSD.IMPORT.PRICING' )
   | level check against cached threshold (first operation, no allocation)
   | message formatting and payload serialization only if enabled
   | context added from ZCL_LOG_CONTEXT
   v
ZIF_LOG_APPENDER (one or more)
   |-- ZCL_LOG_APPENDER_EVENT   -> ZLOG_EVENT: full event and JSON payload
   |-- ZCL_LOG_APPENDER_BAL     -> SLG1: summary with reference to the event
   |-- ZCL_LOG_APPENDER_JOBLOG  -> job log in background runs
   `-- ZCL_LOG_APPENDER_MEMORY  -> unit tests
```

## 5. Objects to build

| Object | Purpose |
|---|---|
| `ZIF_LOG` | Logger API |
| `ZIF_LOG_SUPPLIER` | Deferred creation of expensive messages or payloads |
| `ZIF_LOG_APPENDER` | Appender contract: `append( )` and `flush( )` |
| `ZCL_LOG_FACTORY` | Creates and caches loggers per category; provides `flush_all( )` |
| `ZCL_LOG_LOGGER` | `ZIF_LOG` implementation |
| `ZCL_LOG_CONFIG` | Reads configuration and resolves rules |
| `ZCL_LOG_CONTEXT` | Run ID and key-value context |
| `ZCL_LOG_FORMATTER` | `{}` placeholder formatting and value conversion |
| `ZCL_LOG_JSON` | The only class that calls the JSON serializer |
| `ZCL_LOG_APPENDER_*` | EVENT, BAL, JOBLOG and MEMORY appenders |
| `ZCL_LOG_READER` | Reads events by run ID and filter, and returns JSON |
| `ZLOG_READ` | Report that outputs events as NDJSON for job spool access |
| `ZLOG_CLEANUP` | Retention job |
| `ZLOG_EVENT` | Event and payload table |
| `ZLOG_CONFIG` | Runtime configuration table and maintenance view |
| `ZLOG` (SLG0 object) | BAL log object |

## 6. Logger API

ABAP evaluates string templates before a method call, so disabled log statements must avoid them. Generic `ANY` parameters passed by reference let callers supply variables at almost no cost.

```abap
INTERFACE zif_log PUBLIC.
  CONSTANTS:
    BEGIN OF c_level,
      trace TYPE int1 VALUE 1,
      debug TYPE int1 VALUE 2,
      info  TYPE int1 VALUE 3,
      warn  TYPE int1 VALUE 4,
      error TYPE int1 VALUE 5,
      off   TYPE int1 VALUE 6,
    END OF c_level.

  METHODS debug
    IMPORTING
      i_message   TYPE csequence OPTIONAL
      i_val1      TYPE any OPTIONAL
      i_val2      TYPE any OPTIONAL
      i_val3      TYPE any OPTIONAL
      i_val4      TYPE any OPTIONAL
      i_args      TYPE string_table OPTIONAL
      i_data      TYPE any OPTIONAL
      i_exception TYPE REF TO cx_root OPTIONAL
      i_supplier  TYPE REF TO zif_log_supplier OPTIONAL.

  " TRACE, INFO, WARN and ERROR have the same signature.

  METHODS is_enabled
    IMPORTING i_level         TYPE int1
    RETURNING VALUE(r_result) TYPE abap_bool.

  METHODS flush.
ENDINTERFACE.
```

Behavior:

- Compare the level with the cached threshold first. If it is disabled, return without formatting, serializing or calling the supplier.
- Replace `{}` placeholders in order from `i_val1` to `i_val4`, then `i_args`.
- Output elementary values as text. Serialize structures and tables as JSON.
- Serialize `i_data` to JSON into the event payload.
- Record the full exception chain from `i_exception`, including `previous` exceptions.
- Add a method for T100 messages from `sy-msg*`, with the message key stored on the event.
- Capture the source position for WARN and above only.

Team rule: do not pass string templates to TRACE or DEBUG unless guarded by `is_enabled( )`.

## 7. Categories and configuration

Categories are dot-separated and uppercase, such as `ZSD.IMPORT.PRICING`.

### `ZLOG_CONFIG`

| Field | Type | Notes |
|---|---|---|
| `MANDT` | CLNT | Key |
| `CATEGORY` | CHAR 120 | Key; a prefix or `*` |
| `UNAME` | `SYUNAME` | Key; a user or `*` |
| `LOG_LEVEL` | INT1 | Threshold |
| `APPENDERS` | CHAR 60 | Comma-separated: `EVENT,BAL,JOBLOG,MEMORY` |
| `VALID_TO` | `TIMESTAMPL` | Initial means no expiry |

Example rows:

| CATEGORY | UNAME | LOG_LEVEL | APPENDERS | VALID_TO |
|---|---|---|---|---|
| `*` | `*` | WARN | `EVENT,BAL` | |
| `ZSD.IMPORT` | `*` | INFO | `EVENT,BAL` | |
| `ZSD.IMPORT.PRICING` | `JDOE` | TRACE | `EVENT` | today 14:00 |

### Resolution rules

1. Ignore expired rows.
2. Search rows for the current user, from the longest matching category prefix down to `*`.
3. If none match, search `*` user rows in the same order.
4. If none match, use the built-in default: WARN with `EVENT,BAL`.

Rules:

- A user-specific rule at any category level takes priority over a global rule.
- The first matching row supplies both level and appenders. Appenders are not additive across the hierarchy, unlike Log4j's default.
- Only match on full category segments, so `ZSD.IMP` does not match `ZSD.IMPORT`.
- Read the configuration once per internal session and cache it in `ZCL_LOG_FACTORY`. Cache one logger per category.

The table must be maintainable in production without a transport. Use a maintenance view with no transport recording and an authorization group.

## 8. Run context

`ZCL_LOG_CONTEXT` provides `get_run_id( )`, `set_run_id( )`, `put( )`, `remove( )`, `clear( )` and `as_json( )`.

- Generate a 16-byte GUID as the run ID on first use in an internal session.
- Automatically capture user, program, transaction, and in background runs, the job name and count.
- Static state does not cross `SUBMIT`, RFC or bgRFC boundaries. Callers must pass the run ID and call `set_run_id( )` on the other side.

## 9. `ZLOG_EVENT`

| Field | Type | Notes |
|---|---|---|
| `MANDT` | CLNT | Key |
| `EVENT_ID` | `SYSUUID_X16` | Key |
| `RUN_ID` | `SYSUUID_X16` | Indexed |
| `EVENT_TS` | `TIMESTAMPL` | UTC |
| `SEQ_NO` | INT4 | Order within an internal session |
| `LOG_LEVEL` | INT1 | |
| `CATEGORY` | CHAR 120 | |
| `UNAME` | `SYUNAME` | |
| `PROGRAM_NAME` | `PROGNAME` | |
| `JOB_NAME` | `BTCJOB` | |
| `JOB_COUNT` | `BTCJOBCNT` | |
| `MSG_TEXT` | `SSTRING` 1333 | Formatted message, truncated if necessary |
| `MSGID` / `MSGNO` | `SYMSGID` / `SYMSGNO` | T100 key, if any |
| `SOURCE_POS` | CHAR 120 | WARN and above |
| `HAS_PAYLOAD` | `ABAP_BOOL` | Filter without reading the payload |
| `PAYLOAD_LEN` | INT4 | Original length |
| `PAYLOAD_TRUNC` | `ABAP_BOOL` | True if the limit was exceeded |
| `CONTEXT_JSON` | STRING | Context |
| `EXCEPTION_JSON` | STRING | Exception chain |
| `PAYLOAD_JSON` | STRING | Payload |

Indexes:

- `MANDT, RUN_ID, EVENT_TS, SEQ_NO`
- `MANDT, EVENT_TS, LOG_LEVEL`
- `MANDT, CATEGORY, EVENT_TS`

Rules:

- Select explicit field lists. Never use `SELECT *`, and only read string columns when required.
- Apply a configurable maximum payload size, with a default of 1 MB.
- A truncated payload is not valid JSON. Set `PAYLOAD_TRUNC`, store the original length, and make the reader report the truncation.
- Allow callers to log only technical and business data that is safe to store. Do not log personal data or secrets.

## 10. Appenders

Use this contract:

```abap
INTERFACE zif_log_appender PUBLIC.
  METHODS append
    IMPORTING i_event TYPE zlog_s_event.
  METHODS flush.
ENDINTERFACE.
```

### EVENT

- Buffer events, and flush when the buffer reaches a configurable size (default 50), on ERROR, on `flush( )` and on `ZCL_LOG_FACTORY=>flush_all( )`.
- Write and commit through a service connection:

```abap
CONSTANTS c_connection TYPE dbcon_name VALUE 'R/3*ZLOG'.

INSERT zlog_event CONNECTION (c_connection) FROM TABLE m_buffer.
COMMIT CONNECTION (c_connection).
```

### BAL

- Write INFO, WARN and ERROR only, even if a rule requests a lower level.
- Use log object `ZLOG` and set the external ID to the run ID.
- Use the category and message in the visible text.
- Never write the JSON payload to BAL. Write a summary line that references `EVENT_ID`.
- Use `BAL_LOG_CREATE`, `BAL_LOG_MSG_ADD`, `BAL_LOG_MSG_ADD_FREE_TEXT` and `BAL_DB_SAVE`.
- Save with `BAL_DB_SAVE`'s second-connection options. Confirm their exact names on the system.
- Chunk long text. **Check the free-text limit in the function module's interface on the target system.** Earlier notes say 255 characters, but it may be 200. Keep the limit in one constant.

### JOBLOG

- Only active when `sy-batch` is true.
- Use `MESSAGE` statements with short text and truncate safely.
- Write the run ID once at the start so that a job log reader can find the matching events.

### MEMORY

- Store events in an internal table, with accessors for unit tests.

## 11. Durability

ABAP has no destructors, and a short dump loses anything still in the buffer.

- ERROR flushes all buffered appenders immediately.
- Long-running programs and jobs should call `ZCL_LOG_FACTORY=>flush_all( )` at the end of processing and at milestones.
- Document this limitation in the README.

## 12. Reading and retention

### `ZCL_LOG_READER`

Filters: run ID, time range, minimum level, category prefix and job name. It also has options for payload inclusion and maximum rows.

### `ZLOG_READ`

Takes the same selection criteria and writes one JSON object per line, so the AI job loop can read results from the spool.

```json
{"event_id":"...","run_id":"...","ts":"2026-11-05T09:05:00.123Z","level":"ERROR","category":"ZSD.IMPORT","message":"Posting failed","context":{},"exception":[],"payload":{},"payload_truncated":false}
```

Requirements:

- Protect reading with a dedicated authorization object.
- Limit rows and payload size by default.
- Exclude payloads unless requested.

### `ZLOG_CLEANUP`

- Default retention: TRACE and DEBUG 3 days, INFO and WARN 30 days, ERROR 180 days.
- Make retention values selection parameters.
- Delete in packages and commit after each package.
- BAL logs: set the expiry date on the log header and delete through SLG2.

## 13. Delivery order

Complete and verify each phase before starting the next.

1. **Core:** `ZIF_LOG`, levels, factory, configuration resolution, formatter, context and memory appender, with unit tests.
2. **Event store:** `ZLOG_EVENT`, JSON wrapper, EVENT appender, truncation and secondary-connection persistence.
3. **SAP outputs:** BAL and JOBLOG appenders, and the `ZLOG` SLG0 object.
4. **Consumers:** reader, `ZLOG_READ`, `ZLOG_CLEANUP`, configuration maintenance view and authorization object.
5. **Adoption:** README, team conventions and a sample program. An ATC check that blocks direct `BAL_*` calls outside the framework package can follow as a separate item.

Out of scope for version 1: reloading configuration during an internal session, an HTTP read service, a viewer UI, async appenders and ABAP Cloud support.

## 14. Acceptance criteria

### Automated tests

- A disabled level does not call the supplier, formatter or serializer.
- Placeholders are replaced correctly, including missing values, extra values and more than four arguments.
- Category matching respects segment boundaries.
- A user rule beats a global rule, including when the global rule has a longer category prefix.
- Expired rules are ignored, and the built-in default applies when no rule matches.
- A failing appender does not raise an exception or stop other appenders.
- Oversized payloads set the truncation fields correctly.

### Checks on an SAP system

- Run `abaplint` with no errors, and activate all objects on a 7.50 system.
- A payload above the BAL limit is stored in full in `ZLOG_EVENT`, and SLG1 shows a summary with its event ID.
- A caller's `ROLLBACK WORK` does not remove flushed events.
- Logging does not commit the caller's open database changes.
- A `ZLOG_CONFIG` change applies to the next session without a transport.
- A background job writes its run ID to the job log, and `ZLOG_READ` returns that run's events as valid NDJSON.

## 15. Verify on the target system first

Report the results before Phase 2:

1. The system is on SAP_BASIS 7.50, and abapGit is available for import.
2. `/UI2/CL_JSON` is available. If it isn't, implement `ZCL_LOG_JSON` with the kernel's JSON writer through `CALL TRANSFORMATION`.
3. The `BAL_DB_SAVE` second-connection parameters and `BAL_LOG_MSG_ADD_FREE_TEXT` length limit.
4. The system allows `R/3*` service connections for the database in use.
5. The team's package name and authorization naming conventions.
