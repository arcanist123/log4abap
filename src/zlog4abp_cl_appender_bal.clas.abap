"! <p class="shorttext synchronized">log4abap: appender for the application log (SLG1)</p>
"! Writes a summary of each event to the application log for support users.
"! Configuration name: BAL.
"! <ul>
"! <li>Only INFO, WARN and ERROR are written, even if a rule enables lower levels.</li>
"! <li>One log of object ZLOG4ABP per run ID; the external ID is the run ID.</li>
"! <li>Each event becomes the text "CATEGORY: message", cut into lines of
"! C_MAX_TEXT characters (at most C_MAX_MESSAGE_LINES), followed by a line
"! with the event ID. The JSON payload is never written; it stays in
"! ZLOG4ABP_EVENT.</li>
"! <li>Messages are saved when C_DEFAULT_BUFFER_SIZE events are waiting and on
"! FLUSH( ), through BAL_DB_SAVE's second connection. The caller's LUW is
"! never committed or rolled back.</li>
"! </ul>
"! If a log cannot be created, a message cannot be added or a save fails, the
"! events concerned are dropped and counted. The appender never logs through
"! the framework.
CLASS zlog4abp_cl_appender_bal DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zlog4abp_if_appender.

    TYPES ty_handles TYPE bal_t_logh.

    "! Application log object (transaction SLG0)
    CONSTANTS c_object TYPE balobj_d VALUE 'ZLOG4ABP'.
    "! Characters kept by BAL_LOG_MSG_ADD_FREE_TEXT per message (measured on the target system)
    CONSTANTS c_max_text TYPE i VALUE 200.
    "! Message lines per event before the text is cut off
    CONSTANTS c_max_message_lines TYPE i VALUE 5.
    "! Lowest level written to the application log
    CONSTANTS c_min_level TYPE int1 VALUE zlog4abp_if_log=>c_level-info.
    "! Default number of events waiting before they are saved
    CONSTANTS c_default_buffer_size TYPE i VALUE 50.
    "! Days until a log expires (header field ALDATE_DEL)
    CONSTANTS c_retention_days TYPE i VALUE 180.
    "! A log with this many messages is released from memory after its next
    "! save; later events of the run start a new log with the same external ID
    CONSTANTS c_max_log_messages TYPE i VALUE 1000.

    "! @parameter i_buffer_size | Events waiting before a save; 1 or less saves every event
    METHODS constructor
      IMPORTING i_buffer_size TYPE i DEFAULT c_default_buffer_size.

    "! Change the buffer size. Takes effect with the next event.
    "! @parameter i_buffer_size | Events waiting before a save
    METHODS set_buffer_size
      IMPORTING i_buffer_size TYPE i.

    "! Number of events added to a log but not saved yet
    "! @parameter r_result | Count
    METHODS get_unsaved_count
      RETURNING VALUE(r_result) TYPE i.

    "! Number of events that could not be added or saved
    "! @parameter r_result | Count
    METHODS get_dropped_count
      RETURNING VALUE(r_result) TYPE i.

  PROTECTED SECTION.
    "! Create a log in memory. Unit tests redefine the methods of this
    "! section so they do not call the application log.
    "! @parameter i_run_id | Run ID, used as external ID
    "! @parameter i_program | Program name for the log header
    "! @parameter r_result | Log handle; initial if the log cannot be created
    METHODS create_log
      IMPORTING i_run_id        TYPE sysuuid_x16
                i_program       TYPE progname
      RETURNING VALUE(r_result) TYPE balloghndl.

    "! Add one free-text message to a log in memory
    "! @parameter i_handle | Log handle
    "! @parameter i_msgty | Message type
    "! @parameter i_probclass | Problem class
    "! @parameter i_detlevel | Level of detail: 1 summary, 2 continuation
    "! @parameter i_text | Text of at most C_MAX_TEXT characters
    "! @parameter r_result | True if the message was added
    METHODS add_text
      IMPORTING i_handle        TYPE balloghndl
                i_msgty         TYPE symsgty
                i_probclass     TYPE balprobcl
                i_detlevel      TYPE ballevel
                i_text          TYPE string
      RETURNING VALUE(r_result) TYPE abap_bool.

    "! Save logs through the second database connection, which BAL commits
    "! @parameter i_handles | Log handles
    "! @parameter r_result | True if the save succeeded
    METHODS save
      IMPORTING i_handles       TYPE ty_handles
      RETURNING VALUE(r_result) TYPE abap_bool.

    "! Remove a log from memory
    "! @parameter i_handle | Log handle
    METHODS release
      IMPORTING i_handle TYPE balloghndl.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_line,
        text     TYPE string,
        detlevel TYPE ballevel,
      END OF ty_line,
      ty_lines TYPE STANDARD TABLE OF ty_line WITH DEFAULT KEY,
      BEGIN OF ty_log,
        run_id   TYPE sysuuid_x16,
        handle   TYPE balloghndl,
        messages TYPE i,
        unsaved  TYPE i,
      END OF ty_log,
      ty_logs TYPE HASHED TABLE OF ty_log WITH UNIQUE KEY run_id.

    DATA m_logs TYPE ty_logs.
    DATA m_buffer_size TYPE i.
    DATA m_unsaved_count TYPE i.
    DATA m_dropped_count TYPE i.

    "! Message lines for an event: the text in pieces, then the event reference
    "! @parameter i_event | Event
    "! @parameter r_result | Lines of at most C_MAX_TEXT characters
    METHODS build_lines
      IMPORTING i_event         TYPE zlog4abp_s_event
      RETURNING VALUE(r_result) TYPE ty_lines.

