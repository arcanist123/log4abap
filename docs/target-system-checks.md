# Target system checks (brief section 15)

Report these results before Phase 2 starts.

Checked on 2026-11-05 on system **A4H, client 001** (ABAP Platform developer trial, user DEVELOPER). The checks used
vsp CLI over ADT: dictionary reads, plus short ABAP snippets run through `vsp execute` in temporary `$TMP` programs.
The connection settings are in the git-ignored `.env.sap`.

| # | Check | Result |
|---|---|---|
| 1a | SAP_BASIS 7.50 | **No: SAP_BASIS 816** (ABAP Platform 2023-level trial, HANA). See the note below |
| 1b | abapGit available | **Yes, and it runs.** Developer edition 1.134.0 (`ZCL_ABAPGIT_*` in `$ABAPGIT*`, transaction `ZABAPGIT`); `zcl_abapgit_repo_srv=>get_instance( )->list( )` returned 4 repositories. vsp's `ZADT_VSP` is installed too, so `vsp git import-zip` can import this repository |
| 2 | `/UI2/CL_JSON` available | Yes (package `/UI2/NWBC_CORE`). Not used: `ZLOG4ABP_CL_JSON` has its own writer |
| 3a | `BAL_DB_SAVE` second connection | Importing `I_2TH_CONNECTION` and `I_2TH_CONNECT_COMMIT` (both `BOOLEAN`, default space); exporting `E_SECOND_CONNECTION` (`DBCON_NAME`). Also `I_IN_UPDATE_TASK`, `I_SAVE_ALL`, `I_LINK2JOB` (default `'X'`) and `I_T_LOG_HANDLE` |
| 3b | `BAL_LOG_MSG_ADD_FREE_TEXT` length | The interface types `I_TEXT` as generic `C`, with no length. Observed: a 400-character text was stored as message `BL 001` with `MSGV1`..`MSGV4` of 50 characters each, so **200 characters** were kept and the rest was dropped. The BAL appender's chunk constant must be 200 |
| 4 | `R/3*` service connection | Yes: `SELECT ... CONNECTION ('R/3*ZLOG4ABP')` and `COMMIT CONNECTION` worked on HANA (`sy-dbsys` = HDB). Still to do once `ZLOG4ABP_EVENT` exists: the `INSERT`, and the check that the caller's `ROLLBACK WORK` keeps flushed rows |
| 5 | Package and authorization naming | Decided: package `$ZLOG4ABP`, prefix `ZLOG4ABP_`. Authorization object names have at most 10 characters, e.g. `ZLOG4ABP_R` |

**Release note (1a):** No 7.50 system is available, only this 816 system. Activating there shows the code works on
a newer release. It does not show that the code is 7.50-compatible, because 816 accepts newer syntax.
7.50 compatibility rests on abaplint with `"version": "v750"`, which `npm test` runs. Before the framework is
delivered to a real 7.50 system, activate it there once.

## Phase 1 on A4H (2026-11-05)

All 20 objects are active in `$ZLOG4ABP`, and ABAP Unit for the package passed: **68 passed, 0 failed**.

- **How it was pushed:** with vsp, file by file. The package came from `sapcli package create`. Domains, data
  elements, the structure and the table were created through vsp's MCP tools, with the structure as DDL source
  equivalent to `zlog4abp_s_event.tabl.xml`. The classes and interfaces, including their test includes, went in
  with `vsp deploy`.
- **Why not an abapGit import:** `vsp git import-zip` needs `ZCL_VSP_GIT_SERVICE`, which is missing from this
  system's `ZADT_VSP`. Creating `$ZLOG4ABP` through abapGit's API dumped in `CL_PACKAGE_FACTORY`
  (`MESSAGE_TYPE_UNKNOWN`). After that attempt, an empty offline abapGit repository `log4abap` (key `000000000009`)
  remains registered for `$ZLOG4ABP`.
- **Fixed by activation:** two errors that abaplint did not catch. `T100KEY-MSGNO` (type N) was passed to a
  `CSEQUENCE` parameter, and ABAP Doc does not allow `<pre>`. abaplint's `abapdoc_html_tag` rule is now enabled.
