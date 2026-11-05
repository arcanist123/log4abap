*&---------------------------------------------------------------------*
*& log4abap: write events from ZLOG4ABP_EVENT as NDJSON
*&---------------------------------------------------------------------*
*& One JSON object per event and line, oldest first, for reading from the
*& list or the spool of a background job. Times are UTC.
*&
*& The spool keeps at most 255 characters per line. A longer event is
*& split: every following line starts with "+". Remove the "+" and append
*& the line to the previous one to restore the JSON object.
*&
*& Needs authorization object ZLOG4ABP_R with activity 03. Messages about
*& the row limit go to the job log, so the list holds JSON only.
*&---------------------------------------------------------------------*
REPORT zlog4abp_read LINE-SIZE 255 NO STANDARD PAGE HEADING.

CONSTANTS gc_width TYPE i VALUE 255.

PARAMETERS p_run TYPE c LENGTH 32.
PARAMETERS p_fdate TYPE d.
PARAMETERS p_ftime TYPE t.
PARAMETERS p_tdate TYPE d.
PARAMETERS p_ttime TYPE t DEFAULT '235959'.
PARAMETERS p_level TYPE zlog4abp_level DEFAULT 1.
PARAMETERS p_cat TYPE zlog4abp_category.
PARAMETERS p_job TYPE btcjob.
PARAMETERS p_pay AS CHECKBOX.
PARAMETERS p_rows TYPE i DEFAULT 1000.
PARAMETERS p_maxp TYPE i DEFAULT 65536.


CLASS lcl_main DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS check_input.
    CLASS-METHODS run.
  PRIVATE SECTION.
    CLASS-METHODS to_timestamp
      IMPORTING i_date          TYPE d
                i_time          TYPE t
      RETURNING VALUE(r_result) TYPE timestampl.
ENDCLASS.


CLASS lcl_main IMPLEMENTATION.

  METHOD check_input.
    IF p_run IS NOT INITIAL AND ( strlen( p_run ) <> 32 OR p_run CN '0123456789ABCDEF' ).
      MESSAGE 'Run ID must have 32 hexadecimal characters' TYPE 'E'.
    ENDIF.
    IF p_rows < 0 OR p_maxp < 0.
      MESSAGE 'Limits must not be negative' TYPE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD run.
    DATA l_filter TYPE zlog4abp_cl_reader=>ty_filter.
    DATA l_result TYPE zlog4abp_cl_reader=>ty_result.

    l_filter-run_id = p_run.
    IF p_fdate IS NOT INITIAL.
      l_filter-from_ts = to_timestamp( i_date = p_fdate i_time = p_ftime ).
    ENDIF.
    IF p_tdate IS NOT INITIAL.
      " Up to the end of the given second
      l_filter-to_ts = to_timestamp( i_date = p_tdate i_time = p_ttime ) + '0.9999999'.
    ENDIF.
    l_filter-min_level = p_level.
    l_filter-category = p_cat.
    l_filter-job_name = p_job.
    l_filter-with_payload = p_pay.
    l_filter-max_rows = p_rows.
    l_filter-max_payload = p_maxp.

    DATA(l_reader) = NEW zlog4abp_cl_reader( ).
    TRY.
        l_result = l_reader->read( l_filter ).
      CATCH zlog4abp_cx_not_authorized INTO DATA(l_error).
        DATA(l_text) = l_error->get_text( ).
        MESSAGE l_text TYPE 'E'.
    ENDTRY.

    LOOP AT l_result-rows INTO DATA(row).
      DATA(l_lines) = zlog4abp_cl_reader=>split_line(
        i_line  = l_reader->to_json( i_row          = row
                                     i_with_payload = l_filter-with_payload
                                     i_max_payload  = l_filter-max_payload )
        i_width = gc_width ).
      LOOP AT l_lines INTO DATA(line).
        WRITE / line.
      ENDLOOP.
    ENDLOOP.

    IF l_result-more = abap_true.
      MESSAGE |Row limit reached: { lines( l_result-rows ) } events written, more exist| TYPE 'S'.
    ELSE.
      MESSAGE |{ lines( l_result-rows ) } events written| TYPE 'S'.
    ENDIF.
  ENDMETHOD.

  METHOD to_timestamp.
    DATA l_digits TYPE n LENGTH 14.
    l_digits = |{ i_date }{ i_time }|.
    r_result = l_digits.
  ENDMETHOD.

ENDCLASS.


AT SELECTION-SCREEN.
  lcl_main=>check_input( ).

START-OF-SELECTION.
  lcl_main=>run( ).
