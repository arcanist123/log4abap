"! <p class="shorttext synchronized">log4abap: logger implementation</p>
"! Normally created and cached by ZLOG4ABP_CL_FACTORY. Each log method checks
"! the cached threshold first and returns at once when the level is disabled.
"! Only enabled statements format the message, serialize the payload and call
"! the supplier. Errors inside the framework or an appender are swallowed.
CLASS zlog4abp_cl_logger DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zlog4abp_if_log.

    TYPES ty_appenders TYPE STANDARD TABLE OF REF TO zlog4abp_if_appender WITH DEFAULT KEY.

    "! Default maximum payload length in characters (1 MB)
    CONSTANTS c_default_max_payload TYPE i VALUE 1048576.
    "! Pattern of this class pool's program name, used to skip its own stack frames
    CONSTANTS c_own_program TYPE string VALUE `ZLOG4ABP_CL_LOGGER*`.

    "! @parameter i_category | Category
    "! @parameter i_threshold | Lowest enabled level, see ZLOG4ABP_IF_LOG=>C_LEVEL
    "! @parameter i_appenders | Appenders that receive enabled events
    "! @parameter i_formatter | Formatter; a default one if not supplied
    "! @parameter i_json | JSON serializer; a default one if not supplied
    "! @parameter i_max_payload | Payloads longer than this are truncated
    METHODS constructor
      IMPORTING i_category    TYPE csequence
                i_threshold   TYPE int1
                i_appenders   TYPE ty_appenders OPTIONAL
                i_formatter   TYPE REF TO zlog4abp_cl_formatter OPTIONAL
                i_json        TYPE REF TO zlog4abp_cl_json OPTIONAL
                i_max_payload TYPE i DEFAULT c_default_max_payload.

    "! Lowest enabled level
    "! @parameter r_result | Threshold
    METHODS get_threshold
      RETURNING VALUE(r_result) TYPE int1.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA m_category TYPE zlog4abp_category.
    DATA m_threshold TYPE int1.
    DATA m_appenders TYPE ty_appenders.
    DATA m_formatter TYPE REF TO zlog4abp_cl_formatter.
    DATA m_json TYPE REF TO zlog4abp_cl_json.
    DATA m_max_payload TYPE i.

    METHODS log
      IMPORTING i_level     TYPE int1
                i_message   TYPE csequence OPTIONAL
                i_val1      TYPE any OPTIONAL
                i_val2      TYPE any OPTIONAL
                i_val3      TYPE any OPTIONAL
                i_val4      TYPE any OPTIONAL
                i_has_val1  TYPE abap_bool DEFAULT abap_false
                i_has_val2  TYPE abap_bool DEFAULT abap_false
                i_has_val3  TYPE abap_bool DEFAULT abap_false
                i_has_val4  TYPE abap_bool DEFAULT abap_false
                i_args      TYPE string_table OPTIONAL
                i_data      TYPE any OPTIONAL
                i_has_data  TYPE abap_bool DEFAULT abap_false
                i_exception TYPE REF TO cx_root OPTIONAL
                i_supplier  TYPE REF TO zlog4abp_if_supplier OPTIONAL
                i_msgid     TYPE symsgid OPTIONAL
                i_msgno     TYPE symsgno OPTIONAL.

    METHODS set_payload
      IMPORTING i_payload TYPE string
      CHANGING  c_event   TYPE zlog4abp_s_event.

    METHODS dispatch
      IMPORTING i_event TYPE zlog4abp_s_event.

    METHODS source_position
      RETURNING VALUE(r_result) TYPE zlog4abp_source_pos.

ENDCLASS.



