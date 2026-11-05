# log4abap

A Log4j-style logging framework for ABAP 7.50, delivered as an abapGit repository
(package `$ZLOG4ABP`, object prefix `ZLOG4ABP_`). The design follows
[zlog-implementation-brief.md](zlog-implementation-brief.md).

> **Status: Phases 1-4 (core, event store, SAP outputs, consumers).** The code passes abaplint (v750). On
> 2026-11-05 it was activated in `$ZLOG4ABP` on the A4H trial system (SAP_BASIS 816, not 7.50), where all 122
> ABAP Unit tests passed (see [docs/target-system-checks.md](docs/target-system-checks.md)). On A4H the
> authorization object exists, but no user holds it yet, and the configuration maintenance view is in the
> repository only (vsp cannot create it). Phase 5 (adoption: sample program, ATC check) follows.

## Usage

```abap
DATA(l_log) = zlog4abp_cl_factory=>get( 'ZSD.IMPORT.PRICING' ).

l_log->info( i_message = 'Order {} imported with {} items' i_val1 = l_order_id i_val2 = l_count ).
l_log->warn( i_message = 'Price missing' i_data = l_item ).          " i_data -> JSON payload
l_log->error( i_exception = l_cx ).                                   " full previous-chain
l_log->t100( ).                                                       " message from SY-MSG*

IF l_log->is_enabled( zlog4abp_if_log=>c_level-debug ).
  l_log->debug( |Expensive { l_text }| ).                             " templates only when guarded
ENDIF.

zlog4abp_cl_factory=>flush_all( ).                                    " end of processing / milestones
```

- Placeholders `{}` are filled from `i_val1`..`i_val4`, then `i_args`. Elementary values become
  text (dates and times in ISO format). Structures and tables become JSON. A `{}` without a
  value is kept as is, and values without a placeholder are ignored.
- For an expensive message or payload, pass an implementation of `ZLOG4ABP_IF_SUPPLIER`. It is
  only called when the level is enabled.
- Context: `zlog4abp_cl_context=>put( i_key = 'order' i_value = l_order_id )`. The run ID is
  generated per internal session. After `SUBMIT`, RFC or bgRFC, pass `get_run_id( )` and call
  `set_run_id( )` on the other side.

## Team conventions

- Do not pass string templates to TRACE or DEBUG unless guarded by `is_enabled( )`. ABAP
  evaluates templates before the call, even when the level is disabled.
- Log only technical and business data that is safe to store. Never log personal data or secrets.
- Naming: `l_` locals, `i_`/`e_`/`c_`/`r_` parameters, `m_` instance attributes, `g_` static
  attributes, `c_` constants, `ty_` types. Loop iterators need no prefix. abaplint enforces these.

## Configuration

Table `ZLOG4ABP_CONFIG`, maintained in SM30 through view `ZLOG4ABP_CONFIGV` (see *Setup* below):

| CATEGORY | UNAME | LOG_LEVEL | APPENDERS | VALID_TO |
|---|---|---|---|---|
| `*` | `*` | 4 (WARN) | `EVENT,BAL` | |
| `ZSD.IMPORT` | `*` | 3 (INFO) | `EVENT,BAL` | |
| `ZSD.IMPORT.PRICING` | `JDOE` | 1 (TRACE) | `EVENT` | today 14:00 UTC |

Levels: 1 TRACE, 2 DEBUG, 3 INFO, 4 WARN, 5 ERROR, 6 OFF.

Rules are resolved in this order:

1. Expired rows are ignored.
2. The user's rows apply first, longest category prefix down to `*`.
3. Then the rows of user `*`, in the same order.
4. If nothing matches, the default is WARN with `EVENT,BAL`.

Further details:

- A user rule beats any global rule, even one with a longer prefix.
- Prefixes match whole segments only: `ZSD.IMP` does not match `ZSD.IMPORT`.
- The first matching row supplies both the level and the appenders (they are not additive).
- The configuration is read once per internal session, so changes apply to the next session.

Appender name `ABC` maps to class `ZLOG4ABP_CL_APPENDER_ABC`. The class needs a public
constructor with no mandatory parameters. Names that cannot be created are ignored.

## Durability limitation

ABAP has no destructors, and a short dump loses everything still buffered in appenders.
ERROR events flush their logger's appenders immediately. Long-running programs and jobs
should call `zlog4abp_cl_factory=>flush_all( )` at the end and at milestones.

## Event store

Appender `EVENT` writes complete events, including the JSON payload, to table `ZLOG4ABP_EVENT`.

- Events are buffered and written when the buffer holds 50 events, after every ERROR, and on
  `flush( )` / `flush_all( )`. Change the size with
  `CAST zlog4abp_cl_appender_event( zlog4abp_cl_factory=>get_appender( 'EVENT' ) )->set_buffer_size( n )`.
