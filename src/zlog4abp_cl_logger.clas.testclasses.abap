"! Serializer double that counts calls
CLASS ltd_json DEFINITION FINAL FOR TESTING INHERITING FROM zlog4abp_cl_json.
  PUBLIC SECTION.
    METHODS serialize REDEFINITION.
    METHODS serialize_exception REDEFINITION.
    METHODS get_calls RETURNING VALUE(r_result) TYPE i.
  PRIVATE SECTION.
    DATA m_calls TYPE i.
ENDCLASS.

CLASS ltd_json IMPLEMENTATION.
  METHOD serialize.
    m_calls = m_calls + 1.
    r_result = super->serialize( i_data ).
  ENDMETHOD.

  METHOD serialize_exception.
    m_calls = m_calls + 1.
    r_result = super->serialize_exception( i_exception ).
  ENDMETHOD.

  METHOD get_calls.
    r_result = m_calls.
  ENDMETHOD.
ENDCLASS.


"! Formatter double that counts calls
CLASS ltd_formatter DEFINITION FINAL FOR TESTING INHERITING FROM zlog4abp_cl_formatter.
  PUBLIC SECTION.
    METHODS format REDEFINITION.
    METHODS to_text REDEFINITION.
    METHODS t100_text REDEFINITION.
    METHODS get_calls RETURNING VALUE(r_result) TYPE i.
  PRIVATE SECTION.
    DATA m_calls TYPE i.
ENDCLASS.

CLASS ltd_formatter IMPLEMENTATION.
  METHOD format.
    m_calls = m_calls + 1.
    r_result = super->format( i_pattern = i_pattern i_values = i_values ).
  ENDMETHOD.

  METHOD to_text.
    m_calls = m_calls + 1.
    r_result = super->to_text( i_value ).
  ENDMETHOD.

  METHOD t100_text.
    m_calls = m_calls + 1.
    r_result = super->t100_text( i_msgid = i_msgid
                                 i_msgno = i_msgno
                                 i_msgv1 = i_msgv1
                                 i_msgv2 = i_msgv2
                                 i_msgv3 = i_msgv3
                                 i_msgv4 = i_msgv4 ).
  ENDMETHOD.

  METHOD get_calls.
    r_result = m_calls.
  ENDMETHOD.
ENDCLASS.


"! Supplier double that counts calls
CLASS ltd_supplier DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zlog4abp_if_supplier.
    METHODS constructor IMPORTING i_message TYPE string i_data TYPE string.
    METHODS get_calls RETURNING VALUE(r_result) TYPE i.
  PRIVATE SECTION.
    DATA m_calls TYPE i.
    DATA m_message TYPE string.
    DATA m_data TYPE string.
ENDCLASS.

CLASS ltd_supplier IMPLEMENTATION.
  METHOD constructor.
    m_message = i_message.
    m_data = i_data.
  ENDMETHOD.

  METHOD zlog4abp_if_supplier~get_message.
    m_calls = m_calls + 1.
    r_result = m_message.
  ENDMETHOD.

  METHOD zlog4abp_if_supplier~get_data.
    m_calls = m_calls + 1.
    r_result = REF #( m_data ).
  ENDMETHOD.

  METHOD get_calls.
    r_result = m_calls.
  ENDMETHOD.
ENDCLASS.


"! Appender double that fails on every call
CLASS ltd_failing_appender DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zlog4abp_if_appender.
ENDCLASS.

