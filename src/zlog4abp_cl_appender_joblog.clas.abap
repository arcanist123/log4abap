"! <p class="shorttext synchronized">log4abap: appender for the job log</p>
"! Writes events to the job log of background runs. Configuration name: JOBLOG.
"! <ul>
"! <li>Only active when SY-BATCH is set; in dialog runs events are ignored.</li>
"! <li>Before the first event of a run, the line "log4abap run ID ..." is
"! written, so a job log reader can find the run's events in ZLOG4ABP_EVENT.</li>
"! <li>Each event becomes one status message "LEVEL CATEGORY: message", cut to
"! C_MAX_TEXT characters. Type S is used for every level, because an E or A
"! message would end the job.</li>
"! <li>SY-MSGID, SY-MSGTY, SY-MSGNO and SY-MSGV1 to SY-MSGV4 are restored after
"! each message, so the caller's message fields survive logging.</li>
"! </ul>
"! Messages go to the job log at once; FLUSH( ) has nothing to do.
CLASS zlog4abp_cl_appender_joblog DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zlog4abp_if_appender.

    "! Characters per job log message (four message variables of 50 characters)
    CONSTANTS c_max_text TYPE i VALUE 200.

  PROTECTED SECTION.
    "! True in background runs. Unit tests redefine the methods of this section.
    "! @parameter r_result | SY-BATCH is set
    METHODS is_batch
      RETURNING VALUE(r_result) TYPE abap_bool.

    "! Write one message to the job log
    "! @parameter i_text | Text of at most C_MAX_TEXT characters
    METHODS write_message
      IMPORTING i_text TYPE string.

  PRIVATE SECTION.
    DATA m_run_id TYPE sysuuid_x16.
    DATA m_run_written TYPE abap_bool.

ENDCLASS.



CLASS zlog4abp_cl_appender_joblog IMPLEMENTATION.


  METHOD zlog4abp_if_appender~append.
    IF i_event-log_level >= zlog4abp_if_log=>c_level-off OR is_batch( ) = abap_false.
      RETURN.
    ENDIF.

    IF m_run_written = abap_false OR i_event-run_id <> m_run_id.
      write_message( |log4abap run ID { i_event-run_id }| ).
      m_run_id = i_event-run_id.
      m_run_written = abap_true.
    ENDIF.

    write_message( zlog4abp_cl_formatter=>shorten(
      i_text       = |{ zlog4abp_cl_formatter=>level_name( i_event-log_level ) } { i_event-category }: {
                       i_event-msg_text }|
      i_max_length = c_max_text ) ).
  ENDMETHOD.


  METHOD zlog4abp_if_appender~flush.
    " Job log messages are written immediately.
    RETURN.
  ENDMETHOD.


  METHOD is_batch.
    r_result = xsdbool( sy-batch = abap_true ).
  ENDMETHOD.


  METHOD write_message.
    DATA l_text TYPE c LENGTH c_max_text.

    DATA(l_msgid) = sy-msgid.
    DATA(l_msgty) = sy-msgty.
    DATA(l_msgno) = sy-msgno.
    DATA(l_msgv1) = sy-msgv1.
    DATA(l_msgv2) = sy-msgv2.
    DATA(l_msgv3) = sy-msgv3.
    DATA(l_msgv4) = sy-msgv4.

    l_text = i_text.
    MESSAGE l_text TYPE 'S'.

    sy-msgid = l_msgid.
    sy-msgty = l_msgty.
    sy-msgno = l_msgno.
    sy-msgv1 = l_msgv1.
    sy-msgv2 = l_msgv2.
    sy-msgv3 = l_msgv3.
    sy-msgv4 = l_msgv4.
  ENDMETHOD.

ENDCLASS.
