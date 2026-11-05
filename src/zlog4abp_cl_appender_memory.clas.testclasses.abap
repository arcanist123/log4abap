CLASS ltc_memory DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS keeps_events_in_order FOR TESTING.
    METHODS counts_flushes_and_clears FOR TESTING.
ENDCLASS.


CLASS ltc_memory IMPLEMENTATION.

  METHOD keeps_events_in_order.
    DATA(l_cut) = NEW zlog4abp_cl_appender_memory( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( VALUE #( msg_text = `one` ) ).
    l_appender->append( VALUE #( msg_text = `two` ) ).

    cl_abap_unit_assert=>assert_equals( act = l_cut->get_count( ) exp = 2 ).
    DATA(l_events) = l_cut->get_events( ).
    cl_abap_unit_assert=>assert_equals( act = l_events[ 2 ]-msg_text exp = `two` ).
  ENDMETHOD.

  METHOD counts_flushes_and_clears.
    DATA(l_cut) = NEW zlog4abp_cl_appender_memory( ).
    DATA(l_appender) = CAST zlog4abp_if_appender( l_cut ).

    l_appender->append( VALUE #( msg_text = `one` ) ).
    l_appender->flush( ).

    cl_abap_unit_assert=>assert_equals( act = l_cut->get_flush_count( ) exp = 1 ).

    l_cut->clear( ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_count( ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = l_cut->get_flush_count( ) exp = 0 ).
  ENDMETHOD.

ENDCLASS.
