"! <p class="shorttext synchronized">log4abap: retention for table ZLOG4ABP_EVENT</p>
"! Deletes events older than their level's retention period.
"! <ul>
"! <li>Default retention: TRACE and DEBUG 3 days, INFO and WARN 30 days, ERROR 180 days.</li>
"! <li>A retention of 0 days or less keeps the events of that level.</li>
"! <li>Rows are deleted in packages; each package is deleted and committed on
"!     service connection R/3*ZLOG4ABP, so the caller's LUW is not touched.
"!     Rows are selected on the default connection, which sees the
"!     committed deletions.</li>
"! <li>Deleting needs authorization object ZLOG4ABP_R with activity 06;
"!     test mode (count only) needs activity 03.</li>
"! </ul>
"! Application logs are not deleted here: the BAL appender sets their expiry
"! date, and SLG2 (report SBAL_DELETE) deletes expired logs of object ZLOG4ABP.
CLASS zlog4abp_cl_cleanup DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_retention,
        "! Days for TRACE and DEBUG
        trace_debug TYPE i,
        "! Days for INFO and WARN
        info_warn   TYPE i,
        "! Days for ERROR
        error       TYPE i,
      END OF ty_retention.
    TYPES:
      BEGIN OF ty_count,
        level  TYPE int1,
        days   TYPE i,
        cutoff TYPE timestampl,
        "! Rows deleted, or in test mode the rows that would be deleted
        rows   TYPE i,
      END OF ty_count,
      ty_counts TYPE STANDARD TABLE OF ty_count WITH DEFAULT KEY.
    TYPES ty_keys TYPE STANDARD TABLE OF sysuuid_x16 WITH DEFAULT KEY.

    CONSTANTS:
      BEGIN OF c_default_retention,
        trace_debug TYPE i VALUE 3,
        info_warn   TYPE i VALUE 30,
        error       TYPE i VALUE 180,
      END OF c_default_retention.
    CONSTANTS c_default_package_size TYPE i VALUE 1000.
    CONSTANTS c_connection TYPE dbcon_name VALUE zlog4abp_cl_appender_event=>c_connection.

    "! Time stamp I_DAYS calendar days before I_NOW, at the same time of day
    "! @parameter i_now | UTC time stamp
    "! @parameter i_days | Days
    "! @parameter r_result | UTC time stamp
    CLASS-METHODS cutoff
      IMPORTING i_now           TYPE timestampl
                i_days          TYPE i
      RETURNING VALUE(r_result) TYPE timestampl.

    "! @parameter i_package_size | Rows deleted and committed together
    METHODS constructor
      IMPORTING i_package_size TYPE i DEFAULT c_default_package_size.

    "! Delete expired events, or count them in test mode
    "! @parameter i_retention | Retention in days per level group
    "! @parameter i_now | Reference time (UTC); current time if initial
    "! @parameter i_test | Test mode: count only, delete nothing
    "! @parameter r_result | One line per level: retention, cutoff and rows
    "! @raising zlog4abp_cx_not_authorized | No authorization for activity 06 (03 in test mode)
    "! @raising cx_sy_open_sql_db | Database error; packages committed before it stay deleted
    METHODS run
      IMPORTING i_retention     TYPE ty_retention
                i_now           TYPE timestampl OPTIONAL
                i_test          TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(r_result) TYPE ty_counts
      RAISING   zlog4abp_cx_not_authorized
                cx_sy_open_sql_db.

  PROTECTED SECTION.
    "! Authorization check. Unit tests redefine this method.
    "! @parameter i_activity | Activity
    "! @parameter r_result | Authorized
    METHODS check_authority
      IMPORTING i_activity      TYPE zlog4abp_cl_reader=>ty_activity
      RETURNING VALUE(r_result) TYPE abap_bool.

    "! Count the events of a level before the cutoff. Unit tests redefine this method.
    "! @parameter i_level | Level
    "! @parameter i_cutoff | Events before this time stamp
    "! @parameter r_result | Count
    "! @raising cx_sy_open_sql_db | Database error
    METHODS count_rows
      IMPORTING i_level         TYPE int1
                i_cutoff        TYPE timestampl
      RETURNING VALUE(r_result) TYPE i
      RAISING   cx_sy_open_sql_db.

    "! Event IDs of one package. Unit tests redefine this method.
    "! @parameter i_level | Level
    "! @parameter i_cutoff | Events before this time stamp
    "! @parameter i_max | Package size
    "! @parameter r_result | Event IDs
    "! @raising cx_sy_open_sql_db | Database error
    METHODS select_package
      IMPORTING i_level         TYPE int1
                i_cutoff        TYPE timestampl
                i_max           TYPE i
      RETURNING VALUE(r_result) TYPE ty_keys
      RAISING   cx_sy_open_sql_db.

    "! Delete the events and commit the service connection. Unit tests redefine this method.
    "! @parameter i_keys | Event IDs
    "! @parameter r_result | Rows deleted
    "! @raising cx_sy_open_sql_db | Database error
    METHODS delete_package
      IMPORTING i_keys          TYPE ty_keys
      RETURNING VALUE(r_result) TYPE i
      RAISING   cx_sy_open_sql_db.

  PRIVATE SECTION.
    DATA m_package_size TYPE i.

    METHODS days_for_level
      IMPORTING i_retention     TYPE ty_retention
                i_level         TYPE int1
      RETURNING VALUE(r_result) TYPE i.

    METHODS delete_level
      IMPORTING i_level         TYPE int1
                i_cutoff        TYPE timestampl
      RETURNING VALUE(r_result) TYPE i
      RAISING   cx_sy_open_sql_db.

