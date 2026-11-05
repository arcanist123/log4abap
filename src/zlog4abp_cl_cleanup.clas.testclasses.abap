"! Keeps events in memory instead of the database.
CLASS ltd_cleanup DEFINITION FINAL FOR TESTING INHERITING FROM zlog4abp_cl_cleanup.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_event,
        event_id  TYPE sysuuid_x16,
        log_level TYPE int1,
        event_ts  TYPE timestampl,
      END OF ty_event,
      ty_events TYPE STANDARD TABLE OF ty_event WITH DEFAULT KEY.
    METHODS add_events
      IMPORTING i_level TYPE int1
                i_ts    TYPE timestampl
                i_count TYPE i.
    METHODS get_events RETURNING VALUE(r_result) TYPE ty_events.
    METHODS get_delete_calls RETURNING VALUE(r_result) TYPE i.
    METHODS set_authorized IMPORTING i_authorized TYPE abap_bool.
    METHODS get_checked_activity RETURNING VALUE(r_result) TYPE zlog4abp_cl_reader=>ty_activity.
  PROTECTED SECTION.
    METHODS check_authority REDEFINITION.
    METHODS count_rows REDEFINITION.
    METHODS select_package REDEFINITION.
    METHODS delete_package REDEFINITION.
  PRIVATE SECTION.
    DATA m_events TYPE ty_events.
    DATA m_next_id TYPE i.
    DATA m_delete_calls TYPE i.
    DATA m_authorized TYPE abap_bool VALUE abap_true.
    DATA m_checked_activity TYPE zlog4abp_cl_reader=>ty_activity.
ENDCLASS.

CLASS ltd_cleanup IMPLEMENTATION.
  METHOD add_events.
    DATA l_id TYPE x LENGTH 4.
    DO i_count TIMES.
      m_next_id = m_next_id + 1.
      l_id = m_next_id.
      APPEND VALUE #( event_id = l_id log_level = i_level event_ts = i_ts ) TO m_events.
    ENDDO.
  ENDMETHOD.

  METHOD get_events.
    r_result = m_events.
  ENDMETHOD.

  METHOD get_delete_calls.
    r_result = m_delete_calls.
  ENDMETHOD.

  METHOD set_authorized.
    m_authorized = i_authorized.
  ENDMETHOD.

  METHOD get_checked_activity.
    r_result = m_checked_activity.
  ENDMETHOD.

  METHOD check_authority.
    m_checked_activity = i_activity.
    r_result = m_authorized.
  ENDMETHOD.

  METHOD count_rows.
    LOOP AT m_events TRANSPORTING NO FIELDS WHERE log_level = i_level AND event_ts < i_cutoff.
      r_result = r_result + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD select_package.
    LOOP AT m_events INTO DATA(event) WHERE log_level = i_level AND event_ts < i_cutoff.
      APPEND event-event_id TO r_result.
      IF lines( r_result ) >= i_max.
        EXIT.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD delete_package.
    m_delete_calls = m_delete_calls + 1.
    LOOP AT i_keys INTO DATA(key).
      DELETE m_events WHERE event_id = key.
      r_result = r_result + 1.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_cleanup DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_now TYPE timestampl VALUE '20261105120000.5'.

    METHODS cutoff_same_time_of_day FOR TESTING RAISING cx_static_check cx_sy_open_sql_db.
    METHODS cutoff_across_months FOR TESTING RAISING cx_static_check cx_sy_open_sql_db.
    METHODS retention_per_level FOR TESTING RAISING cx_static_check cx_sy_open_sql_db.
    METHODS test_mode_counts_only FOR TESTING RAISING cx_static_check cx_sy_open_sql_db.
    METHODS deletes_in_packages FOR TESTING RAISING cx_static_check cx_sy_open_sql_db.
    METHODS zero_days_keeps_level FOR TESTING RAISING cx_static_check cx_sy_open_sql_db.
    METHODS not_authorized FOR TESTING RAISING cx_static_check cx_sy_open_sql_db.
ENDCLASS.


