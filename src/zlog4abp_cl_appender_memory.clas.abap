"! <p class="shorttext synchronized">log4abap: in-memory appender for unit tests</p>
"! Keeps events in an internal table. Configuration name: MEMORY.
CLASS zlog4abp_cl_appender_memory DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zlog4abp_if_appender.

    "! Events received so far
    "! @parameter r_result | Events in arrival order
    METHODS get_events
      RETURNING VALUE(r_result) TYPE zlog4abp_if_appender=>ty_events.

    "! Number of events received so far
    "! @parameter r_result | Count
    METHODS get_count
      RETURNING VALUE(r_result) TYPE i.

    "! Number of FLUSH calls received so far
    "! @parameter r_result | Count
    METHODS get_flush_count
      RETURNING VALUE(r_result) TYPE i.

    "! Forget all events and reset the flush count
    METHODS clear.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA m_events TYPE zlog4abp_if_appender=>ty_events.
    DATA m_flush_count TYPE i.

ENDCLASS.



CLASS zlog4abp_cl_appender_memory IMPLEMENTATION.


  METHOD zlog4abp_if_appender~append.
    APPEND i_event TO m_events.
  ENDMETHOD.


  METHOD zlog4abp_if_appender~flush.
    m_flush_count = m_flush_count + 1.
  ENDMETHOD.


  METHOD get_events.
    r_result = m_events.
  ENDMETHOD.


  METHOD get_count.
    r_result = lines( m_events ).
  ENDMETHOD.


  METHOD get_flush_count.
    r_result = m_flush_count.
  ENDMETHOD.


  METHOD clear.
    CLEAR: m_events, m_flush_count.
  ENDMETHOD.

ENDCLASS.