- **Still open:** an abapGit round trip. Serialize `$ZLOG4ABP` with the system's abapGit (or pull it with the
  offline repository) and diff the result against `src/`, to show that the repository files match what abapGit
  writes.

## Phase 2 on A4H (2026-11-05)

Pushed with vsp: data element `ZLOG4ABP_MSG_TEXT` and table `ZLOG4ABP_EVENT` through the MCP tool `SAP`
(action create), class `ZLOG4ABP_CL_APPENDER_EVENT` with its test include through `vsp deploy`. All are active.
ABAP Unit for the package: **76 passed, 0 failed**.

Transaction checks (brief section 14), run with `vsp execute` against the real table. The snippet logged
three events through the factory (default rule, so WARN and above), with an open `INSERT` into
`ZLOG4ABP_CONFIG` on the default connection, and called `ROLLBACK WORK` after the ERROR flush:

| Check | Result |
|---|---|
| Logging does not commit the caller's open changes | After the flush, the service connection saw 0 of the caller's uncommitted rows; after `ROLLBACK WORK` the row was gone |
| The caller's `ROLLBACK WORK` keeps flushed events | All 3 events of the run were still in `ZLOG4ABP_EVENT`; 0 dropped |
| A payload above the BAL limit is stored in full | 600-character string: `PAYLOAD_LEN` 602, full JSON stored, `PAYLOAD_TRUNC` initial |
| An oversized payload sets the truncation fields | Limit 1000, 3000-character string: `PAYLOAD_LEN` 3002, `PAYLOAD_TRUNC` = X |

The three test events (category `ZLOG4ABP.SYSCHECK`, run `0242AC1100111FE1B6A0B6F5A152A06A`) remain in the
table. The SLG1 half of the BAL check follows with the BAL appender in Phase 3.

**Open: indexes and technical settings.** vsp creates tables from DDL source and has no way to create
secondary indexes or set technical settings. On A4H, `ZLOG4ABP_EVENT` therefore has no indexes Z01-Z03 and
uses data class APPL0, size category 0 (the repository says APPL1, size category 4). `ZLOG4ABP_CONFIG` has
the same drift: APPL0 on the system, APPL2 in the repository. An abapGit import would create both from
`src/`.

## Phase 3 on A4H (2026-11-05)

Pushed with vsp: classes `ZLOG4ABP_CL_APPENDER_BAL` and `ZLOG4ABP_CL_APPENDER_JOBLOG` (new) and
`ZLOG4ABP_CL_FORMATTER` (new methods `LEVEL_NAME( )` and `SHORTEN( )`), each with its test include, through
`vsp deploy`. All are active. ABAP Unit for the package: **96 passed, 0 failed**.

**Log object.** vsp cannot create application log objects, and abapGit's APLO type does not exist on 7.50.
At the user's request, `ZLOG4ABP` was inserted into `BALOBJ` and `BALOBJT` (texts E and D: `log4abap`) by a
`vsp execute` snippet, committed on the service connection. On other systems, create it in SLG0.

Checks run with `vsp execute` against the real application log and tables:

| Check | Result |
|---|---|
| A payload above the BAL limit is stored in full, and SLG1 shows a summary with its event ID | Rule `*`/`*` INFO `EVENT,BAL`. One log (number 22225, external ID = run ID `0242AC1100111FE1B6A525CFD304E06A`) with 8 messages: per event a summary line (type I/W/E) and an `Event <id> in ZLOG4ABP_EVENT` line, for the WARN event with `payload of 602 characters`. The 485-character ERROR text came out as 3 lines of at most 200 characters. The 3 event IDs match the rows in `ZLOG4ABP_EVENT`, where the 602-character payload is stored in full. The DEBUG event was not written to BAL. 0 unsaved, 0 dropped |
| BAL does not commit the caller's open changes | A caller row inserted into `ZLOG4ABP_CONFIG` before logging was invisible to another connection after the ERROR flush (`BAL_DB_SAVE` with `I_2TH_CONNECTION` / `I_2TH_CONNECT_COMMIT`) and was gone after `ROLLBACK WORK`; the BAL log and events stayed |
| A background job writes its run ID to the job log | Temporary report `ZLOG4ABP_JOBCHECK` in `$TMP` (deleted afterwards), started as job 14580600 with rule `ZLOG4ABP.JOBCHECK`/`*` INFO `EVENT,JOBLOG`. Job log: `log4abap run ID 0242AC1100111FE1B6A529EAA731206A`, then the INFO, WARN and ERROR lines (DEBUG filtered out, ERROR cut to 200 characters with `...`), all type S; the job finished normally. The 3 events of the job in `ZLOG4ABP_EVENT` carry the same run ID. The `ZLOG4ABP_READ` half of this check follows in Phase 4 |
| A `ZLOG4ABP_CONFIG` change applies to the next session without a transport | The job's rule was committed to the table just before the job started, and the job (a new session) used it. The row was deleted afterwards |

