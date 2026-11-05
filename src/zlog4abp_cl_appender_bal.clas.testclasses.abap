"! Records application log calls instead of making them; can be told to fail.
CLASS ltd_appender DEFINITION FINAL FOR TESTING INHERITING FROM zlog4abp_cl_appender_bal.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_create,
        run_id  TYPE sysuuid_x16,
        program TYPE progname,
      END OF ty_create,
      ty_creates TYPE STANDARD TABLE OF ty_create WITH DEFAULT KEY,
      BEGIN OF ty_text,
        handle    TYPE balloghndl,
        msgty     TYPE symsgty,
        probclass TYPE balprobcl,
        detlevel  TYPE ballevel,
        text      TYPE string,
      END OF ty_text,
      ty_texts TYPE STANDARD TABLE OF ty_text WITH DEFAULT KEY,
      ty_saves TYPE STANDARD TABLE OF ty_handles WITH DEFAULT KEY.

    METHODS get_creates RETURNING VALUE(r_result) TYPE ty_creates.
    METHODS get_texts RETURNING VALUE(r_result) TYPE ty_texts.
    METHODS get_saves RETURNING VALUE(r_result) TYPE ty_saves.
    METHODS get_releases RETURNING VALUE(r_result) TYPE ty_handles.
    METHODS get_create IMPORTING i_index TYPE i RETURNING VALUE(r_result) TYPE ty_create.
    METHODS get_text IMPORTING i_index TYPE i RETURNING VALUE(r_result) TYPE ty_text.
    METHODS get_save IMPORTING i_index TYPE i RETURNING VALUE(r_result) TYPE ty_handles.
    METHODS set_fail_create IMPORTING i_fail TYPE abap_bool.
    METHODS set_fail_save IMPORTING i_fail TYPE abap_bool.
  PROTECTED SECTION.
    METHODS create_log REDEFINITION.
    METHODS add_text REDEFINITION.
    METHODS save REDEFINITION.
    METHODS release REDEFINITION.
  PRIVATE SECTION.
    DATA m_creates TYPE ty_creates.
    DATA m_texts TYPE ty_texts.
    DATA m_saves TYPE ty_saves.
    DATA m_releases TYPE ty_handles.
    DATA m_fail_create TYPE abap_bool.
    DATA m_fail_save TYPE abap_bool.
ENDCLASS.

CLASS ltd_appender IMPLEMENTATION.
  METHOD create_log.
    IF m_fail_create = abap_true.
      RETURN.
    ENDIF.
    APPEND VALUE #( run_id = i_run_id program = i_program ) TO m_creates.
    r_result = |H{ lines( m_creates ) }|.
  ENDMETHOD.

  METHOD add_text.
    APPEND VALUE #( handle    = i_handle
                    msgty     = i_msgty
                    probclass = i_probclass
                    detlevel  = i_detlevel
                    text      = i_text ) TO m_texts.
    r_result = abap_true.
  ENDMETHOD.

  METHOD save.
    APPEND i_handles TO m_saves.
    r_result = xsdbool( m_fail_save = abap_false ).
  ENDMETHOD.

  METHOD release.
    INSERT i_handle INTO TABLE m_releases.
  ENDMETHOD.

  METHOD get_creates.
    r_result = m_creates.
  ENDMETHOD.

  METHOD get_texts.
    r_result = m_texts.
  ENDMETHOD.

  METHOD get_saves.
    r_result = m_saves.
  ENDMETHOD.

  METHOD get_releases.
    r_result = m_releases.
  ENDMETHOD.

  METHOD get_create.
    r_result = m_creates[ i_index ].
  ENDMETHOD.

  METHOD get_text.
    r_result = m_texts[ i_index ].
  ENDMETHOD.

  METHOD get_save.
    r_result = m_saves[ i_index ].
  ENDMETHOD.

  METHOD set_fail_create.
    m_fail_create = i_fail.
  ENDMETHOD.

  METHOD set_fail_save.
    m_fail_save = i_fail.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_bal DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_run1 TYPE sysuuid_x16 VALUE '0102030405060708090A0B0C0D0E0F10'.
    CONSTANTS c_run2 TYPE sysuuid_x16 VALUE '1112131415161718191A1B1C1D1E1F20'.
    "! Handle the test double gives the first log
    CONSTANTS c_handle1 TYPE balloghndl VALUE 'H1'.

    METHODS below_info_ignored FOR TESTING.
    METHODS one_log_per_run FOR TESTING.
    METHODS summary_and_reference FOR TESTING.
    METHODS long_text_in_pieces FOR TESTING.
    METHODS very_long_text_cut FOR TESTING.
    METHODS saves_when_buffer_full FOR TESTING.
    METHODS flush_saves_only_new FOR TESTING.
    METHODS failed_create_drops FOR TESTING.
    METHODS failed_save_drops_and_releases FOR TESTING.
    METHODS logger_error_saves FOR TESTING.
    METHODS factory_creates_by_name FOR TESTING.

    METHODS event
      IMPORTING i_level         TYPE int1 DEFAULT zlog4abp_if_log=>c_level-info
                i_run_id        TYPE sysuuid_x16 DEFAULT c_run1
                i_message       TYPE string DEFAULT `text`
      PREFERRED PARAMETER i_level
      RETURNING VALUE(r_result) TYPE zlog4abp_s_event.