ENDCLASS.



CLASS zlog4abp_cl_appender_bal IMPLEMENTATION.


  METHOD constructor.
    set_buffer_size( i_buffer_size ).
  ENDMETHOD.


  METHOD set_buffer_size.
    m_buffer_size = nmax( val1 = i_buffer_size val2 = 1 ).
  ENDMETHOD.


  METHOD get_unsaved_count.
    r_result = m_unsaved_count.
  ENDMETHOD.


  METHOD get_dropped_count.
    r_result = m_dropped_count.
  ENDMETHOD.


  METHOD zlog4abp_if_appender~append.
    DATA l_msgty TYPE symsgty.
    DATA l_probclass TYPE balprobcl.
    DATA l_added TYPE abap_bool.
    FIELD-SYMBOLS <l_log> TYPE ty_log.

    IF i_event-log_level < c_min_level OR i_event-log_level >= zlog4abp_if_log=>c_level-off.
      RETURN.
    ENDIF.

    CASE i_event-log_level.
      WHEN zlog4abp_if_log=>c_level-error.
        l_msgty = 'E'.
        l_probclass = '1'.
      WHEN zlog4abp_if_log=>c_level-warn.
        l_msgty = 'W'.
        l_probclass = '2'.
      WHEN OTHERS.
        l_msgty = 'I'.
        l_probclass = '4'.
    ENDCASE.

    READ TABLE m_logs ASSIGNING <l_log> WITH TABLE KEY run_id = i_event-run_id.
    IF sy-subrc <> 0.
      DATA(l_handle) = create_log( i_run_id  = i_event-run_id
                                   i_program = i_event-program_name ).
      IF l_handle IS INITIAL.
        m_dropped_count = m_dropped_count + 1.
        RETURN.
      ENDIF.
      INSERT VALUE #( run_id = i_event-run_id handle = l_handle ) INTO TABLE m_logs ASSIGNING <l_log>.
    ENDIF.

    LOOP AT build_lines( i_event ) INTO DATA(line).
      IF add_text( i_handle    = <l_log>-handle
                   i_msgty     = l_msgty
                   i_probclass = l_probclass
                   i_detlevel  = line-detlevel
                   i_text      = line-text ) = abap_true.
        l_added = abap_true.
        <l_log>-messages = <l_log>-messages + 1.
      ENDIF.
    ENDLOOP.

    IF l_added = abap_false.
      m_dropped_count = m_dropped_count + 1.
      RETURN.
    ENDIF.
    <l_log>-unsaved = <l_log>-unsaved + 1.
    m_unsaved_count = m_unsaved_count + 1.

    IF m_unsaved_count >= m_buffer_size.
      zlog4abp_if_appender~flush( ).
    ENDIF.
  ENDMETHOD.


  METHOD zlog4abp_if_appender~flush.
    DATA l_handles TYPE ty_handles.
    FIELD-SYMBOLS <l_log> TYPE ty_log.

    LOOP AT m_logs INTO DATA(log) WHERE unsaved > 0.
      INSERT log-handle INTO TABLE l_handles.
    ENDLOOP.
    IF l_handles IS INITIAL.
      RETURN.
    ENDIF.

    DATA(l_saved) = save( l_handles ).

    " A failed save is not retried: the logs are released so memory stays bounded.
    LOOP AT m_logs ASSIGNING <l_log> WHERE unsaved > 0.
      IF l_saved = abap_false.
        m_dropped_count = m_dropped_count + <l_log>-unsaved.
      ENDIF.
      <l_log>-unsaved = 0.
      IF l_saved = abap_false OR <l_log>-messages >= c_max_log_messages.
        release( <l_log>-handle ).
        CLEAR <l_log>-handle.
      ENDIF.
    ENDLOOP.
    DELETE m_logs WHERE handle IS INITIAL.
    m_unsaved_count = 0.
  ENDMETHOD.


  METHOD build_lines.
    DATA l_detlevel TYPE ballevel.

    DATA(l_rest) = |{ i_event-category }: { i_event-msg_text }|.
    DO c_max_message_lines TIMES.
      l_detlevel = COND #( WHEN sy-index = 1 THEN '1' ELSE '2' ).
      IF strlen( l_rest ) <= c_max_text OR sy-index = c_max_message_lines.
        APPEND VALUE #( text     = zlog4abp_cl_formatter=>shorten( i_text = l_rest i_max_length = c_max_text )
                        detlevel = l_detlevel ) TO r_result.
        EXIT.
      ENDIF.
      APPEND VALUE #( text = substring( val = l_rest len = c_max_text ) detlevel = l_detlevel ) TO r_result.
      l_rest = substring( val = l_rest off = c_max_text ).
    ENDDO.

    DATA(l_reference) = |Event { i_event-event_id } in ZLOG4ABP_EVENT|.
    IF i_event-msgid IS NOT INITIAL.
      l_reference = |{ l_reference }, message { i_event-msgid } { i_event-msgno }|.
    ENDIF.
    IF i_event-has_payload = abap_true.
      l_reference = |{ l_reference }, payload of { i_event-payload_len } characters|.
      IF i_event-payload_trunc = abap_true.
        l_reference = |{ l_reference } (truncated)|.
      ENDIF.
    ENDIF.
    IF i_event-exception_json IS NOT INITIAL.
      l_reference = |{ l_reference }, exception chain|.
    ENDIF.
    APPEND VALUE #( text     = zlog4abp_cl_formatter=>shorten( i_text = l_reference i_max_length = c_max_text )
                    detlevel = '2' ) TO r_result.
  ENDMETHOD.


  METHOD create_log.
    DATA l_header TYPE bal_s_log.

    l_header-object = c_object.
    l_header-extnumber = |{ i_run_id }|.
    l_header-alprog = i_program.
    l_header-aldate_del = sy-datum + c_retention_days.

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log                 = l_header
      IMPORTING
        e_log_handle            = r_result
      EXCEPTIONS
        log_header_inconsistent = 1
        OTHERS                  = 2.
    IF sy-subrc <> 0.
      CLEAR r_result.
    ENDIF.
  ENDMETHOD.


  METHOD add_text.
    DATA l_text TYPE c LENGTH c_max_text.
    DATA l_logged TYPE boolean.

    l_text = i_text.
    CALL FUNCTION 'BAL_LOG_MSG_ADD_FREE_TEXT'
      EXPORTING
        i_log_handle     = i_handle
        i_msgty          = i_msgty
        i_probclass      = i_probclass
        i_detlevel       = i_detlevel
        i_text           = l_text
      IMPORTING
        e_msg_was_logged = l_logged
      EXCEPTIONS
        log_not_found    = 1
        msg_inconsistent = 2
        log_is_full      = 3
        OTHERS           = 4.
    r_result = xsdbool( sy-subrc = 0 AND l_logged = abap_true ).
  ENDMETHOD.


  METHOD save.
    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle       = i_handles
        i_2th_connection     = abap_true
        i_2th_connect_commit = abap_true
      EXCEPTIONS
        log_not_found        = 1
        save_not_allowed     = 2
        numbering_error      = 3
        OTHERS               = 4.
    r_result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD release.
    CALL FUNCTION 'BAL_LOG_REFRESH'
      EXPORTING
        i_log_handle  = i_handle
      EXCEPTIONS
        log_not_found = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      " Nothing to release: the log is no longer in memory.
      RETURN.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