CLASS ltc_cleanup IMPLEMENTATION.

  METHOD cutoff_same_time_of_day.
    cl_abap_unit_assert=>assert_equals(
      act = zlog4abp_cl_cleanup=>cutoff( i_now = c_now i_days = 3 )
      exp = CONV timestampl( '20261102120000.5' ) ).
  ENDMETHOD.

  METHOD cutoff_across_months.
    cl_abap_unit_assert=>assert_equals(
      act = zlog4abp_cl_cleanup=>cutoff( i_now = '20260301080910' i_days = 1 )
      exp = CONV timestampl( '20260228080910' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = zlog4abp_cl_cleanup=>cutoff( i_now = '20270105000000' i_days = 180 )
      exp = CONV timestampl( '20260709000000' ) ).
  ENDMETHOD.

  METHOD retention_per_level.
    DATA(l_cut) = NEW ltd_cleanup( ).
    " 10 days old: past DEBUG retention (3), within INFO/WARN (30) and ERROR (180)
    DATA(l_old) = zlog4abp_cl_cleanup=>cutoff( i_now = c_now i_days = 10 ).
    l_cut->add_events( i_level = zlog4abp_if_log=>c_level-trace i_ts = l_old i_count = 1 ).
    l_cut->add_events( i_level = zlog4abp_if_log=>c_level-debug i_ts = l_old i_count = 2 ).
    l_cut->add_events( i_level = zlog4abp_if_log=>c_level-info i_ts = l_old i_count = 1 ).
    l_cut->add_events( i_level = zlog4abp_if_log=>c_level-error i_ts = l_old i_count = 1 ).
    " Recent DEBUG event stays
    l_cut->add_events( i_level = zlog4abp_if_log=>c_level-debug i_ts = c_now i_count = 1 ).

    DATA(l_counts) = l_cut->run( i_retention = zlog4abp_cl_cleanup=>c_default_retention i_now = c_now ).

    cl_abap_unit_assert=>assert_equals( act = lines( l_counts ) exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = l_counts[ 1 ]-rows exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = l_counts[ 2 ]-rows exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_counts[ 2 ]-days exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = l_counts[ 3 ]-rows exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = l_counts[ 4 ]-days exp = 30 ).
    cl_abap_unit_assert=>assert_equals( act = l_counts[ 5 ]-rows exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = l_counts[ 5 ]-days exp = 180 ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_events( ) ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_checked_activity( ) exp = '06' ).
  ENDMETHOD.

  METHOD test_mode_counts_only.
    DATA(l_cut) = NEW ltd_cleanup( ).
    l_cut->add_events( i_level = zlog4abp_if_log=>c_level-debug
                       i_ts    = zlog4abp_cl_cleanup=>cutoff( i_now = c_now i_days = 5 )
                       i_count = 4 ).

    DATA(l_counts) = l_cut->run( i_retention = zlog4abp_cl_cleanup=>c_default_retention
                                 i_now       = c_now
                                 i_test      = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = l_counts[ 2 ]-rows exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_events( ) ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_delete_calls( ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_checked_activity( ) exp = '03' ).
  ENDMETHOD.

  METHOD deletes_in_packages.
    DATA(l_cut) = NEW ltd_cleanup( i_package_size = 2 ).
    l_cut->add_events( i_level = zlog4abp_if_log=>c_level-error
                       i_ts    = zlog4abp_cl_cleanup=>cutoff( i_now = c_now i_days = 200 )
                       i_count = 5 ).

    DATA(l_counts) = l_cut->run( i_retention = zlog4abp_cl_cleanup=>c_default_retention i_now = c_now ).

    cl_abap_unit_assert=>assert_equals( act = l_counts[ 5 ]-rows exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_delete_calls( ) exp = 3 ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_events( ) ).
  ENDMETHOD.

  METHOD zero_days_keeps_level.
    DATA(l_cut) = NEW ltd_cleanup( ).
    l_cut->add_events( i_level = zlog4abp_if_log=>c_level-error
                       i_ts    = zlog4abp_cl_cleanup=>cutoff( i_now = c_now i_days = 1000 )
                       i_count = 1 ).

    DATA(l_counts) = l_cut->run( i_retention = VALUE #( trace_debug = 3 info_warn = 30 error = 0 ) i_now = c_now ).

    cl_abap_unit_assert=>assert_equals( act = l_counts[ 5 ]-rows exp = 0 ).
    cl_abap_unit_assert=>assert_initial( l_counts[ 5 ]-cutoff ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_events( ) ) exp = 1 ).
  ENDMETHOD.

  METHOD not_authorized.
    DATA(l_cut) = NEW ltd_cleanup( ).
    l_cut->set_authorized( abap_false ).
    TRY.
        l_cut->run( i_retention = zlog4abp_cl_cleanup=>c_default_retention ).
        cl_abap_unit_assert=>fail( 'Exception expected' ).
      CATCH zlog4abp_cx_not_authorized INTO DATA(l_error).
        cl_abap_unit_assert=>assert_equals( act = l_error->get_activity( ) exp = '06' ).
      CATCH cx_sy_open_sql_db.
        cl_abap_unit_assert=>fail( 'No database access expected' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