The test log, events and job remain on the system.

**Known limitation:** BAL builds free-text messages from four 50-character message variables, and message
variables lose trailing blanks. A space that falls exactly at position 50, 100 or 150 of a line therefore
disappears in SLG1. The full text is in `ZLOG4ABP_EVENT`.

## Phase 4 on A4H (2026-11-05)

Pushed with `vsp deploy`: classes `ZLOG4ABP_CX_NOT_AUTHORIZED`, `ZLOG4ABP_CL_READER` and
`ZLOG4ABP_CL_CLEANUP` (with test includes) and reports `ZLOG4ABP_READ` and `ZLOG4ABP_CLEANUP`. All are
active. ABAP Unit for the package: **122 passed, 0 failed**.

**Fixed by activation:** in `ZLOG4ABP_CL_CLEANUP`, `CONNECTION` stood right after `FROM` in two SELECTs.
SAP requires it after the INTO clause, but abaplint's v750 parser rejects that position. The SELECTs now
use the default connection, which sees the deletions committed on the service connection; only `DELETE`
and `COMMIT CONNECTION` use `R/3*ZLOG4ABP`.

Checks run with `vsp execute` against the real table:

| Check | Result |
|---|---|
| Authorization is enforced | Before the object existed, `AUTHORITY-CHECK` returned 12 and `READ( )` raised `ZLOG4ABP_CX_NOT_AUTHORIZED` ("No authorization for object ZLOG4ABP_R, activity 03") |
| Category prefix in SQL | `CATEGORY_RANGE( 'zlog4abp' )` (EQ plus CP `ZLOG4ABP.*`) selected all 9 events of `ZLOG4ABP.SYSCHECK` and `ZLOG4ABP.JOBCHECK` |
| Output is valid JSON | All 9 events in the table, converted with payload (limit 1000) and split for a width of 255: no physical line above 255 characters, and each event, joined again, parsed with the kernel's JSON reader (`CL_SXML_STRING_READER`). The reader rejected `{"a":` and an unterminated string as a control. The 3002-character payload stored as truncated came out as a JSON string with `payload_truncated` true. (This run used a build in which the blank escape of `SPLIT_LINE( )` was broken; no piece of these events ended with a blank. The escape is fixed and covered by `SPLIT_TRAILING_BLANK`.) |

