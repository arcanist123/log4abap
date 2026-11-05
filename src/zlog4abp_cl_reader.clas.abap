"! <p class="shorttext synchronized">log4abap: read events from ZLOG4ABP_EVENT as JSON</p>
"! Reads events by run ID, time range, minimum level, category prefix and job
"! name, and converts them to one JSON object per event.
"! <ul>
"! <li>Reading needs authorization object ZLOG4ABP_R with activity 03.</li>
"! <li>At most MAX_ROWS events are returned (default 1000), oldest first.</li>
"! <li>The payload column is only read when WITH_PAYLOAD is set.</li>
"! <li>A payload that was truncated when it was stored, or that exceeds
"!     MAX_PAYLOAD (default 64 KB), is written as a JSON string with
"!     payload_truncated = true, because it is no longer valid JSON.</li>
"! </ul>
CLASS zlog4abp_cl_reader DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_activity TYPE zlog4abp_cx_not_authorized=>ty_activity.
    TYPES:
      BEGIN OF ty_filter,
        "! Only events of this run; initial = all runs
        run_id       TYPE sysuuid_x16,
        "! Earliest event time (UTC); initial = no lower limit
        from_ts      TYPE timestampl,
        "! Latest event time (UTC); initial = no upper limit
        to_ts        TYPE timestampl,
        "! Minimum level; initial = all levels
        min_level    TYPE int1,
        "! Category prefix on full segments, e.g. ZSD.IMPORT; initial or * = all
        category     TYPE string,
        "! Only events of this job; initial = all
        job_name     TYPE btcjob,
        "! Read and return the payload
        with_payload TYPE abap_bool,
        "! Maximum number of events; 0 = C_DEFAULT_MAX_ROWS
        max_rows     TYPE i,
        "! Maximum payload characters per event; 0 = C_DEFAULT_MAX_PAYLOAD
        max_payload  TYPE i,
      END OF ty_filter.
    TYPES:
      BEGIN OF ty_row,
        event_id       TYPE sysuuid_x16,
        run_id         TYPE sysuuid_x16,
        event_ts       TYPE timestampl,
        seq_no         TYPE int4,
        log_level      TYPE int1,
        category       TYPE zlog4abp_category,
        uname          TYPE syuname,
        program_name   TYPE progname,
        job_name       TYPE btcjob,
        job_count      TYPE btcjobcnt,
        msg_text       TYPE string,
        msgid          TYPE symsgid,
        msgno          TYPE symsgno,
        source_pos     TYPE zlog4abp_source_pos,
        has_payload    TYPE abap_bool,
        payload_len    TYPE int4,
        payload_trunc  TYPE abap_bool,
        context_json   TYPE string,
        exception_json TYPE string,
        payload_json   TYPE string,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.
    TYPES:
      ty_run_ids    TYPE RANGE OF sysuuid_x16,
      ty_timestamps TYPE RANGE OF timestampl,
      ty_levels     TYPE RANGE OF int1,
      ty_categories TYPE RANGE OF zlog4abp_category,
      ty_job_names  TYPE RANGE OF btcjob,
      BEGIN OF ty_selection,
        run_ids      TYPE ty_run_ids,
        timestamps   TYPE ty_timestamps,
        levels       TYPE ty_levels,
        categories   TYPE ty_categories,
        job_names    TYPE ty_job_names,
        with_payload TYPE abap_bool,
        "! Rows to read; one more than the filter's MAX_ROWS to detect more rows
        max_rows     TYPE i,
      END OF ty_selection.
    TYPES:
      BEGIN OF ty_result,
        rows TYPE ty_rows,
        "! More events matched than MAX_ROWS
        more TYPE abap_bool,
      END OF ty_result.

    "! Authorization object for reading (03) and deleting (06) events
    CONSTANTS c_auth_object LIKE zlog4abp_cx_not_authorized=>c_auth_object
      VALUE zlog4abp_cx_not_authorized=>c_auth_object.
    CONSTANTS:
      BEGIN OF c_activity,
        read   TYPE ty_activity VALUE '03',
        delete TYPE ty_activity VALUE '06',
      END OF c_activity.
    CONSTANTS c_default_max_rows TYPE i VALUE 1000.
    CONSTANTS c_default_max_payload TYPE i VALUE 65536.
    "! First character of a continuation line written by SPLIT_LINE( )
    CONSTANTS c_continuation TYPE c LENGTH 1 VALUE '+'.
    "! JSON escape for a blank, used by SPLIT_LINE( ) at the end of a physical line
    CONSTANTS c_escaped_blank TYPE string VALUE `\u0020`.

    "! Check the authorization for an activity
    "! @parameter i_activity | Activity, see C_ACTIVITY
    "! @parameter r_result | Authorized
    CLASS-METHODS is_authorized
      IMPORTING i_activity      TYPE ty_activity
      RETURNING VALUE(r_result) TYPE abap_bool.

    "! Selection for a category prefix on full segments: the category itself
    "! and everything below it
    "! @parameter i_category | Category prefix; initial or * selects all
    "! @parameter r_result | Range for column CATEGORY
    CLASS-METHODS category_range
      IMPORTING i_category      TYPE csequence
      RETURNING VALUE(r_result) TYPE ty_categories.

    "! Format a UTC time stamp as ISO 8601 with milliseconds, e.g. 2026-11-05T09:05:00.123Z
    "! @parameter i_timestamp | Time stamp
    "! @parameter r_result | Text; initial for an initial time stamp
    CLASS-METHODS format_timestamp
      IMPORTING i_timestamp     TYPE timestampl
      RETURNING VALUE(r_result) TYPE string.

    "! Split a line into physical lines of at most I_WIDTH characters, for
    "! output to a list or spool. Every line after the first starts with
    "! C_CONTINUATION; remove it and join the lines to restore the original.
    "! A space at the end of a physical line (which the spool would drop) is
    "! written as the JSON escape \u0020 (C_ESCAPED_BLANK), so the input must be JSON.
    "! @parameter i_line | JSON text
    "! @parameter i_width | Maximum physical line length, at least 16
    "! @parameter r_result | Physical lines
    CLASS-METHODS split_line
      IMPORTING i_line          TYPE string
                i_width         TYPE i
      RETURNING VALUE(r_result) TYPE string_table.

    "! @parameter i_json | JSON writer; a default one if not supplied
    METHODS constructor
      IMPORTING i_json TYPE REF TO zlog4abp_cl_json OPTIONAL.

    "! Read events. Never reads more than MAX_ROWS events.
    "! @parameter i_filter | Filter
    "! @parameter r_result | Events, oldest first
    "! @raising zlog4abp_cx_not_authorized | No authorization for activity 03
    METHODS read
      IMPORTING i_filter        TYPE ty_filter
      RETURNING VALUE(r_result) TYPE ty_result
      RAISING   zlog4abp_cx_not_authorized.

    "! Read events as JSON, one object per line (NDJSON)
    "! @parameter i_filter | Filter
    "! @parameter r_result | One JSON object per event
    "! @raising zlog4abp_cx_not_authorized | No authorization for activity 03
    METHODS read_json
      IMPORTING i_filter        TYPE ty_filter
      RETURNING VALUE(r_result) TYPE string_table
      RAISING   zlog4abp_cx_not_authorized.

    "! Convert one event to a JSON object
    "! @parameter i_row | Event
    "! @parameter i_with_payload | Include the payload; otherwise payload is null
    "! @parameter i_max_payload | Maximum payload characters; 0 = C_DEFAULT_MAX_PAYLOAD
    "! @parameter r_result | JSON object on one line
    METHODS to_json
      IMPORTING i_row           TYPE ty_row
                i_with_payload  TYPE abap_bool DEFAULT abap_false
                i_max_payload   TYPE i DEFAULT 0
      RETURNING VALUE(r_result) TYPE string.

  PROTECTED SECTION.
    "! Select the rows. Unit tests redefine this method.
    "! @parameter i_selection | Ranges and row limit
    "! @parameter r_result | Rows ordered by EVENT_TS, SEQ_NO
    METHODS select_rows
      IMPORTING i_selection     TYPE ty_selection
      RETURNING VALUE(r_result) TYPE ty_rows.

    "! Authorization check. Unit tests redefine this method.
    "! @parameter i_activity | Activity
    "! @parameter r_result | Authorized
    METHODS check_authority
      IMPORTING i_activity      TYPE ty_activity
      RETURNING VALUE(r_result) TYPE abap_bool.

  PRIVATE SECTION.
    DATA m_json TYPE REF TO zlog4abp_cl_json.

    METHODS to_selection
      IMPORTING i_filter        TYPE ty_filter
      RETURNING VALUE(r_result) TYPE ty_selection.

    METHODS optional_text
      IMPORTING i_text          TYPE csequence
      RETURNING VALUE(r_result) TYPE string.

    METHODS raw_or
      IMPORTING i_json          TYPE string
                i_default       TYPE string
      RETURNING VALUE(r_result) TYPE string.

