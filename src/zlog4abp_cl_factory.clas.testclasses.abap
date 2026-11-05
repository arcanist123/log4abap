CLASS ltc_factory DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA m_memory TYPE REF TO zlog4abp_cl_appender_memory.

    METHODS setup.
    METHODS teardown.
    METHODS configure
      IMPORTING i_rules TYPE zlog4abp_cl_config=>ty_rules.

    METHODS same_logger_per_category FOR TESTING.
    METHODS logger_uses_configuration FOR TESTING.
    METHODS unknown_appenders_ignored FOR TESTING.
    METHODS appender_created_by_name FOR TESTING.
    METHODS appender_shared_by_loggers FOR TESTING.
    METHODS flush_all_flushes FOR TESTING.
    METHODS default_without_rules FOR TESTING.
ENDCLASS.


CLASS ltc_factory IMPLEMENTATION.

  METHOD setup.
    m_memory = NEW #( ).
    configure( VALUE #( ( category = '*' uname = '*' log_level = zlog4abp_if_log=>c_level-trace
                          appenders = 'MEMORY' ) ) ).
  ENDMETHOD.

  METHOD teardown.
    " Unbound configuration: the next productive use reads the table again
    zlog4abp_cl_factory=>set_config( ).
  ENDMETHOD.

  METHOD configure.
    zlog4abp_cl_factory=>set_config( NEW zlog4abp_cl_config( i_rules ) ).
    zlog4abp_cl_factory=>register_appender( i_name = 'MEMORY' i_appender = m_memory ).
  ENDMETHOD.

  METHOD same_logger_per_category.
    DATA(l_first) = zlog4abp_cl_factory=>get( 'ZSD.IMPORT' ).
    DATA(l_second) = zlog4abp_cl_factory=>get( 'zsd.import' ).

    cl_abap_unit_assert=>assert_bound( l_first ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_first = l_second ) ).
    cl_abap_unit_assert=>assert_equals( act = l_first->get_category( ) exp = `ZSD.IMPORT` ).
  ENDMETHOD.

  METHOD logger_uses_configuration.
    configure( VALUE #( ( category = '*' uname = '*' log_level = zlog4abp_if_log=>c_level-warn
                          appenders = 'MEMORY' ) ) ).

    DATA(l_log) = zlog4abp_cl_factory=>get( 'ZSD.IMPORT' ).
    l_log->info( 'filtered' ).
    l_log->warn( 'logged' ).

    cl_abap_unit_assert=>assert_equals( act = m_memory->get_count( ) exp = 1 ).
  ENDMETHOD.

  METHOD unknown_appenders_ignored.
    configure( VALUE #( ( category = '*' uname = '*' log_level = zlog4abp_if_log=>c_level-info
                          appenders = 'NOPE,BAD-NAME,MEMORY' ) ) ).

    zlog4abp_cl_factory=>get( 'ZSD' )->info( 'logged' ).

    cl_abap_unit_assert=>assert_equals( act = m_memory->get_count( ) exp = 1 ).
    cl_abap_unit_assert=>assert_not_bound( zlog4abp_cl_factory=>get_appender( 'NOPE' ) ).
    cl_abap_unit_assert=>assert_not_bound( zlog4abp_cl_factory=>get_appender( 'BAD-NAME' ) ).
  ENDMETHOD.

  METHOD appender_created_by_name.
    zlog4abp_cl_factory=>set_config( NEW zlog4abp_cl_config( VALUE #( ) ) ).

    DATA(l_appender) = zlog4abp_cl_factory=>get_appender( 'memory' ).

    cl_abap_unit_assert=>assert_true( xsdbool( l_appender IS INSTANCE OF zlog4abp_cl_appender_memory ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_appender = zlog4abp_cl_factory=>get_appender( 'MEMORY' ) ) ).
  ENDMETHOD.

  METHOD appender_shared_by_loggers.
    zlog4abp_cl_factory=>get( 'ZSD' )->info( 'one' ).
    zlog4abp_cl_factory=>get( 'ZMM' )->info( 'two' ).

    cl_abap_unit_assert=>assert_equals( act = m_memory->get_count( ) exp = 2 ).
  ENDMETHOD.

  METHOD flush_all_flushes.
    zlog4abp_cl_factory=>get( 'ZSD' )->info( 'buffered' ).

    zlog4abp_cl_factory=>flush_all( ).

    cl_abap_unit_assert=>assert_equals( act = m_memory->get_flush_count( ) exp = 1 ).
  ENDMETHOD.

  METHOD default_without_rules.
    configure( VALUE #( ) ).

    DATA(l_logger) = CAST zlog4abp_cl_logger( zlog4abp_cl_factory=>get( 'ZSD' ) ).

    cl_abap_unit_assert=>assert_equals( act = l_logger->get_threshold( ) exp = zlog4abp_if_log=>c_level-warn ).
  ENDMETHOD.

ENDCLASS.
