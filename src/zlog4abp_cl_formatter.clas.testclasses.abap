CLASS ltc_formatter DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_pair,
        key   TYPE string,
        value TYPE i,
      END OF ty_pair.

    DATA m_cut TYPE REF TO zlog4abp_cl_formatter.

    METHODS setup.
    METHODS no_placeholders FOR TESTING.
    METHODS replaces_in_order FOR TESTING.
    METHODS missing_values_keep_braces FOR TESTING.
    METHODS extra_values_ignored FOR TESTING.
    METHODS more_than_four_values FOR TESTING.
    METHODS inserted_text_not_rescanned FOR TESTING.
    METHODS placeholders_at_edges FOR TESTING.
    METHODS empty_pattern FOR TESTING.
    METHODS elementary_to_text FOR TESTING.
    METHODS structure_to_json FOR TESTING.
    METHODS reference_to_text FOR TESTING.
    METHODS level_names FOR TESTING.
    METHODS shorten_keeps_short_text FOR TESTING.
    METHODS shorten_cuts_with_ellipsis FOR TESTING.
ENDCLASS.


CLASS ltc_formatter IMPLEMENTATION.

  METHOD setup.
    m_cut = NEW #( ).
  ENDMETHOD.

  METHOD no_placeholders.
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = 'plain text' i_values = VALUE #( ( `a` ) ) )
      exp = `plain text` ).
  ENDMETHOD.

  METHOD replaces_in_order.
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = 'a {} b {}' i_values = VALUE #( ( `1` ) ( `2` ) ) )
      exp = `a 1 b 2` ).
  ENDMETHOD.

  METHOD missing_values_keep_braces.
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = '{} and {} and {}' i_values = VALUE #( ( `x` ) ) )
      exp = `x and {} and {}` ).
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = 'none {}' i_values = VALUE #( ) )
      exp = `none {}` ).
  ENDMETHOD.

  METHOD extra_values_ignored.
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = 'only {}' i_values = VALUE #( ( `x` ) ( `y` ) ( `z` ) ) )
      exp = `only x` ).
  ENDMETHOD.

  METHOD more_than_four_values.
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = '{} {} {} {} {} {}'
                           i_values  = VALUE #( ( `1` ) ( `2` ) ( `3` ) ( `4` ) ( `5` ) ( `6` ) ) )
      exp = `1 2 3 4 5 6` ).
  ENDMETHOD.

  METHOD inserted_text_not_rescanned.
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = '{} {}' i_values = VALUE #( ( `{}` ) ( `b` ) ) )
      exp = `{} b` ).
  ENDMETHOD.

  METHOD placeholders_at_edges.
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = '{}x{}' i_values = VALUE #( ( `A` ) ( `B` ) ) )
      exp = `AxB` ).
    cl_abap_unit_assert=>assert_equals(
      act = m_cut->format( i_pattern = '{}{}' i_values = VALUE #( ( `A` ) ( `B` ) ) )
      exp = `AB` ).
  ENDMETHOD.

  METHOD empty_pattern.
    cl_abap_unit_assert=>assert_initial( m_cut->format( i_pattern = `` i_values = VALUE #( ( `x` ) ) ) ).
  ENDMETHOD.

  METHOD elementary_to_text.
    DATA l_int TYPE i VALUE -42.
    DATA l_char TYPE c LENGTH 10 VALUE 'ab'.
    DATA l_date TYPE d VALUE '20261105'.
    DATA l_time TYPE t VALUE '090500'.
    DATA l_numc TYPE n LENGTH 6 VALUE '000123'.

    cl_abap_unit_assert=>assert_equals( act = m_cut->to_text( l_int ) exp = `-42` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->to_text( l_char ) exp = `ab` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->to_text( l_date ) exp = `2026-11-05` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->to_text( l_time ) exp = `09:05:00` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->to_text( l_numc ) exp = `000123` ).
  ENDMETHOD.

  METHOD structure_to_json.
    DATA(l_pair) = VALUE ty_pair( key = `k` value = 1 ).

    cl_abap_unit_assert=>assert_equals( act = m_cut->to_text( l_pair ) exp = `{"key":"k","value":1}` ).
  ENDMETHOD.

  METHOD reference_to_text.
    DATA l_value TYPE string VALUE `deref`.
    DATA(l_ref) = REF #( l_value ).

    cl_abap_unit_assert=>assert_equals( act = m_cut->to_text( l_ref ) exp = `deref` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->to_text( NEW cx_sy_zerodivide( ) )
                                        exp = NEW cx_sy_zerodivide( )->get_text( ) ).
  ENDMETHOD.

  METHOD level_names.
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_formatter=>level_name( zlog4abp_if_log=>c_level-trace )
                                        exp = `TRACE` ).
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_formatter=>level_name( zlog4abp_if_log=>c_level-error )
                                        exp = `ERROR` ).
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_formatter=>level_name( 9 ) exp = `9` ).
  ENDMETHOD.

  METHOD shorten_keeps_short_text.
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_formatter=>shorten( i_text = `abcde` i_max_length = 5 )
                                        exp = `abcde` ).
  ENDMETHOD.

  METHOD shorten_cuts_with_ellipsis.
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_formatter=>shorten( i_text = `abcdefgh` i_max_length = 6 )
                                        exp = `abc...` ).
    " The limit never drops below the length of the ellipsis.
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_formatter=>shorten( i_text = `abcdefgh` i_max_length = 1 )
                                        exp = `...` ).
  ENDMETHOD.

ENDCLASS.
