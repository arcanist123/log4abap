"! Records job log messages instead of writing them; batch mode is switchable.
CLASS ltd_appender DEFINITION FINAL FOR TESTING INHERITING FROM zlog4abp_cl_appender_joblog.
  PUBLIC SECTION.
    METHODS get_messages RETURNING VALUE(r_result) TYPE string_table.
    METHODS get_message IMPORTING i_index TYPE i RETURNING VALUE(r_result) TYPE string.
    METHODS set_batch IMPORTING i_batch TYPE abap_bool.
    "! Pass messages on to the real MESSAGE statement as well
    METHODS set_write_through IMPORTING i_write_through TYPE abap_bool.
  PROTECTED SECTION.
    METHODS is_batch REDEFINITION.
    METHODS write_message REDEFINITION.
  PRIVATE SECTION.
    DATA m_messages TYPE string_table.
    DATA m_batch TYPE abap_bool VALUE abap_true.
    DATA m_write_through TYPE abap_bool.
ENDCLASS.

CLASS ltd_appender IMPLEMENTATION.
  METHOD is_batch.
    r_result = m_batch.
  ENDMETHOD.

  METHOD write_message.
    APPEND i_text TO m_messages.
    IF m_write_through = abap_true.
      super->write_message( i_text ).
    ENDIF.
  ENDMETHOD.

  METHOD get_messages.
    r_result = m_messages.
  ENDMETHOD.

  METHOD get_message.
    r_result = m_messages[ i_index ].
  ENDMETHOD.

  METHOD set_batch.
    m_batch = i_batch.
  ENDMETHOD.

  METHOD set_write_through.
    m_write_through = i_write_through.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_joblog DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_run1 TYPE sysuuid_x16 VALUE '0102030405060708090A0B0C0D0E0F10'.
    CONSTANTS c_run2 TYPE sysuuid_x16 VALUE '1112131415161718191A1B1C1D1E1F20'.

    METHODS dialog_ignored FOR TESTING.
    METHODS run_id_written_once FOR TESTING.
    METHODS new_run_id_written_again FOR TESTING.
    METHODS long_text_shortened FOR TESTING.
    METHODS message_fields_restored FOR TESTING.
    METHODS factory_creates_by_name FOR TESTING.
ENDCLASS.


CLASS ltc_joblog IMPLEMENTATION.

  METHOD dialog_ignored.
    DATA(l_cut) = NEW ltd_appender( ).
    l_cut->set_batch( abap_false ).

    CAST zlog4abp_if_appender( l_cut )->append( VALUE #( run_id = c_run1 log_level = zlog4abp_if_log=>c_level-error ) ).

    cl_abap_unit_assert=>assert_initial( l_cut->get_messages( ) ).
  ENDMETHOD.

  METHOD run_id_written_once.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( VALUE #( run_id    = c_run1
                                 log_level = zlog4abp_if_log=>c_level-warn
                                 category  = 'ZSD.IMPORT'
                                 msg_text  = `Price missing` ) ).
    l_appender->append( VALUE #( run_id    = c_run1
                                 log_level = zlog4abp_if_log=>c_level-debug
                                 category  = 'ZSD.IMPORT'
                                 msg_text  = `Details` ) ).

    cl_abap_unit_assert=>assert_equals( act = l_cut->get_messages( )
                                        exp = VALUE string_table(
                                          ( `log4abap run ID 0102030405060708090A0B0C0D0E0F10` )
                                          ( `WARN ZSD.IMPORT: Price missing` )
                                          ( `DEBUG ZSD.IMPORT: Details` ) ) ).
  ENDMETHOD.

  METHOD new_run_id_written_again.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( VALUE #( run_id = c_run1 log_level = zlog4abp_if_log=>c_level-info ) ).
    l_appender->append( VALUE #( run_id = c_run2 log_level = zlog4abp_if_log=>c_level-info ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_messages( ) ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_message( 3 )
                                        exp = `log4abap run ID 1112131415161718191A1B1C1D1E1F20` ).
  ENDMETHOD.

  METHOD long_text_shortened.
    DATA(l_cut) = NEW ltd_appender( ).

    CAST zlog4abp_if_appender( l_cut )->append( VALUE #( run_id    = c_run1
                                                         log_level = zlog4abp_if_log=>c_level-error
                                                         category  = 'ZSD.IMPORT'
                                                         msg_text  = repeat( val = `x` occ = 500 ) ) ).

    DATA(l_text) = l_cut->get_message( 2 ).
    cl_abap_unit_assert=>assert_equals( act = strlen( l_text ) exp = zlog4abp_cl_appender_joblog=>c_max_text ).
    cl_abap_unit_assert=>assert_equals( act = substring( val = l_text len = 18 ) exp = `ERROR ZSD.IMPORT: ` ).
    cl_abap_unit_assert=>assert_equals( act = substring( val = l_text off = strlen( l_text ) - 3 ) exp = `...` ).
  ENDMETHOD.

  METHOD message_fields_restored.
    DATA(l_cut) = NEW ltd_appender( ).
    l_cut->set_write_through( abap_true ).
    MESSAGE ID '00' TYPE 'I' NUMBER '001' WITH 'caller' INTO DATA(l_dummy) ##NEEDED.

    CAST zlog4abp_if_appender( l_cut )->append( VALUE #( run_id = c_run1 log_level = zlog4abp_if_log=>c_level-info ) ).

    cl_abap_unit_assert=>assert_equals( act = sy-msgid exp = '00' ).
    cl_abap_unit_assert=>assert_equals( act = sy-msgty exp = 'I' ).
    cl_abap_unit_assert=>assert_equals( act = sy-msgno exp = '001' ).
    cl_abap_unit_assert=>assert_equals( act = sy-msgv1 exp = 'caller' ).
  ENDMETHOD.

  METHOD factory_creates_by_name.
    DATA(l_appender) = zlog4abp_cl_factory=>get_appender( 'JOBLOG' ).

    cl_abap_unit_assert=>assert_true( xsdbool( l_appender IS INSTANCE OF zlog4abp_cl_appender_joblog ) ).
  ENDMETHOD.

ENDCLASS.