CLASS ltd_failing_appender IMPLEMENTATION.
  METHOD zlog4abp_if_appender~append.
    DATA l_zero TYPE i.
    l_zero = 1 / l_zero.
  ENDMETHOD.

  METHOD zlog4abp_if_appender~flush.
    DATA l_zero TYPE i.
    l_zero = 1 / l_zero.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_logger DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_order,
        id  TYPE c LENGTH 10,
        qty TYPE i,
      END OF ty_order.

    DATA m_memory TYPE REF TO zlog4abp_cl_appender_memory.
    DATA m_json TYPE REF TO ltd_json.
    DATA m_formatter TYPE REF TO ltd_formatter.

    METHODS setup.
    METHODS create
      IMPORTING i_threshold     TYPE int1
                i_max_payload   TYPE i DEFAULT zlog4abp_cl_logger=>c_default_max_payload
                i_appenders     TYPE zlog4abp_cl_logger=>ty_appenders OPTIONAL
      RETURNING VALUE(r_result) TYPE REF TO zlog4abp_if_log.
    METHODS last_event
      RETURNING VALUE(r_result) TYPE zlog4abp_s_event.

    METHODS disabled_level_does_no_work FOR TESTING.
    METHODS disabled_t100_does_no_work FOR TESTING.
    METHODS enabled_level_uses_supplier FOR TESTING.
    METHODS message_beats_empty_supplier FOR TESTING.
    METHODS placeholders_values_and_args FOR TESTING.
    METHODS only_supplied_values_used FOR TESTING.
    METHODS structure_value_as_json FOR TESTING.
    METHODS failing_appender_isolated FOR TESTING.
    METHODS error_flushes_appenders FOR TESTING.
    METHODS payload_truncated FOR TESTING.
    METHODS payload_within_limit FOR TESTING.
    METHODS no_payload FOR TESTING.
    METHODS exception_recorded FOR TESTING.
    METHODS t100_level_and_key FOR TESTING.
    METHODS off_blocks_everything FOR TESTING.
    METHODS is_enabled_by_threshold FOR TESTING.
    METHODS event_header_fields FOR TESTING.
    METHODS source_position_warn_only FOR TESTING.
ENDCLASS.