ENDCLASS.



CLASS zlog4abp_cl_reader IMPLEMENTATION.


  METHOD is_authorized.
    AUTHORITY-CHECK OBJECT c_auth_object
      ID 'ACTVT' FIELD i_activity.
    r_result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD category_range.
    DATA l_pattern TYPE string.

    DATA(l_category) = zlog4abp_cl_config=>normalize_category( i_category ).
    IF l_category = zlog4abp_cl_config=>c_wildcard.
      RETURN.
    ENDIF.

    " The pattern must treat the category literally: escape CP's special characters.
    l_pattern = l_category.
    REPLACE ALL OCCURRENCES OF `#` IN l_pattern WITH `##`.
    REPLACE ALL OCCURRENCES OF `*` IN l_pattern WITH `#*`.
    REPLACE ALL OCCURRENCES OF `+` IN l_pattern WITH `#+`.

    APPEND VALUE #( sign = 'I' option = 'EQ' low = l_category ) TO r_result.
    APPEND VALUE #( sign = 'I' option = 'CP' low = l_pattern && zlog4abp_cl_config=>c_separator && `*` )
      TO r_result.
  ENDMETHOD.


  METHOD format_timestamp.
    DATA l_seconds TYPE p LENGTH 8 DECIMALS 0.
    DATA l_digits TYPE n LENGTH 14.
    DATA l_millis TYPE n LENGTH 3.

    IF i_timestamp IS INITIAL.
      RETURN.
    ENDIF.
    l_seconds = floor( i_timestamp ).
    l_digits = l_seconds.
    l_millis = floor( ( i_timestamp - l_seconds ) * 1000 ).
    DATA(l_text) = CONV string( l_digits ).
    r_result = substring( val = l_text len = 4 ) && `-` && substring( val = l_text off = 4 len = 2 )
            && `-` && substring( val = l_text off = 6 len = 2 ) && `T` && substring( val = l_text off = 8 len = 2 )
            && `:` && substring( val = l_text off = 10 len = 2 ) && `:` && substring( val = l_text off = 12 len = 2 )
            && `.` && l_millis && `Z`.
  ENDMETHOD.


  METHOD split_line.
    DATA l_chunk TYPE string.
    DATA l_offset TYPE i.

    DATA(l_length) = strlen( i_line ).
    " Room for the continuation character and a trailing   (5 more characters)
    DATA(l_width) = nmax( val1 = i_width val2 = 16 ) - 6.

    IF l_length <= l_width.
      APPEND i_line TO r_result.
      IF l_length > 0 AND substring( val = i_line off = l_length - 1 ) = ` `.
        r_result[ 1 ] = substring( val = i_line len = l_length - 1 ) && c_escaped_blank.
      ENDIF.
      RETURN.
    ENDIF.

    WHILE l_offset < l_length.
      l_chunk = substring( val = i_line off = l_offset len = nmin( val1 = l_width val2 = l_length - l_offset ) ).
      l_offset = l_offset + strlen( l_chunk ).
      " Our JSON has no blanks between tokens, so a blank is always inside a string.
      IF substring( val = l_chunk off = strlen( l_chunk ) - 1 ) = ` `.
        l_chunk = substring( val = l_chunk len = strlen( l_chunk ) - 1 ) && c_escaped_blank.
      ENDIF.
      IF r_result IS NOT INITIAL.
        l_chunk = c_continuation && l_chunk.
      ENDIF.
      APPEND l_chunk TO r_result.
    ENDWHILE.
  ENDMETHOD.


  METHOD constructor.
    m_json = COND #( WHEN i_json IS BOUND THEN i_json ELSE NEW #( ) ).
  ENDMETHOD.


  METHOD read.
    IF check_authority( c_activity-read ) = abap_false.
      RAISE EXCEPTION TYPE zlog4abp_cx_not_authorized
        EXPORTING
          i_activity = c_activity-read.
    ENDIF.

    DATA(l_selection) = to_selection( i_filter ).
    TRY.
        r_result-rows = select_rows( l_selection ).
      CATCH cx_sy_open_sql_db.
        CLEAR r_result-rows.
    ENDTRY.

    IF lines( r_result-rows ) >= l_selection-max_rows.
      r_result-more = abap_true.
      DELETE r_result-rows FROM l_selection-max_rows.
    ENDIF.
  ENDMETHOD.


  METHOD read_json.
    DATA(l_result) = read( i_filter ).
    LOOP AT l_result-rows INTO DATA(row).
      APPEND to_json( i_row          = row
                      i_with_payload = i_filter-with_payload
                      i_max_payload  = i_filter-max_payload ) TO r_result.
    ENDLOOP.
  ENDMETHOD.


  METHOD to_json.
    DATA l_payload TYPE string.
    DATA l_truncated TYPE abap_bool.

    DATA(l_max_payload) = COND i( WHEN i_max_payload > 0 THEN i_max_payload ELSE c_default_max_payload ).

    l_truncated = i_row-payload_trunc.
    IF i_with_payload = abap_false OR i_row-has_payload = abap_false OR i_row-payload_json IS INITIAL.
      l_payload = `null`.
    ELSEIF i_row-payload_trunc = abap_true.
      " A payload truncated on write is not valid JSON: pass it on as a string.
      l_payload = m_json->quote( substring( val = i_row-payload_json
                                            len = nmin( val1 = strlen( i_row-payload_json ) val2 = l_max_payload ) ) ).
    ELSEIF strlen( i_row-payload_json ) > l_max_payload.
      l_payload = m_json->quote( substring( val = i_row-payload_json len = l_max_payload ) ).
      l_truncated = abap_true.
    ELSE.
      l_payload = i_row-payload_json.
    ENDIF.

    r_result = `{"event_id":` && m_json->quote( |{ i_row-event_id }| )
            && `,"run_id":` && m_json->quote( |{ i_row-run_id }| )
            && `,"ts":` && optional_text( format_timestamp( i_row-event_ts ) )
            && `,"seq_no":` && |{ i_row-seq_no }|
            && `,"level":` && m_json->quote( zlog4abp_cl_formatter=>level_name( i_row-log_level ) )
            && `,"category":` && m_json->quote( i_row-category )
            && `,"message":` && m_json->quote( i_row-msg_text )
            && `,"msgid":` && optional_text( i_row-msgid )
            && `,"msgno":` && COND string( WHEN i_row-msgid IS INITIAL THEN `null`
                                           ELSE m_json->quote( |{ i_row-msgno }| ) )
            && `,"source_pos":` && optional_text( i_row-source_pos )
            && `,"user":` && optional_text( i_row-uname )
            && `,"program":` && optional_text( i_row-program_name )
            && `,"job_name":` && optional_text( i_row-job_name )
            && `,"job_count":` && optional_text( i_row-job_count )
            && `,"context":` && raw_or( i_json = i_row-context_json i_default = `{}` )
            && `,"exception":` && raw_or( i_json = i_row-exception_json i_default = `[]` )
            && `,"has_payload":` && COND string( WHEN i_row-has_payload = abap_true THEN `true` ELSE `false` )
            && `,"payload_len":` && |{ i_row-payload_len }|
            && `,"payload":` && l_payload
            && `,"payload_truncated":` && COND string( WHEN l_truncated = abap_true THEN `true` ELSE `false` )
            && `}`.
  ENDMETHOD.


  METHOD select_rows.
    IF i_selection-with_payload = abap_true.
      SELECT event_id, run_id, event_ts, seq_no, log_level, category, uname, program_name,
             job_name, job_count, msg_text, msgid, msgno, source_pos, has_payload, payload_len,
             payload_trunc, context_json, exception_json, payload_json
        FROM zlog4abp_event
        WHERE run_id    IN @i_selection-run_ids
          AND event_ts  IN @i_selection-timestamps
          AND log_level IN @i_selection-levels
          AND category  IN @i_selection-categories
          AND job_name  IN @i_selection-job_names
        ORDER BY event_ts, seq_no
        INTO CORRESPONDING FIELDS OF TABLE @r_result
        UP TO @i_selection-max_rows ROWS.                 "#EC CI_SUBRC
    ELSE.
      " The payload column is only read on request.
      SELECT event_id, run_id, event_ts, seq_no, log_level, category, uname, program_name,
             job_name, job_count, msg_text, msgid, msgno, source_pos, has_payload, payload_len,
             payload_trunc, context_json, exception_json
        FROM zlog4abp_event
        WHERE run_id    IN @i_selection-run_ids
          AND event_ts  IN @i_selection-timestamps
          AND log_level IN @i_selection-levels
          AND category  IN @i_selection-categories
          AND job_name  IN @i_selection-job_names
        ORDER BY event_ts, seq_no
        INTO CORRESPONDING FIELDS OF TABLE @r_result
        UP TO @i_selection-max_rows ROWS.                 "#EC CI_SUBRC
    ENDIF.
  ENDMETHOD.


  METHOD check_authority.
    r_result = is_authorized( i_activity ).
  ENDMETHOD.


  METHOD to_selection.
    IF i_filter-run_id IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = i_filter-run_id ) TO r_result-run_ids.
    ENDIF.

    IF i_filter-from_ts IS NOT INITIAL AND i_filter-to_ts IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'BT' low = i_filter-from_ts high = i_filter-to_ts )
        TO r_result-timestamps.
    ELSEIF i_filter-from_ts IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'GE' low = i_filter-from_ts ) TO r_result-timestamps.
    ELSEIF i_filter-to_ts IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'LE' low = i_filter-to_ts ) TO r_result-timestamps.
    ENDIF.

    IF i_filter-min_level > 1.
      APPEND VALUE #( sign = 'I' option = 'GE' low = i_filter-min_level ) TO r_result-levels.
    ENDIF.

    r_result-categories = category_range( i_filter-category ).

    IF i_filter-job_name IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = i_filter-job_name ) TO r_result-job_names.
    ENDIF.

    r_result-with_payload = i_filter-with_payload.
    r_result-max_rows = COND i( WHEN i_filter-max_rows > 0 THEN i_filter-max_rows ELSE c_default_max_rows ) + 1.
  ENDMETHOD.


  METHOD optional_text.
    IF i_text IS INITIAL.
      r_result = `null`.
    ELSE.
      r_result = m_json->quote( condense( i_text ) ).
    ENDIF.
  ENDMETHOD.


  METHOD raw_or.
    IF i_json IS INITIAL.
      r_result = i_default.
    ELSE.
      r_result = i_json.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