ENDCLASS.



CLASS zlog4abp_cl_cleanup IMPLEMENTATION.


  METHOD cutoff.
    DATA l_day TYPE p LENGTH 8 DECIMALS 0.
    DATA l_day_digits TYPE n LENGTH 8.
    DATA l_date TYPE d.

    " A time stamp is YYYYMMDDhhmmss.fffffff: move the date part only.
    l_day = floor( i_now / 1000000 ).
    l_day_digits = l_day.
    l_date = l_day_digits.
    l_date = l_date - i_days.
    l_day_digits = l_date.
    r_result = i_now - l_day * 1000000 + CONV timestampl( l_day_digits ) * 1000000.
  ENDMETHOD.


  METHOD constructor.
    m_package_size = nmax( val1 = i_package_size val2 = 1 ).
  ENDMETHOD.


  METHOD run.
    DATA l_now TYPE timestampl.
    DATA l_level TYPE int1.

    DATA(l_activity) = COND zlog4abp_cl_reader=>ty_activity(
      WHEN i_test = abap_true THEN zlog4abp_cl_reader=>c_activity-read
      ELSE zlog4abp_cl_reader=>c_activity-delete ).
    IF check_authority( l_activity ) = abap_false.
      RAISE EXCEPTION TYPE zlog4abp_cx_not_authorized
        EXPORTING
          i_activity = l_activity.
    ENDIF.

    l_now = i_now.
    IF l_now IS INITIAL.
      GET TIME STAMP FIELD l_now.
    ENDIF.

    DO zlog4abp_if_log=>c_level-error TIMES.
      l_level = sy-index.
      DATA(l_count) = VALUE ty_count( level = l_level days = days_for_level( i_retention = i_retention
                                                                             i_level     = l_level ) ).
      IF l_count-days > 0.
        l_count-cutoff = cutoff( i_now = l_now i_days = l_count-days ).
        IF i_test = abap_true.
          l_count-rows = count_rows( i_level = l_level i_cutoff = l_count-cutoff ).
        ELSE.
          l_count-rows = delete_level( i_level = l_level i_cutoff = l_count-cutoff ).
        ENDIF.
      ENDIF.
      APPEND l_count TO r_result.
    ENDDO.
  ENDMETHOD.


  METHOD days_for_level.
    CASE i_level.
      WHEN zlog4abp_if_log=>c_level-trace OR zlog4abp_if_log=>c_level-debug.
        r_result = i_retention-trace_debug.
      WHEN zlog4abp_if_log=>c_level-info OR zlog4abp_if_log=>c_level-warn.
        r_result = i_retention-info_warn.
      WHEN zlog4abp_if_log=>c_level-error.
        r_result = i_retention-error.
    ENDCASE.
  ENDMETHOD.


  METHOD delete_level.
    DO.
      DATA(l_keys) = select_package( i_level = i_level i_cutoff = i_cutoff i_max = m_package_size ).
      IF l_keys IS INITIAL.
        EXIT.
      ENDIF.
      DATA(l_deleted) = delete_package( l_keys ).
      r_result = r_result + l_deleted.
      " Stop if nothing could be deleted, or the same rows would be selected forever.
      IF l_deleted = 0 OR lines( l_keys ) < m_package_size.
        EXIT.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD check_authority.
    r_result = zlog4abp_cl_reader=>is_authorized( i_activity ).
  ENDMETHOD.


  METHOD count_rows.
    SELECT COUNT(*)
      FROM zlog4abp_event
      WHERE log_level = @i_level
        AND event_ts  < @i_cutoff
      INTO @r_result.                                     "#EC CI_SUBRC
  ENDMETHOD.


  METHOD select_package.
    SELECT event_id
      FROM zlog4abp_event
      WHERE log_level = @i_level
        AND event_ts  < @i_cutoff
      INTO TABLE @r_result
      UP TO @i_max ROWS.                                  "#EC CI_SUBRC
  ENDMETHOD.


  METHOD delete_package.
    DATA l_rows TYPE STANDARD TABLE OF zlog4abp_event WITH DEFAULT KEY.

    l_rows = VALUE #( FOR key IN i_keys ( mandt = sy-mandt event_id = key ) ).
    DELETE zlog4abp_event CONNECTION (c_connection) FROM TABLE @l_rows. "#EC CI_SUBRC
    r_result = sy-dbcnt.
    COMMIT CONNECTION (c_connection).
  ENDMETHOD.

ENDCLASS.
