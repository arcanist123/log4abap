"! <p class="shorttext synchronized">log4abap: run context (run ID and key-value pairs)</p>
"! Holds the run ID and caller-defined key-value pairs of the internal session,
"! and captures user, program, transaction and, in background runs, the job.
"! <br/>Static state does not cross SUBMIT, RFC or bgRFC boundaries. Pass
"! GET_RUN_ID( ) to the other side and call SET_RUN_ID( ) there.
CLASS zlog4abp_cl_context DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_info,
        uname        TYPE syuname,
        program_name TYPE progname,
        tcode        TYPE sytcode,
        batch        TYPE abap_bool,
        job_name     TYPE btcjob,
        job_count    TYPE btcjobcnt,
      END OF ty_info,
      BEGIN OF ty_entry,
        key   TYPE string,
        value TYPE string,
      END OF ty_entry,
      ty_entries TYPE SORTED TABLE OF ty_entry WITH UNIQUE KEY key.

    "! Run ID of this internal session; generated on first use
    "! @parameter r_result | Run ID
    CLASS-METHODS get_run_id
      RETURNING VALUE(r_result) TYPE sysuuid_x16.

    "! Continue a run started elsewhere (after SUBMIT, RFC, bgRFC)
    "! @parameter i_run_id | Run ID passed by the caller
    CLASS-METHODS set_run_id
      IMPORTING i_run_id TYPE sysuuid_x16.

    "! Add or replace a context value
    "! @parameter i_key | Key
    "! @parameter i_value | Elementary value, stored as text
    CLASS-METHODS put
      IMPORTING i_key   TYPE csequence
                i_value TYPE simple.

    "! Remove a context value
    "! @parameter i_key | Key
    CLASS-METHODS remove
      IMPORTING i_key TYPE csequence.

    "! Remove all context values. The run ID is kept.
    CLASS-METHODS clear.

    "! Context values
    "! @parameter r_result | Key-value pairs
    CLASS-METHODS get_entries
      RETURNING VALUE(r_result) TYPE ty_entries.

    "! Session information captured on first use
    "! @parameter r_result | User, program, transaction, job
    CLASS-METHODS get_info
      RETURNING VALUE(r_result) TYPE ty_info.

    "! Context as JSON object: session information plus "values"
    "! @parameter r_result | JSON object
    CLASS-METHODS as_json
      RETURNING VALUE(r_result) TYPE string.

    "! Next event sequence number in this internal session
    "! @parameter r_result | Sequence number, starting at 1
    CLASS-METHODS next_seq_no
      RETURNING VALUE(r_result) TYPE int4.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA g_run_id TYPE sysuuid_x16.
    CLASS-DATA g_entries TYPE ty_entries.
    CLASS-DATA g_info TYPE ty_info.
    CLASS-DATA g_info_loaded TYPE abap_bool.
    CLASS-DATA g_seq_no TYPE int4.
    CLASS-DATA g_json TYPE REF TO zlog4abp_cl_json.

    CLASS-METHODS load_info.

ENDCLASS.



CLASS zlog4abp_cl_context IMPLEMENTATION.


  METHOD get_run_id.
    IF g_run_id IS INITIAL.
      TRY.
          g_run_id = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          " Fallback that is unique enough within a system: time stamp and process
          DATA l_ts TYPE timestampl.
          GET TIME STAMP FIELD l_ts.
          g_run_id = l_ts.
      ENDTRY.
    ENDIF.
    r_result = g_run_id.
  ENDMETHOD.


  METHOD set_run_id.
    g_run_id = i_run_id.
  ENDMETHOD.


  METHOD put.
    DATA(l_entry) = VALUE ty_entry( key = i_key value = |{ i_value }| ).
    MODIFY TABLE g_entries FROM l_entry.
    IF sy-subrc <> 0.
      INSERT l_entry INTO TABLE g_entries.
    ENDIF.
  ENDMETHOD.


  METHOD remove.
    DELETE TABLE g_entries WITH TABLE KEY key = CONV string( i_key ).
  ENDMETHOD.


  METHOD clear.
    CLEAR g_entries.
  ENDMETHOD.


  METHOD get_entries.
    r_result = g_entries.
  ENDMETHOD.


  METHOD get_info.
    IF g_info_loaded = abap_false.
      load_info( ).
    ENDIF.
    r_result = g_info.
  ENDMETHOD.


  METHOD as_json.
    DATA l_pairs TYPE zlog4abp_cl_json=>ty_pairs.

    IF g_json IS NOT BOUND.
      g_json = NEW #( ).
    ENDIF.

    DATA(l_info) = get_info( ).
    LOOP AT g_entries INTO DATA(entry).
      APPEND VALUE #( name = entry-key value = entry-value ) TO l_pairs.
    ENDLOOP.

    r_result = `{"user":` && g_json->quote( l_info-uname )
            && `,"program":` && g_json->quote( l_info-program_name )
            && `,"tcode":` && g_json->quote( l_info-tcode ).
    IF l_info-batch = abap_true.
      r_result = r_result
              && `,"job_name":` && g_json->quote( l_info-job_name )
              && `,"job_count":` && g_json->quote( l_info-job_count ).
    ENDIF.
    r_result = r_result && `,"values":` && g_json->object_from_pairs( l_pairs ) && `}`.
  ENDMETHOD.


  METHOD next_seq_no.
    g_seq_no = g_seq_no + 1.
    r_result = g_seq_no.
  ENDMETHOD.


  METHOD load_info.
    g_info_loaded = abap_true.
    g_info-uname = sy-uname.
    g_info-program_name = sy-cprog.
    g_info-tcode = sy-tcode.
    g_info-batch = xsdbool( sy-batch = abap_true ).
    IF g_info-batch = abap_true.
      CALL FUNCTION 'GET_JOB_RUNTIME_INFO'
        IMPORTING
          jobcount        = g_info-job_count
          jobname         = g_info-job_name
        EXCEPTIONS
          no_runtime_info = 1
          OTHERS          = 2.
      IF sy-subrc <> 0.
        CLEAR: g_info-job_count, g_info-job_name.
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
