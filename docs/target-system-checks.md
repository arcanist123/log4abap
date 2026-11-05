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
- **Delivery class:** `ZLOG4ABP_CONFIG` has delivery class A, so changes in production are not
  blocked by client customizing settings. The maintenance view (Phase 4) will have no transport
  recording.
