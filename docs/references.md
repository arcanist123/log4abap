# External references

The clean-room rules are in section 2 of the brief. No source code from another logging
project was opened, searched, fetched, copied or translated.

| Reference | Purpose |
|---|---|
| SAP ABAP keyword documentation, 7.50 (general knowledge) | Syntax and semantics of the statements used |
| SAP standard interfaces: `CL_ABAP_TYPEDESCR` and subclasses, `CL_SYSTEM_UUID`, `CL_ABAP_CONV_IN_CE=>UCCPI`, `CL_ABAP_CHAR_UTILITIES`, `IF_T100_MESSAGE`, FMs `SYSTEM_CALLSTACK` and `GET_JOB_RUNTIME_INFO` | Called by the framework |
| [abaplint](https://github.com/abaplint/abaplint) `@abaplint/cli` and [abaplint/deps](https://github.com/abaplint/deps) | Static checks for v750 (required by the brief); deps holds stubs of SAP standard objects |
| [abaplint transpiler](https://github.com/abaplint/transpiler) and [open-abap](https://github.com/open-abap/open-abap) | Running ABAP Unit locally in Node.js; open-abap provides stubs of SAP standard classes |
| abapGit serialization format (DEVC, INTF, CLAS, TABL, DTEL, DOMA XML) | Repository layout |
| GitHub search, the dotabap.org list and a web search (2026-11-05) | Checking that the names `zlog4abp` / `log4abap` are not taken; only names and search results were viewed |