CLASS zlog4abp_cl_logger IMPLEMENTATION.


  METHOD constructor.
    m_category = zlog4abp_cl_config=>normalize_category( i_category ).
    m_threshold = i_threshold.
    m_appenders = i_appenders.
    DELETE m_appenders WHERE table_line IS NOT BOUND.
    m_max_payload = i_max_payload.

    IF i_json IS BOUND.
      m_json = i_json.
    ELSE.
      m_json = NEW #( ).
    ENDIF.
    IF i_formatter IS BOUND.
      m_formatter = i_formatter.
    ELSE.
      m_formatter = NEW #( m_json ).
    ENDIF.
  ENDMETHOD.


  METHOD get_threshold.
    r_result = m_threshold.
  ENDMETHOD.


  METHOD zlog4abp_if_log~trace.
    IF zlog4abp_if_log=>c_level-trace < m_threshold.
      RETURN.
    ENDIF.
    log( i_level     = zlog4abp_if_log=>c_level-trace
         i_message   = i_message
         i_val1      = i_val1
         i_val2      = i_val2
         i_val3      = i_val3
         i_val4      = i_val4
         i_has_val1  = xsdbool( i_val1 IS SUPPLIED )
         i_has_val2  = xsdbool( i_val2 IS SUPPLIED )
         i_has_val3  = xsdbool( i_val3 IS SUPPLIED )
         i_has_val4  = xsdbool( i_val4 IS SUPPLIED )
         i_args      = i_args
         i_data      = i_data
         i_has_data  = xsdbool( i_data IS SUPPLIED )
         i_exception = i_exception
         i_supplier  = i_supplier ).
  ENDMETHOD.


  METHOD zlog4abp_if_log~debug.
    IF zlog4abp_if_log=>c_level-debug < m_threshold.
      RETURN.
    ENDIF.
    log( i_level     = zlog4abp_if_log=>c_level-debug
         i_message   = i_message
         i_val1      = i_val1
         i_val2      = i_val2
         i_val3      = i_val3
         i_val4      = i_val4
         i_has_val1  = xsdbool( i_val1 IS SUPPLIED )
         i_has_val2  = xsdbool( i_val2 IS SUPPLIED )
         i_has_val3  = xsdbool( i_val3 IS SUPPLIED )
         i_has_val4  = xsdbool( i_val4 IS SUPPLIED )
         i_args      = i_args
         i_data      = i_data
         i_has_data  = xsdbool( i_data IS SUPPLIED )
         i_exception = i_exception
         i_supplier  = i_supplier ).
  ENDMETHOD.


  METHOD zlog4abp_if_log~info.
    IF zlog4abp_if_log=>c_level-info < m_threshold.
      RETURN.
    ENDIF.
    log( i_level     = zlog4abp_if_log=>c_level-info
         i_message   = i_message
         i_val1      = i_val1
         i_val2      = i_val2
         i_val3      = i_val3
         i_val4      = i_val4
         i_has_val1  = xsdbool( i_val1 IS SUPPLIED )
         i_has_val2  = xsdbool( i_val2 IS SUPPLIED )
         i_has_val3  = xsdbool( i_val3 IS SUPPLIED )
         i_has_val4  = xsdbool( i_val4 IS SUPPLIED )
         i_args      = i_args
         i_data      = i_data
         i_has_data  = xsdbool( i_data IS SUPPLIED )
         i_exception = i_exception
         i_supplier  = i_supplier ).
  ENDMETHOD.


  METHOD zlog4abp_if_log~warn.
    IF zlog4abp_if_log=>c_level-warn < m_threshold.
      RETURN.
    ENDIF.
    log( i_level     = zlog4abp_if_log=>c_level-warn
         i_message   = i_message
         i_val1      = i_val1
         i_val2      = i_val2
         i_val3      = i_val3
         i_val4      = i_val4
         i_has_val1  = xsdbool( i_val1 IS SUPPLIED )
         i_has_val2  = xsdbool( i_val2 IS SUPPLIED )
         i_has_val3  = xsdbool( i_val3 IS SUPPLIED )
         i_has_val4  = xsdbool( i_val4 IS SUPPLIED )
         i_args      = i_args
         i_data      = i_data
         i_has_data  = xsdbool( i_data IS SUPPLIED )
         i_exception = i_exception
         i_supplier  = i_supplier ).
  ENDMETHOD.


  METHOD zlog4abp_if_log~error.
    IF zlog4abp_if_log=>c_level-error < m_threshold.
      RETURN.
    ENDIF.
    log( i_level     = zlog4abp_if_log=>c_level-error
         i_message   = i_message
         i_val1      = i_val1
         i_val2      = i_val2
         i_val3      = i_val3
         i_val4      = i_val4
         i_has_val1  = xsdbool( i_val1 IS SUPPLIED )
         i_has_val2  = xsdbool( i_val2 IS SUPPLIED )
         i_has_val3  = xsdbool( i_val3 IS SUPPLIED )
         i_has_val4  = xsdbool( i_val4 IS SUPPLIED )
         i_args      = i_args
         i_data      = i_data
         i_has_data  = xsdbool( i_data IS SUPPLIED )
         i_exception = i_exception
         i_supplier  = i_supplier ).
  ENDMETHOD.


  METHOD zlog4abp_if_log~t100.
    DATA l_level TYPE int1.

    l_level = i_level.
    IF l_level IS INITIAL.
      CASE i_msgty.
        WHEN 'E' OR 'A' OR 'X'.
          l_level = zlog4abp_if_log=>c_level-error.
        WHEN 'W'.
          l_level = zlog4abp_if_log=>c_level-warn.
        WHEN OTHERS.
          l_level = zlog4abp_if_log=>c_level-info.
      ENDCASE.
    ENDIF.
    IF l_level < m_threshold OR l_level >= zlog4abp_if_log=>c_level-off.
      RETURN.
    ENDIF.

    TRY.
        DATA(l_message) = m_formatter->t100_text(
          i_msgid = i_msgid
          i_msgno = i_msgno
          i_msgv1 = i_msgv1
          i_msgv2 = i_msgv2
          i_msgv3 = i_msgv3
          i_msgv4 = i_msgv4 ).
      CATCH cx_root.
        CLEAR l_message.
    ENDTRY.

    log( i_level     = l_level
         i_message   = l_message
         i_data      = i_data
         i_has_data  = xsdbool( i_data IS SUPPLIED )
         i_exception = i_exception
         i_msgid     = i_msgid
         i_msgno     = i_msgno ).
  ENDMETHOD.


  METHOD zlog4abp_if_log~is_enabled.
    r_result = xsdbool( i_level >= m_threshold AND i_level < zlog4abp_if_log=>c_level-off ).
  ENDMETHOD.


  METHOD zlog4abp_if_log~get_category.
    r_result = m_category.
  ENDMETHOD.


  METHOD zlog4abp_if_log~flush.
    LOOP AT m_appenders INTO DATA(appender).
      TRY.
          appender->flush( ).
        CATCH cx_root ##NO_HANDLER.
          " A failing appender must not affect the caller or the other appenders.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD log.
    DATA l_event TYPE zlog4abp_s_event.
    DATA l_message TYPE string.
    DATA l_values TYPE string_table.
    DATA l_payload TYPE string.
    DATA l_supplied_data TYPE REF TO data.
    FIELD-SYMBOLS <l_supplied> TYPE any.

    IF i_level >= zlog4abp_if_log=>c_level-off OR lines( m_appenders ) = 0.
      RETURN.
    ENDIF.

    TRY.
        " Message: the supplier's text replaces I_MESSAGE when it is not initial
        l_message = i_message.
        IF i_supplier IS BOUND.
          DATA(l_supplied_message) = i_supplier->get_message( ).
          IF l_supplied_message IS NOT INITIAL.
            l_message = l_supplied_message.
          ENDIF.
        ENDIF.
        IF l_message IS INITIAL AND i_exception IS BOUND.
          l_message = i_exception->get_text( ).
        ENDIF.

        IF i_has_val1 = abap_true.
          APPEND m_formatter->to_text( i_val1 ) TO l_values.
        ENDIF.
        IF i_has_val2 = abap_true.
          APPEND m_formatter->to_text( i_val2 ) TO l_values.
        ENDIF.
        IF i_has_val3 = abap_true.
          APPEND m_formatter->to_text( i_val3 ) TO l_values.
        ENDIF.
        IF i_has_val4 = abap_true.
          APPEND m_formatter->to_text( i_val4 ) TO l_values.
        ENDIF.
        APPEND LINES OF i_args TO l_values.
        l_event-msg_text = m_formatter->format( i_pattern = l_message i_values = l_values ).

        " Payload: I_DATA wins over the supplier's data
        IF i_has_data = abap_true.
          l_payload = m_json->serialize( i_data ).
        ELSEIF i_supplier IS BOUND.
          l_supplied_data = i_supplier->get_data( ).
          IF l_supplied_data IS BOUND.
            ASSIGN l_supplied_data->* TO <l_supplied>.
            l_payload = m_json->serialize( <l_supplied> ).
          ENDIF.
        ENDIF.
        set_payload( EXPORTING i_payload = l_payload CHANGING c_event = l_event ).

        IF i_exception IS BOUND.
          l_event-exception_json = m_json->serialize_exception( i_exception ).
        ENDIF.

        TRY.
            l_event-event_id = cl_system_uuid=>create_uuid_x16_static( ).
          CATCH cx_uuid_error.
            CLEAR l_event-event_id.
        ENDTRY.
        DATA(l_info) = zlog4abp_cl_context=>get_info( ).
        GET TIME STAMP FIELD l_event-event_ts.
        l_event-run_id       = zlog4abp_cl_context=>get_run_id( ).
        l_event-seq_no       = zlog4abp_cl_context=>next_seq_no( ).
        l_event-context_json = zlog4abp_cl_context=>as_json( ).
        l_event-log_level    = i_level.
        l_event-category     = m_category.
        l_event-uname        = l_info-uname.
        l_event-program_name = l_info-program_name.
        l_event-job_name     = l_info-job_name.
        l_event-job_count    = l_info-job_count.
        l_event-msgid        = i_msgid.
        l_event-msgno        = i_msgno.
        IF i_level >= zlog4abp_if_log=>c_level-warn.
          l_event-source_pos = source_position( ).
        ENDIF.

        dispatch( l_event ).
      CATCH cx_root ##NO_HANDLER.
        " Logging must never break the application.
    ENDTRY.
  ENDMETHOD.


  METHOD set_payload.
    c_event-payload_len = strlen( i_payload ).
    c_event-has_payload = xsdbool( c_event-payload_len > 0 ).
    IF m_max_payload >= 0 AND c_event-payload_len > m_max_payload.
      " A truncated payload is no longer valid JSON; readers check PAYLOAD_TRUNC.
      c_event-payload_json = substring( val = i_payload len = m_max_payload ).
      c_event-payload_trunc = abap_true.
    ELSE.
      c_event-payload_json = i_payload.
      c_event-payload_trunc = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD dispatch.
    LOOP AT m_appenders INTO DATA(appender).
      TRY.
          appender->append( i_event ).
        CATCH cx_root ##NO_HANDLER.
          " A failing appender must not affect the caller or the other appenders.
      ENDTRY.
    ENDLOOP.

    IF i_event-log_level >= zlog4abp_if_log=>c_level-error.
      zlog4abp_if_log~flush( ).
    ENDIF.
  ENDMETHOD.


  METHOD source_position.
    DATA l_stack TYPE abap_callstack.

    CALL FUNCTION 'SYSTEM_CALLSTACK'
      EXPORTING
        max_level = 12
      IMPORTING
        callstack = l_stack.

    LOOP AT l_stack INTO DATA(frame).
      IF frame-mainprogram CP c_own_program.
        CONTINUE.
      ENDIF.
      r_result = |{ frame-include }:{ frame-line } { frame-blockname }|.
      RETURN.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