- Rows are inserted and committed through service connection `R/3*ZLOG4ABP`. Logging never commits
  the caller's open changes, and the caller's `ROLLBACK WORK` does not remove events that were written.
- If a write fails, the buffered events are dropped and counted (`get_dropped_count( )`). The
  appender does not retry and never logs through the framework.
- `MSG_TEXT` keeps the first 1333 characters of the message. Payloads above the logger's limit
  (default 1 MB) are cut off and marked with `PAYLOAD_TRUNC`; `PAYLOAD_LEN` holds the original length.

## Application log (BAL)

Appender `BAL` writes a summary of each event to the application log, for support users in SLG1.

- Only INFO, WARN and ERROR are written, even if a rule enables lower levels.
- There is one log per run ID, with object `ZLOG4ABP` and the run ID as external ID.
- Each event becomes the text `CATEGORY: message`, cut into lines of 200 characters (at most 5).
  The next line names the event ID in `ZLOG4ABP_EVENT`, plus the T100 key, the payload size and
  whether an exception chain was recorded. The payload itself is never written to BAL.
- Messages are saved when 50 events are waiting, after every ERROR and on `flush( )` / `flush_all( )`.
  `BAL_DB_SAVE` saves and commits them on its second connection, so the caller's LUW is untouched.
- Logs expire after 180 days (`ALDATE_DEL`). A log with 1000 messages is released from memory after
  its next save, and later events of the run start a new log with the same external ID.
- Failures (no log object, full log, failed save) drop the events concerned and count them
  (`get_dropped_count( )`).

**Setup: log object `ZLOG4ABP`.** Create it in transaction SLG0 (object `ZLOG4ABP`, text
`log4abap`, no subobjects). The repository does not contain it: abapGit's object type for
application log objects (APLO) does not exist on 7.50. Without the object, `BAL` drops every event.

## Job log

Appender `JOBLOG` writes events to the job log, but only in background runs (`SY-BATCH`).

- Before the first event of a run it writes `log4abap run ID <run ID>`, so you can find the run's
  events in `ZLOG4ABP_EVENT` from the job log.
- Each event becomes one line `LEVEL CATEGORY: message`, cut to 200 characters.
- Every line has message type S, because an E or A message would end the job.
- `SY-MSGID`, `SY-MSGTY`, `SY-MSGNO` and `SY-MSGV1`..`SY-MSGV4` are restored after each line.

Example rule for a job: category `ZSD.IMPORT`, user `*`, level 3, appenders `EVENT,BAL,JOBLOG`.

## Reading events

Class `ZLOG4ABP_CL_READER` reads events from `ZLOG4ABP_EVENT` and converts them to JSON. Report
`ZLOG4ABP_READ` writes them as NDJSON (one JSON object per line) to the list, so a background job
leaves them in its spool.

```abap
DATA(l_lines) = NEW zlog4abp_cl_reader( )->read_json( VALUE #( run_id    = l_run_id
                                                               min_level = zlog4abp_if_log=>c_level-warn ) ).
```

- Filters: run ID, time range (UTC), minimum level, category prefix (whole segments: `ZSD` selects
  `ZSD` and `ZSD.IMPORT`, not `ZSDX`) and job name. Events come oldest first.
- At most 1000 events by default (`MAX_ROWS`). If more match, `READ( )` sets `MORE` and the report
  says so in a status message (job log), so the list itself holds JSON only.
- Payloads are left out unless requested (`WITH_PAYLOAD`, report checkbox *Include payload*). The
  payload column is then not read at all.
- A payload longer than 64 KB (`MAX_PAYLOAD`), or one that was truncated when it was stored, is no
  longer valid JSON. It is written as a JSON string, with `"payload_truncated":true`;
  `payload_len` always holds the original length.
- One line looks like this (shortened):

```json
{"event_id":"0242AC11...","run_id":"0242AC11...","ts":"2026-11-05T14:58:07.527Z","seq_no":3,"level":"ERROR","category":"ZSD.IMPORT","message":"Posting failed","msgid":null,"msgno":null,"source_pos":"ZSD_IMPORT:9 START-OF-SELECTION","user":"JDOE","program":"ZSD_IMPORT","job_name":"ZSD_NIGHTLY","job_count":"14580600","context":{...},"exception":[],"has_payload":false,"payload_len":0,"payload":null,"payload_truncated":false}
```

**Long lines.** A spool line holds at most 255 characters. Longer events are split: each further
line starts with `+`. To restore the event, drop the `+` and append the line to the previous one.
A blank at the end of a piece (which the spool would drop) is written as `\u0020`, which means
the same inside a JSON string.

Reading needs authorization object `ZLOG4ABP_R` with activity 03. Without it, `READ( )` raises
`ZLOG4ABP_CX_NOT_AUTHORIZED`.

## Retention

Report `ZLOG4ABP_CLEANUP` (class `ZLOG4ABP_CL_CLEANUP`) deletes expired events. Schedule it daily
with a variant that clears *Test mode*.

