CLASS ltc_context DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA m_saved_run_id TYPE sysuuid_x16.
    DATA m_saved_entries TYPE zlog4abp_cl_context=>ty_entries.

    METHODS setup.
    METHODS teardown.
    METHODS run_id_generated_once FOR TESTING.
    METHODS run_id_can_be_continued FOR TESTING.
    METHODS put_replaces_value FOR TESTING.
    METHODS remove_and_clear FOR TESTING.
    METHODS json_contains_values FOR TESTING.
    METHODS info_has_user_and_program FOR TESTING.
    METHODS seq_no_increments FOR TESTING.
ENDCLASS.


CLASS ltc_context IMPLEMENTATION.

  METHOD setup.
    m_saved_run_id = zlog4abp_cl_context=>get_run_id( ).
    m_saved_entries = zlog4abp_cl_context=>get_entries( ).
    zlog4abp_cl_context=>clear( ).
  ENDMETHOD.

  METHOD teardown.
    zlog4abp_cl_context=>set_run_id( m_saved_run_id ).
    zlog4abp_cl_context=>clear( ).
    LOOP AT m_saved_entries INTO DATA(entry).
      zlog4abp_cl_context=>put( i_key = entry-key i_value = entry-value ).
    ENDLOOP.
  ENDMETHOD.

  METHOD run_id_generated_once.
    zlog4abp_cl_context=>set_run_id( VALUE #( ) ).

    DATA(l_first) = zlog4abp_cl_context=>get_run_id( ).

    cl_abap_unit_assert=>assert_not_initial( l_first ).
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_context=>get_run_id( ) exp = l_first ).
  ENDMETHOD.

  METHOD run_id_can_be_continued.
    DATA l_run_id TYPE sysuuid_x16 VALUE '0123456789ABCDEF0123456789ABCDEF'.

    zlog4abp_cl_context=>set_run_id( l_run_id ).

    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_context=>get_run_id( ) exp = l_run_id ).
  ENDMETHOD.

  METHOD put_replaces_value.
    zlog4abp_cl_context=>put( i_key = 'order' i_value = 4711 ).
    zlog4abp_cl_context=>put( i_key = 'order' i_value = 'A-1' ).

    cl_abap_unit_assert=>assert_equals(
      act = zlog4abp_cl_context=>get_entries( )
      exp = VALUE zlog4abp_cl_context=>ty_entries( ( key = `order` value = `A-1` ) ) ).
  ENDMETHOD.

  METHOD remove_and_clear.
    zlog4abp_cl_context=>put( i_key = 'a' i_value = 1 ).
    zlog4abp_cl_context=>put( i_key = 'b' i_value = 2 ).

    zlog4abp_cl_context=>remove( 'a' ).
    cl_abap_unit_assert=>assert_equals( act = lines( zlog4abp_cl_context=>get_entries( ) ) exp = 1 ).

    DATA(l_run_id) = zlog4abp_cl_context=>get_run_id( ).
    zlog4abp_cl_context=>clear( ).
    cl_abap_unit_assert=>assert_initial( zlog4abp_cl_context=>get_entries( ) ).
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_context=>get_run_id( ) exp = l_run_id ).
  ENDMETHOD.

  METHOD json_contains_values.
    zlog4abp_cl_context=>put( i_key = 'order' i_value = 4711 ).

    DATA(l_json) = zlog4abp_cl_context=>as_json( ).

    cl_abap_unit_assert=>assert_true( xsdbool( l_json CS `"values":{"order":"4711"}` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_json CS `"user":` ) ).
  ENDMETHOD.

  METHOD info_has_user_and_program.
    DATA(l_info) = zlog4abp_cl_context=>get_info( ).

    cl_abap_unit_assert=>assert_equals( act = l_info-uname exp = sy-uname ).
    cl_abap_unit_assert=>assert_not_initial( l_info-program_name ).
  ENDMETHOD.

  METHOD seq_no_increments.
    DATA(l_first) = zlog4abp_cl_context=>next_seq_no( ).

    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_context=>next_seq_no( ) exp = l_first + 1 ).
  ENDMETHOD.

ENDCLASS.