ENDCLASS.


CLASS ltc_bal IMPLEMENTATION.

  METHOD event.
    r_result = VALUE #( event_id  = '00000000000000000000000000000001'
                        run_id    = i_run_id
                        log_level = i_level
                        category  = 'ZSD.IMPORT'
                        msg_text  = i_message ).
  ENDMETHOD.

  METHOD below_info_ignored.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( event( zlog4abp_if_log=>c_level-trace ) ).
    l_appender->append( event( zlog4abp_if_log=>c_level-debug ) ).
    l_appender->flush( ).

    cl_abap_unit_assert=>assert_initial( l_cut->get_creates( ) ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_saves( ) ).
  ENDMETHOD.

  METHOD one_log_per_run.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( event( ) ).
    l_appender->append( event( zlog4abp_if_log=>c_level-warn ) ).
    l_appender->append( event( i_run_id = c_run2 ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_creates( ) ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_create( 1 )-run_id exp = c_run1 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_create( 2 )-run_id exp = c_run2 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_text( 3 )-handle exp = 'H1' ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_text( 5 )-handle exp = 'H2' ).
  ENDMETHOD.

  METHOD summary_and_reference.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_event) = event( i_level = zlog4abp_if_log=>c_level-warn i_message = `Price missing` ).
    l_event-msgid = '00'.
    l_event-msgno = '001'.
    l_event-has_payload = abap_true.
    l_event-payload_len = 3002.
    l_event-payload_trunc = abap_true.
    l_event-exception_json = `[]`.
    l_event-payload_json = `{"secret":"never in BAL"}`.

    CAST zlog4abp_if_appender( l_cut )->append( l_event ).

    DATA(l_texts) = l_cut->get_texts( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_texts ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_texts[ 1 ]-text exp = `ZSD.IMPORT: Price missing` ).
    cl_abap_unit_assert=>assert_equals( act = l_texts[ 1 ]-detlevel exp = '1' ).
    cl_abap_unit_assert=>assert_equals( act = l_texts[ 1 ]-msgty exp = 'W' ).
    cl_abap_unit_assert=>assert_equals( act = l_texts[ 1 ]-probclass exp = '2' ).
    cl_abap_unit_assert=>assert_equals(
      act = l_texts[ 2 ]-text
      exp = `Event 00000000000000000000000000000001 in ZLOG4ABP_EVENT, message 00 001, `
         && `payload of 3002 characters (truncated), exception chain` ).
    cl_abap_unit_assert=>assert_equals( act = l_texts[ 2 ]-detlevel exp = '2' ).
    cl_abap_unit_assert=>assert_equals( act = l_texts[ 2 ]-msgty exp = 'W' ).
  ENDMETHOD.

  METHOD long_text_in_pieces.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_message) = repeat( val = `abcdefghij` occ = 45 ).
    DATA l_joined TYPE string.

    CAST zlog4abp_if_appender( l_cut )->append( event( i_message = l_message ) ).

    " "ZSD.IMPORT: " plus 450 characters: 200 + 200 + 62, then the reference
    DATA(l_texts) = l_cut->get_texts( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_texts ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = strlen( l_texts[ 1 ]-text ) exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = strlen( l_texts[ 2 ]-text ) exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = l_texts[ 2 ]-detlevel exp = '2' ).
    LOOP AT l_texts INTO DATA(text) TO 3.
      l_joined = l_joined && text-text.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = l_joined exp = `ZSD.IMPORT: ` && l_message ).
  ENDMETHOD.

  METHOD very_long_text_cut.
    DATA(l_cut) = NEW ltd_appender( ).

    CAST zlog4abp_if_appender( l_cut )->append( event( i_message = repeat( val = `x` occ = 5000 ) ) ).

    DATA(l_texts) = l_cut->get_texts( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_texts )
                                        exp = zlog4abp_cl_appender_bal=>c_max_message_lines + 1 ).
    LOOP AT l_texts INTO DATA(text).
      cl_abap_unit_assert=>assert_true( xsdbool( strlen( text-text ) <= zlog4abp_cl_appender_bal=>c_max_text ) ).
    ENDLOOP.
    DATA(l_last) = l_texts[ zlog4abp_cl_appender_bal=>c_max_message_lines ]-text.
    cl_abap_unit_assert=>assert_equals( act = substring( val = l_last off = strlen( l_last ) - 3 ) exp = `...` ).
  ENDMETHOD.

  METHOD saves_when_buffer_full.
    DATA(l_cut) = NEW ltd_appender( i_buffer_size = 2 ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( event( ) ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_saves( ) ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_unsaved_count( ) exp = 1 ).

    l_appender->append( event( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_saves( ) ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_save( 1 ) exp = VALUE zlog4abp_cl_appender_bal=>ty_handles(
                                                                          ( c_handle1 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_unsaved_count( ) exp = 0 ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_releases( ) ).
  ENDMETHOD.

  METHOD flush_saves_only_new.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( event( ) ).
    l_appender->append( event( i_run_id = c_run2 ) ).
    l_appender->flush( ).
    l_appender->flush( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_saves( ) ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_save( 1 ) ) exp = 2 ).

    " The log of run 1 stays open: a new event goes into it and only it is saved.
    l_appender->append( event( ) ).
    l_appender->flush( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_creates( ) ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_save( 2 ) exp = VALUE zlog4abp_cl_appender_bal=>ty_handles(
                                                                          ( c_handle1 ) ) ).
  ENDMETHOD.

  METHOD failed_create_drops.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).
    l_cut->set_fail_create( abap_true ).

    l_appender->append( event( ) ).
    l_appender->flush( ).

    cl_abap_unit_assert=>assert_equals( act = l_cut->get_dropped_count( ) exp = 1 ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_texts( ) ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_saves( ) ).
  ENDMETHOD.

  METHOD failed_save_drops_and_releases.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).
    l_cut->set_fail_save( abap_true ).

    l_appender->append( event( ) ).
    l_appender->append( event( ) ).
    l_appender->flush( ).

    cl_abap_unit_assert=>assert_equals( act = l_cut->get_dropped_count( ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_releases( ) exp = VALUE zlog4abp_cl_appender_bal=>ty_handles(
                                                                       ( c_handle1 ) ) ).

    " The next event of the run starts a new log.
    l_cut->set_fail_save( abap_false ).
    l_appender->append( event( ) ).
    l_appender->flush( ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_creates( ) ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_dropped_count( ) exp = 2 ).
  ENDMETHOD.

  METHOD logger_error_saves.
    DATA(l_cut) = NEW ltd_appender( ).
    DATA(l_log) = CAST zlog4abp_if_log( NEW zlog4abp_cl_logger(
      i_category  = 'ZTEST'
      i_threshold = zlog4abp_if_log=>c_level-trace
      i_appenders = VALUE #( ( l_cut ) ) ) ).

    l_log->debug( 'not for BAL' ).
    l_log->info( 'buffered' ).
    cl_abap_unit_assert=>assert_initial( l_cut->get_saves( ) ).

    l_log->error( 'saved' ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_cut->get_saves( ) ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_text( 1 )-text exp = `ZTEST: buffered` ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_text( 3 )-msgty exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_text( 3 )-probclass exp = '1' ).
  ENDMETHOD.

  METHOD factory_creates_by_name.
    DATA(l_appender) = zlog4abp_cl_factory=>get_appender( 'BAL' ).

    cl_abap_unit_assert=>assert_true( xsdbool( l_appender IS INSTANCE OF zlog4abp_cl_appender_bal ) ).
  ENDMETHOD.

ENDCLASS.