| Levels | Default retention |
|---|---|
| TRACE, DEBUG | 3 days |
| INFO, WARN | 30 days |
| ERROR | 180 days |

- A retention of 0 keeps the events of that group.
- Rows are deleted in packages (default 1000). Each package is deleted and committed on service
  connection `R/3*ZLOG4ABP`.
- Test mode (the default) only counts the rows it would delete.
- Deleting needs `ZLOG4ABP_R` with activity 06 (test mode: 03).
- Application logs are not deleted by the report. The BAL appender gives every log an expiry date
  180 days ahead. Schedule SLG2 (report `SBAL_DELETE`) for object `ZLOG4ABP` to delete expired logs.

## Setup

These objects are in the repository, but are either not created by an abapGit import alone or not
yet tested through one:

1. **Log object `ZLOG4ABP`** in SLG0 (see *Application log* above).
2. **Authorization object `ZLOG4ABP_R`** (class `BC_A`, field `ACTVT`, activities 03 and 06) is in
   `src/zlog4abp_r.suso.xml`. Give support and AI job users a role with activity 03, and the
   cleanup job's user activity 06.
3. **Maintenance dialog.** `src/zlog4abp_configv.view.xml` holds maintenance view
   `ZLOG4ABP_CONFIGV`. Generate the dialog in SE54 (or SE11, *Utilities > Table Maintenance
   Generator*):
   - authorization group: a dedicated group, e.g. `ZLG4` (create it in SE54 with *Authorization
     Group*), checked through `S_TABU_DIS`;
   - function group `ZLOG4ABP_CFG` in `$ZLOG4ABP`, one-step maintenance;
   - recording routine: *no, or user, recording routine*, so changes need no transport.

   Then serialize the generated function group and the view's table maintenance object (TOBJ) with
   abapGit and commit them.

## Objects

| Object | Purpose |
|---|---|
| `ZLOG4ABP_IF_LOG` | Logger API and level constants |
| `ZLOG4ABP_IF_SUPPLIER` | Deferred message and payload |
| `ZLOG4ABP_IF_APPENDER` | Appender contract: `append( )`, `flush( )` |
| `ZLOG4ABP_CL_FACTORY` | Logger and appender cache, `flush_all( )` |
| `ZLOG4ABP_CL_LOGGER` | `ZLOG4ABP_IF_LOG` implementation |
| `ZLOG4ABP_CL_CONFIG` | Rule resolution |
| `ZLOG4ABP_CL_CONTEXT` | Run ID, key-value context, session info |
| `ZLOG4ABP_CL_FORMATTER` | `{}` formatting, value conversion, T100 text, level names |
| `ZLOG4ABP_CL_JSON` | The only JSON writer (RTTI-based) |
| `ZLOG4ABP_CL_APPENDER_MEMORY` | In-memory appender for unit tests |
| `ZLOG4ABP_CL_APPENDER_EVENT` | Appender for `ZLOG4ABP_EVENT` (Phase 2) |
| `ZLOG4ABP_CL_APPENDER_BAL` | Appender for the application log, SLG1 (Phase 3) |
| `ZLOG4ABP_CL_APPENDER_JOBLOG` | Appender for the job log of background runs (Phase 3) |
| `ZLOG4ABP_CL_READER` | Reads events by filter and converts them to JSON (Phase 4) |
| `ZLOG4ABP_CL_CLEANUP` | Retention: deletes expired events in packages (Phase 4) |
| `ZLOG4ABP_CX_NOT_AUTHORIZED` | Raised without `ZLOG4ABP_R` authorization (Phase 4) |
| `ZLOG4ABP_READ` | Report: events as NDJSON for the list and the spool (Phase 4) |
| `ZLOG4ABP_CLEANUP` | Report: retention job (Phase 4) |
| `ZLOG4ABP_R` | Authorization object, field `ACTVT`: 03 read, 06 delete (Phase 4) |
| `ZLOG4ABP_CONFIGV` | Maintenance view for `ZLOG4ABP_CONFIG` (Phase 4) |
| `ZLOG4ABP_CONFIG` | Configuration table |
| `ZLOG4ABP_EVENT` | Event and payload table, indexes Z01-Z03 (Phase 2) |
| `ZLOG4ABP_S_EVENT` | Event structure passed to appenders |
| `ZLOG4ABP_LEVEL`, `_CATEGORY`, `_APPENDERS`, `_SOURCE_POS`, `_JSON`, `_TEXT`, `_MSG_TEXT` | Domains / data elements |

## Local checks

```sh
npm install
npm test        # abaplint (v750) + ABAP Unit via the abaplint transpiler
```

The transpiler runs the tests in Node.js against the open-abap runtime, not on an SAP kernel.
`test/stubs/` holds a few SAP data elements that open-abap lacks. abapGit does not import
these stubs, because they sit outside `/src/`. A green run is a useful signal, but it does not
replace running ABAP Unit on a 7.50 system.
