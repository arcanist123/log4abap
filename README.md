# log4abap

A Log4j-style logging framework for ABAP 7.50, delivered as an abapGit repository
(package `$ZLOG4ABP`, object prefix `ZLOG4ABP_`). The design follows
[zlog-implementation-brief.md](zlog-implementation-brief.md).

> **Status: Phase 1 (core) only.** The code passes abaplint (v750). On 2026-11-05 it was activated in
> `$ZLOG4ABP` on the A4H trial system (SAP_BASIS 816, not 7.50), where all 68 ABAP Unit tests passed.
> The EVENT, BAL and JOBLOG appenders, the event table, the reader and the reports follow in later phases.

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

Table `ZLOG4ABP_CONFIG` (maintenance view: Phase 4):

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

## Objects (Phase 1)

| Object | Purpose |
|---|---|
| `ZLOG4ABP_IF_LOG` | Logger API and level constants |
| `ZLOG4ABP_IF_SUPPLIER` | Deferred message and payload |
| `ZLOG4ABP_IF_APPENDER` | Appender contract: `append( )`, `flush( )` |
| `ZLOG4ABP_CL_FACTORY` | Logger and appender cache, `flush_all( )` |
| `ZLOG4ABP_CL_LOGGER` | `ZLOG4ABP_IF_LOG` implementation |
| `ZLOG4ABP_CL_CONFIG` | Rule resolution |
| `ZLOG4ABP_CL_CONTEXT` | Run ID, key-value context, session info |
| `ZLOG4ABP_CL_FORMATTER` | `{}` formatting, value conversion, T100 text |
| `ZLOG4ABP_CL_JSON` | The only JSON writer (RTTI-based) |
| `ZLOG4ABP_CL_APPENDER_MEMORY` | In-memory appender for unit tests |
| `ZLOG4ABP_CONFIG` | Configuration table |
| `ZLOG4ABP_S_EVENT` | Event structure passed to appenders |
| `ZLOG4ABP_LEVEL`, `_CATEGORY`, `_APPENDERS`, `_SOURCE_POS`, `_JSON`, `_TEXT` | Domains / data elements |

## Local checks

```sh
npm install
npm test        # abaplint (v750) + ABAP Unit via the abaplint transpiler
```

The transpiler runs the tests in Node.js against the open-abap runtime, not on an SAP kernel.
`test/stubs/` holds a few SAP data elements that open-abap lacks. abapGit does not import
these stubs, because they sit outside `/src/`. A green run is a useful signal, but it does not
replace running ABAP Unit on a 7.50 system.
