"! <p class="shorttext synchronized">log4abap: appender for table ZLOG4ABP_EVENT</p>
"! Stores complete events, including the JSON payload, in ZLOG4ABP_EVENT.
"! Configuration name: EVENT.
"! <br/>Events are buffered. The buffer is written when it reaches the buffer
"! size (default 50) and on FLUSH( ). Loggers flush their appenders after every
"! ERROR event, and ZLOG4ABP_CL_FACTORY=&gt;FLUSH_ALL( ) flushes all of them.
"! <br/>Rows are written and committed through service connection
"! R/3*ZLOG4ABP. The caller's LUW is never committed or rolled back, and a
"! ROLLBACK WORK of the caller does not remove events that were written.
"! If a write fails, the buffered events are dropped and counted, so a broken
"! database connection never lets the buffer grow without limit.
CLASS zlog4abp_cl_appender_event DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zlog4abp_if_appender.

    TYPES ty_rows TYPE STANDARD TABLE OF zlog4abp_event WITH DEFAULT KEY.

    "! Service connection for all writes to ZLOG4ABP_EVENT
    CONSTANTS c_connection TYPE dbcon_name VALUE 'R/3*ZLOG4ABP'.
    "! Default number of events buffered before they are written
    CONSTANTS c_default_buffer_size TYPE i VALUE 50.
    "! Length of column MSG_TEXT; longer messages are truncated
    CONSTANTS c_max_msg_text TYPE i VALUE 1333.

    "! @parameter i_buffer_size | Events buffered before a write; 1 or less writes every event
    METHODS constructor
      IMPORTING i_buffer_size TYPE i DEFAULT c_default_buffer_size.

    "! Change the buffer size. Takes effect with the next event.
    "! @parameter i_buffer_size | Events buffered before a write
    METHODS set_buffer_size
      IMPORTING i_buffer_size TYPE i.

    "! Number of events waiting to be written
    "! @parameter r_result | Count
    METHODS get_buffered_count
      RETURNING VALUE(r_result) TYPE i.

    "! Number of events dropped because a write failed
    "! @parameter r_result | Count
    METHODS get_dropped_count
      RETURNING VALUE(r_result) TYPE i.

  PROTECTED SECTION.
    "! Insert the rows and commit the service connection. Unit tests redefine
    "! this method so they do not touch the database. Rows with a duplicate
    "! EVENT_ID are skipped and counted as dropped.
    "! @parameter i_rows | Rows to insert
    "! @raising cx_sy_open_sql_db | Database error; FLUSH( ) drops the rows
    METHODS write
      IMPORTING i_rows TYPE ty_rows
      RAISING   cx_sy_open_sql_db.

    "! Roll back the service connection after a failed write. Unit tests
    "! redefine this method too.
    "! @raising cx_sy_open_sql_db | Database error; ignored by the caller
    METHODS rollback
      RAISING cx_sy_open_sql_db.

  PRIVATE SECTION.
    DATA m_buffer TYPE ty_rows.
    DATA m_buffer_size TYPE i.
    DATA m_dropped_count TYPE i.

    "! Count lost events and undo whatever the failed write left open
    "! @parameter i_count | Number of events lost
    METHODS drop
      IMPORTING i_count TYPE i.

ENDCLASS.



CLASS zlog4abp_cl_appender_event IMPLEMENTATION.


  METHOD constructor.
    set_buffer_size( i_buffer_size ).
  ENDMETHOD.


  METHOD set_buffer_size.
    m_buffer_size = nmax( val1 = i_buffer_size val2 = 1 ).
  ENDMETHOD.


  METHOD get_buffered_count.
    r_result = lines( m_buffer ).
  ENDMETHOD.


  METHOD get_dropped_count.
    r_result = m_dropped_count.
  ENDMETHOD.


  METHOD zlog4abp_if_appender~append.
    DATA l_row TYPE zlog4abp_event.

    MOVE-CORRESPONDING i_event TO l_row.
    l_row-mandt = sy-mandt.
    IF strlen( i_event-msg_text ) > c_max_msg_text.
      l_row-msg_text = substring( val = i_event-msg_text len = c_max_msg_text ).
    ENDIF.
    APPEND l_row TO m_buffer.

    IF lines( m_buffer ) >= m_buffer_size.
      zlog4abp_if_appender~flush( ).
    ENDIF.
  ENDMETHOD.


  METHOD zlog4abp_if_appender~flush.
    IF m_buffer IS INITIAL.
      RETURN.
    ENDIF.

    " The buffer is cleared in every case: a failed write must not be retried
    " with an ever-growing buffer.
    DATA(l_rows) = m_buffer.
    CLEAR m_buffer.

    TRY.
        write( l_rows ).
      CATCH cx_sy_open_sql_db.
        drop( lines( l_rows ) ).
      CATCH cx_root.
        drop( lines( l_rows ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD drop.
    " Never log through the framework from here; count the loss instead.
    m_dropped_count = m_dropped_count + i_count.
    TRY.
        rollback( ).
      CATCH cx_sy_open_sql_db ##NO_HANDLER.
        " The connection may not be open at all.
      CATCH cx_root ##NO_HANDLER.
        " Same: nothing left to undo.
    ENDTRY.
  ENDMETHOD.


  METHOD rollback.
    ROLLBACK CONNECTION (c_connection).
  ENDMETHOD.


  METHOD write.
    " ACCEPTING DUPLICATE KEYS: a repeated EVENT_ID must not cost the other rows.
    INSERT zlog4abp_event CONNECTION (c_connection) FROM TABLE @i_rows ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0.
      m_dropped_count = m_dropped_count + lines( i_rows ) - sy-dbcnt.
    ENDIF.
    COMMIT CONNECTION (c_connection).
  ENDMETHOD.

ENDCLASS.
