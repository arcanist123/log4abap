"! Records writes instead of touching the database; can be told to fail.
CLASS ltd_appender DEFINITION FINAL FOR TESTING INHERITING FROM zlog4abp_cl_appender_event.
  PUBLIC SECTION.
    TYPES ty_writes TYPE STANDARD TABLE OF ty_rows WITH DEFAULT KEY.
    METHODS get_writes RETURNING VALUE(r_result) TYPE ty_writes.
    METHODS set_fail IMPORTING i_fail TYPE abap_bool.
  PROTECTED SECTION.
    METHODS write REDEFINITION.
    METHODS rollback REDEFINITION.
  PRIVATE SECTION.
    DATA m_writes TYPE ty_writes.
    DATA m_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_appender IMPLEMENTATION.
  METHOD write.
    IF m_fail = abap_true.
      RAISE EXCEPTION TYPE cx_sy_open_sql_db.
    ENDIF.
    APPEND i_rows TO m_writes.
  ENDMETHOD.

  METHOD rollback.
    " Nothing to undo: WRITE( ) did not touch the database.
    RETURN.
  ENDMETHOD.

  METHOD get_writes.
    r_result = m_writes.
  ENDMETHOD.

  METHOD set_fail.
    m_fail = i_fail.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_event DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS buffers_until_size_reached FOR TESTING.
    METHODS flush_writes_buffer_once FOR TESTING.
    METHODS flush_with_empty_buffer FOR TESTING.
    METHODS maps_event_to_row FOR TESTING.
    METHODS truncates_long_message FOR TESTING.
    METHODS failed_write_drops_and_counts FOR TESTING.
    METHODS logger_error_flushes FOR TESTING.
    METHODS factory_creates_by_name FOR TESTING.
ENDCLASS.


CLASS ltc_event IMPLEMENTATION.

  METHOD buffers_until_size_reached.
    DATA(l_cut) = NEW ltd_appender( i_buffer_size = 3 ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( VALUE #( seq_no = 1 ) ).
    l_appender->append( VALUE #( seq_no = 2 ) ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_writes( ) ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_buffered_count( ) exp = 2 ).

    l_appender->append( VALUE #( seq_no = 3 ) ).
    DATA(l_writes) = l_cut->get_writes( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_writes ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_writes[ 1 ] ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_buffered_count( ) exp = 0 ).
  ENDMETHOD.

  METHOD flush_writes_buffer_once.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( VALUE #( seq_no = 1 ) ).
    l_appender->flush( ).
    l_appender->flush( ).

    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_writes( ) ) exp = 1 ).
  ENDMETHOD.

  METHOD flush_with_empty_buffer.
    DATA(l_cut) = NEW ltd_appender( ).

    CAST zlog4abp_if_appender( l_cut )->flush( ).

    cl_abap_unit_assert=>assert_initial( l_cut->get_writes( ) ).
  ENDMETHOD.

  METHOD maps_event_to_row.
    DATA(l_cut) = NEW ltd_appender( i_buffer_size = 1 ).

    CAST zlog4abp_if_appender( l_cut )->append( VALUE #( seq_no       = 7
                                                         log_level    = zlog4abp_if_log=>c_level-warn
                                                         category     = 'ZSD.IMPORT'
                                                         msg_text     = `Price missing`
                                                         has_payload  = abap_true
                                                         payload_len  = 2
                                                         payload_json = `{}` ) ).

    DATA(l_writes) = l_cut->get_writes( ).
    DATA(l_row) = l_writes[ 1 ][ 1 ].
    cl_abap_unit_assert=>assert_equals( act = l_row-mandt exp = sy-mandt ).
    cl_abap_unit_assert=>assert_equals( act = l_row-seq_no exp = 7 ).
    cl_abap_unit_assert=>assert_equals( act = l_row-category exp = 'ZSD.IMPORT' ).
    cl_abap_unit_assert=>assert_equals( act = l_row-msg_text exp = `Price missing` ).
    cl_abap_unit_assert=>assert_equals( act = l_row-payload_json exp = `{}` ).
  ENDMETHOD.

  METHOD truncates_long_message.
    DATA(l_cut) = NEW ltd_appender( i_buffer_size = 1 ).
    DATA(l_long) = repeat( val = `x` occ = zlog4abp_cl_appender_event=>c_max_msg_text + 10 ).

    CAST zlog4abp_if_appender( l_cut )->append( VALUE #( msg_text = l_long ) ).

    DATA(l_writes) = l_cut->get_writes( ).
    cl_abap_unit_assert=>assert_equals( act = strlen( l_writes[ 1 ][ 1 ]-msg_text )
                                        exp = zlog4abp_cl_appender_event=>c_max_msg_text ).
  ENDMETHOD.

  METHOD failed_write_drops_and_counts.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).
    l_cut->set_fail( abap_true ).

    l_appender->append( VALUE #( seq_no = 1 ) ).
    l_appender->append( VALUE #( seq_no = 2 ) ).
    l_appender->flush( ).

    cl_abap_unit_assert=>assert_equals( act = l_cut->get_dropped_count( ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_buffered_count( ) exp = 0 ).

    " The appender keeps working once writes succeed again.
    l_cut->set_fail( abap_false ).
    l_appender->append( VALUE #( seq_no = 3 ) ).
    l_appender->flush( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_writes( ) ) exp = 1 ).
  ENDMETHOD.

  METHOD logger_error_flushes.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_log) = CAST zlog4abp_if_log( NEW zlog4abp_cl_logger(
      i_category  = 'ZTEST'
      i_threshold = zlog4abp_if_log=>c_level-info
      i_appenders = VALUE #( ( l_cut ) ) ) ).

    l_log->info( 'buffered' ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_writes( ) ).

    l_log->error( 'written' ).
    DATA(l_writes) = l_cut->get_writes( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_writes[ 1 ] ) exp = 2 ).
  ENDMETHOD.

  METHOD factory_creates_by_name.
    DATA(l_appender) = zlog4abp_cl_factory=>get_appender( 'EVENT' ).

    cl_abap_unit_assert=>assert_true( xsdbool( l_appender IS INSTANCE OF zlog4abp_cl_appender_event ) ).
  ENDMETHOD.

ENDCLASS.