**Authorization object `ZLOG4ABP_R`.** vsp cannot create authorization objects. At the user's request, a
`vsp execute` snippet inserted it: `TOBJ` (field `ACTVT`, class `BC_A`), `TOBJT` (E and D), `TACTZ` (03,
06) and `TOBJVORFLG`, committed on the service connection. DEVELOPER still gets return code 12, because
the `SAP_ALL` profile was generated before the object existed. `RSUSR406` (regenerate `SAP_ALL`) cannot
run as a background job: it asks for confirmation and ends with "Action canceled by user". Until
`SAP_ALL` is regenerated in dialog, or a role grants the object, `ZLOG4ABP_READ` and `ZLOG4ABP_CLEANUP`
stop with the authorization message. The second half of the job check in brief section 14
(`ZLOG4ABP_READ` returns the job's run as valid NDJSON from the spool) and a real cleanup run wait for it.

**Also open on A4H:**

- Maintenance view `ZLOG4ABP_CONFIGV` and its generated dialog (SE54); vsp cannot create views. See
  *Setup* in the README.
- The selection texts in the two `.prog.xml` files: `vsp deploy` writes the source only, so on A4H the
  selection screens show the parameter names.

Also confirm on activation:

- Message `00 001` exists. The T100 unit test uses it.
- `SYSTEM_CALLSTACK` returns `CALLSTACK` of type `ABAP_CALLSTACK` (used for the source position).
- `CL_ABAP_CONV_IN_CE=>UCCPI` is available (used to build the JSON control-character table).

## Deviations from the brief

- **Names:** The brief's names are mapped to the `ZLOG4ABP_` prefix: `ZIF_LOG` -> `ZLOG4ABP_IF_LOG`,
  `ZCL_LOG_*` -> `ZLOG4ABP_CL_*`, `ZLOG_EVENT` -> `ZLOG4ABP_EVENT`, `ZLOG_CONFIG` -> `ZLOG4ABP_CONFIG`,
  `zlog_s_event` -> `ZLOG4ABP_S_EVENT`, and BAL object `ZLOG` -> `ZLOG4ABP`. The service connection
  will be `R/3*ZLOG4ABP`.
- **JSON:** `ZLOG4ABP_CL_JSON` writes JSON itself through RTTI instead of wrapping `/UI2/CL_JSON` or
  `CALL TRANSFORMATION`. This removes check 2 as a dependency and gives lowercase keys and
  real booleans. It is still the only class that produces JSON.
- **API additions:** `ZLOG4ABP_IF_LOG` adds `t100( )` (the brief asks for a T100 method) and
  `get_category( )`. The five level methods declare `PREFERRED PARAMETER i_message`, so
  `l_log->info( 'text' )` works.
- **Truncation:** Payload truncation (default 1 MB) happens in the logger when the event is built,
  so all appenders see the same `PAYLOAD_TRUNC` / `PAYLOAD_LEN`. The limit is set through
  `zlog4abp_cl_factory=>set_max_payload( )`.
- **Boolean fields:** `HAS_PAYLOAD` and `PAYLOAD_TRUNC` use data element `XFELD`. It holds the same
  values as `ABAP_BOOL`, which is not a DDIC data element.
- **BAL messages:** The BAL appender writes free text only (`BAL_LOG_MSG_ADD_FREE_TEXT`), also for T100
  events: the event carries the message key but not its variables, so `BAL_LOG_MSG_ADD` could not rebuild
  the message. The T100 key is shown on the event reference line instead.
- **BAL log object:** `ZLOG4ABP` is not in the repository (no abapGit type on 7.50); it is created in SLG0.
- **Delivery class:** `ZLOG4ABP_CONFIG` has delivery class A, so changes in production are not
  blocked by client customizing settings. The maintenance dialog is generated without transport
  recording (README, *Setup*).
- **Maintenance dialog:** The repository holds view `ZLOG4ABP_CONFIGV`, but not the generated function
  group and table maintenance object. Generated dynpros cannot be written reliably by hand; they are
  generated in SE54 and then serialized with abapGit.
- **Authorization:** One object, `ZLOG4ABP_R`, with field `ACTVT` only: 03 to read, 06 to delete. A
  category field was left out because authorization field values hold at most 40 characters and
  categories 120.
- **Exception class:** `ZLOG4ABP_CX_NOT_AUTHORIZED` uses the prefix `ZLOG4ABP_CX_` (abaplint's class
  naming rule now allows `ZLOG4ABP_CL_` and `ZLOG4ABP_CX_`).
- **NDJSON in the spool:** Spool lines hold 255 characters, so `ZLOG4ABP_READ` splits long events into
  continuation lines that start with `+` (README, *Reading events*). Pure NDJSON comes from
  `ZLOG4ABP_CL_READER=>READ_JSON( )`.
- **Retention of BAL logs:** `ZLOG4ABP_CLEANUP` deletes events only. BAL logs get their expiry date from
  the BAL appender (180 days) and are deleted by SLG2.
