"! <p class="shorttext synchronized">log4abap: no authorization for the event store</p>
"! Raised by ZLOG4ABP_CL_READER and ZLOG4ABP_CL_CLEANUP when the user lacks
"! authorization object ZLOG4ABP_R for the activity concerned.
CLASS zlog4abp_cx_not_authorized DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_activity TYPE c LENGTH 2.

    "! Authorization object for reading (03) and deleting (06) events
    CONSTANTS c_auth_object TYPE c LENGTH 10 VALUE 'ZLOG4ABP_R'.

    "! @parameter textid | Text ID (not used; the text comes from GET_TEXT( ))
    "! @parameter previous | Previous exception
    "! @parameter i_activity | Activity that was checked, e.g. 03
    METHODS constructor
      IMPORTING textid     LIKE textid OPTIONAL
                previous   LIKE previous OPTIONAL
                i_activity TYPE ty_activity OPTIONAL.

    METHODS get_text REDEFINITION.

    "! Activity that was checked
    "! @parameter r_result | Activity, e.g. 03 (display) or 06 (delete)
    METHODS get_activity
      RETURNING VALUE(r_result) TYPE ty_activity.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA m_activity TYPE ty_activity.

ENDCLASS.



CLASS zlog4abp_cx_not_authorized IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid = textid previous = previous ).
    m_activity = i_activity.
  ENDMETHOD.


  METHOD get_text.
    result = |No authorization for object { c_auth_object }, activity { m_activity }|.
  ENDMETHOD.


  METHOD get_activity.
    r_result = m_activity.
  ENDMETHOD.

ENDCLASS.