CLASS ltc_logger IMPLEMENTATION.

  METHOD setup.
    m_memory = NEW #( ).
    m_json = NEW #( ).
    m_formatter = NEW #( m_json ).
  ENDMETHOD.

  METHOD create.
    DATA(l_appenders) = i_appenders.
    IF l_appenders IS INITIAL.
      l_appenders = VALUE #( ( m_memory ) ).
    ENDIF.
    r_result = NEW zlog4abp_cl_logger( i_category    = 'zlog4abp.test'
                                       i_threshold   = i_threshold
                                       i_appenders   = l_appenders
                                       i_formatter   = m_formatter
                                       i_json        = m_json
                                       i_max_payload = i_max_payload ).
  ENDMETHOD.

  METHOD last_event.
    DATA(l_events) = m_memory->get_events( ).
    cl_abap_unit_assert=>assert_not_initial( act = l_events msg = 'No event appended' ).
    r_result = l_events[ lines( l_events ) ].
  ENDMETHOD.

  METHOD disabled_level_does_no_work.
    DATA(l_supplier) = NEW ltd_supplier( i_message = `expensive` i_data = `payload` ).
    DATA(l_order) = VALUE ty_order( id = 'A1' qty = 3 ).
    DATA(l_log) = create( zlog4abp_if_log=>c_level-error ).

    l_log->trace( i_message = 'Order {}' i_val1 = l_order i_data = l_order i_supplier = l_supplier ).
    l_log->debug( i_message = 'Order {}' i_val1 = l_order i_data = l_order i_supplier = l_supplier ).
    l_log->info( i_message = 'Order {}' i_val1 = l_order i_data = l_order i_supplier = l_supplier ).
    l_log->warn( i_message = 'Order {}' i_val1 = l_order i_data = l_order i_supplier = l_supplier
                 i_exception = NEW cx_sy_zerodivide( ) ).

    cl_abap_unit_assert=>assert_equals( act = l_supplier->get_calls( ) exp = 0 msg = 'Supplier called' ).
    cl_abap_unit_assert=>assert_equals( act = m_formatter->get_calls( ) exp = 0 msg = 'Formatter called' ).
    cl_abap_unit_assert=>assert_equals( act = m_json->get_calls( ) exp = 0 msg = 'Serializer called' ).
    cl_abap_unit_assert=>assert_equals( act = m_memory->get_count( ) exp = 0 msg = 'Event appended' ).
  ENDMETHOD.

  METHOD disabled_t100_does_no_work.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-error ).

    l_log->t100( i_msgid = '00' i_msgty = 'W' i_msgno = '001' i_msgv1 = 'x' ).

    cl_abap_unit_assert=>assert_equals( act = m_formatter->get_calls( ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = m_memory->get_count( ) exp = 0 ).
  ENDMETHOD.

  METHOD enabled_level_uses_supplier.
    DATA(l_supplier) = NEW ltd_supplier( i_message = `from supplier` i_data = `payload` ).
    DATA(l_log) = create( zlog4abp_if_log=>c_level-debug ).

    l_log->debug( i_message = 'ignored' i_supplier = l_supplier ).

    DATA(l_event) = last_event( ).
    cl_abap_unit_assert=>assert_equals( act = l_supplier->get_calls( ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_event-msg_text exp = `from supplier` ).
    cl_abap_unit_assert=>assert_equals( act = l_event-payload_json exp = `"payload"` ).
  ENDMETHOD.

  METHOD message_beats_empty_supplier.
    DATA(l_supplier) = NEW ltd_supplier( i_message = `` i_data = `` ).
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->info( i_message = 'kept' i_supplier = l_supplier ).

    cl_abap_unit_assert=>assert_equals( act = last_event( )-msg_text exp = `kept` ).
  ENDMETHOD.

  METHOD placeholders_values_and_args.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->info( i_message = 'a={} b={} c={} d={} e={} f={} g={}'
                 i_val1    = 1
                 i_val2    = 'two'
                 i_val3    = `three`
                 i_val4    = -4
                 i_args    = VALUE #( ( `5` ) ( `6` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = last_event( )-msg_text
                                        exp = `a=1 b=two c=three d=-4 e=5 f=6 g={}` ).
  ENDMETHOD.

  METHOD only_supplied_values_used.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->info( i_message = '{} and {}' i_val2 = 'second' ).

    cl_abap_unit_assert=>assert_equals( act = last_event( )-msg_text exp = `second and {}` ).
  ENDMETHOD.

  METHOD structure_value_as_json.
    DATA(l_order) = VALUE ty_order( id = 'A1' qty = 3 ).
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->info( i_message = 'Order {}' i_val1 = l_order ).

    cl_abap_unit_assert=>assert_equals( act = last_event( )-msg_text exp = `Order {"id":"A1","qty":3}` ).
  ENDMETHOD.

  METHOD failing_appender_isolated.
    DATA(l_log) = create( i_threshold = zlog4abp_if_log=>c_level-info
                          i_appenders = VALUE #( ( NEW ltd_failing_appender( ) ) ( m_memory ) ) ).

    TRY.
        l_log->error( 'still logged' ).
        l_log->info( 'also logged' ).
        l_log->flush( ).
      CATCH cx_root INTO DATA(l_error).
        cl_abap_unit_assert=>fail( |Exception escaped: { l_error->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_equals( act = m_memory->get_count( ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = m_memory->get_flush_count( ) exp = 2 ).
  ENDMETHOD.

  METHOD error_flushes_appenders.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->warn( 'no flush' ).
    cl_abap_unit_assert=>assert_equals( act = m_memory->get_flush_count( ) exp = 0 ).

    l_log->error( 'flush' ).
    cl_abap_unit_assert=>assert_equals( act = m_memory->get_flush_count( ) exp = 1 ).
  ENDMETHOD.

  METHOD payload_truncated.
    DATA(l_log) = create( i_threshold = zlog4abp_if_log=>c_level-info i_max_payload = 10 ).

    " Serialized as "abcdefghijklmnop" (18 characters including the quotes)
    l_log->info( i_message = 'big' i_data = `abcdefghijklmnop` ).

    DATA(l_event) = last_event( ).
    cl_abap_unit_assert=>assert_equals( act = l_event-has_payload exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = l_event-payload_trunc exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = l_event-payload_len exp = 18 ).
    cl_abap_unit_assert=>assert_equals( act = l_event-payload_json exp = `"abcdefghi` ).
  ENDMETHOD.

  METHOD payload_within_limit.
    DATA(l_log) = create( i_threshold = zlog4abp_if_log=>c_level-info i_max_payload = 18 ).

    l_log->info( i_message = 'fits' i_data = `abcdefghijklmnop` ).

    DATA(l_event) = last_event( ).
    cl_abap_unit_assert=>assert_equals( act = l_event-payload_trunc exp = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = l_event-payload_len exp = 18 ).
    cl_abap_unit_assert=>assert_equals( act = l_event-payload_json exp = `"abcdefghijklmnop"` ).
  ENDMETHOD.

  METHOD no_payload.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->info( 'nothing attached' ).

    DATA(l_event) = last_event( ).
    cl_abap_unit_assert=>assert_equals( act = l_event-has_payload exp = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = l_event-payload_len exp = 0 ).
    cl_abap_unit_assert=>assert_initial( l_event-payload_json ).
    cl_abap_unit_assert=>assert_equals( act = m_json->get_calls( ) exp = 0 ).
  ENDMETHOD.

  METHOD exception_recorded.
    DATA(l_exception) = NEW cx_sy_zerodivide( ).
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->error( i_exception = l_exception ).

    DATA(l_event) = last_event( ).
    cl_abap_unit_assert=>assert_equals( act = l_event-msg_text exp = l_exception->get_text( ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_event-exception_json CS `CX_SY_ZERODIVIDE` ) ).
  ENDMETHOD.

  METHOD t100_level_and_key.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->t100( i_msgid = '00' i_msgty = 'W' i_msgno = '001' i_msgv1 = 'hello' ).

    DATA(l_event) = last_event( ).
    cl_abap_unit_assert=>assert_equals( act = l_event-log_level exp = zlog4abp_if_log=>c_level-warn ).
    cl_abap_unit_assert=>assert_equals( act = l_event-msgid exp = '00' ).
    cl_abap_unit_assert=>assert_equals( act = l_event-msgno exp = '001' ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_event-msg_text CS 'hello' ) ).

    l_log->t100( i_msgid = '00' i_msgty = 'E' i_msgno = '001' ).
    cl_abap_unit_assert=>assert_equals( act = last_event( )-log_level exp = zlog4abp_if_log=>c_level-error ).

    l_log->t100( i_level = zlog4abp_if_log=>c_level-info i_msgid = '00' i_msgty = 'E' i_msgno = '001' ).
    cl_abap_unit_assert=>assert_equals( act = last_event( )-log_level exp = zlog4abp_if_log=>c_level-info ).
  ENDMETHOD.

  METHOD off_blocks_everything.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-off ).

    l_log->error( 'blocked' ).
    l_log->t100( i_msgid = '00' i_msgty = 'E' i_msgno = '001' ).

    cl_abap_unit_assert=>assert_equals( act = m_memory->get_count( ) exp = 0 ).
  ENDMETHOD.

  METHOD is_enabled_by_threshold.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    cl_abap_unit_assert=>assert_false( l_log->is_enabled( zlog4abp_if_log=>c_level-debug ) ).
    cl_abap_unit_assert=>assert_true( l_log->is_enabled( zlog4abp_if_log=>c_level-info ) ).
    cl_abap_unit_assert=>assert_true( l_log->is_enabled( zlog4abp_if_log=>c_level-error ) ).
    cl_abap_unit_assert=>assert_false( l_log->is_enabled( zlog4abp_if_log=>c_level-off ) ).
  ENDMETHOD.

  METHOD event_header_fields.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-info ).

    l_log->info( 'first' ).
    DATA(l_first) = last_event( ).
    l_log->info( 'second' ).
    DATA(l_second) = last_event( ).

    cl_abap_unit_assert=>assert_equals( act = l_first-category exp = 'ZLOG4ABP.TEST' ).
    cl_abap_unit_assert=>assert_equals( act = l_first-log_level exp = zlog4abp_if_log=>c_level-info ).
    cl_abap_unit_assert=>assert_equals( act = l_first-run_id exp = zlog4abp_cl_context=>get_run_id( ) ).
    cl_abap_unit_assert=>assert_equals( act = l_first-uname exp = sy-uname ).
    cl_abap_unit_assert=>assert_not_initial( l_first-event_id ).
    cl_abap_unit_assert=>assert_not_initial( l_first-event_ts ).
    cl_abap_unit_assert=>assert_differs( act = l_second-event_id exp = l_first-event_id ).
    cl_abap_unit_assert=>assert_equals( act = l_second-seq_no exp = l_first-seq_no + 1 ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_first-context_json CP '{*}' ) ).
  ENDMETHOD.

  METHOD source_position_warn_only.
    DATA(l_log) = create( zlog4abp_if_log=>c_level-trace ).

    l_log->info( 'no position' ).
    cl_abap_unit_assert=>assert_initial( last_event( )-source_pos ).

    l_log->warn( 'with position' ).
    cl_abap_unit_assert=>assert_not_initial( last_event( )-source_pos ).
  ENDMETHOD.

ENDCLASS.
