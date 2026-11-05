"! Exception double used as the outer link of an exception chain
CLASS ltd_exception DEFINITION FINAL FOR TESTING INHERITING FROM cx_static_check.
ENDCLASS.

CLASS ltd_exception IMPLEMENTATION.
ENDCLASS.


CLASS ltc_json DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flat,
        name  TYPE string,
        count TYPE i,
        flag  TYPE abap_bool,
        day   TYPE d,
      END OF ty_flat,
      BEGIN OF ty_nested,
        id    TYPE c LENGTH 4,
        lines TYPE string_table,
      END OF ty_nested,
      ty_numbers TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    DATA m_cut TYPE REF TO zlog4abp_cl_json.

    METHODS setup.
    METHODS structure_lowercase_keys FOR TESTING.
    METHODS false_and_numbers FOR TESTING.
    METHODS table_as_array FOR TESTING.
    METHODS nested_structure FOR TESTING.
    METHODS escapes_special_chars FOR TESTING.
    METHODS control_char_as_unicode FOR TESTING.
    METHODS data_reference_followed FOR TESTING.
    METHODS unbound_reference_null FOR TESTING.
    METHODS exception_chain FOR TESTING.
    METHODS unbound_exception_initial FOR TESTING.
    METHODS pairs_object FOR TESTING.
ENDCLASS.


CLASS ltc_json IMPLEMENTATION.

  METHOD setup.
    m_cut = NEW #( ).
  ENDMETHOD.

  METHOD structure_lowercase_keys.
    DATA(l_flat) = VALUE ty_flat( name = `A"b` count = -5 flag = abap_true day = '20261105' ).

    cl_abap_unit_assert=>assert_equals(
      act = m_cut->serialize( l_flat )
      exp = `{"name":"A\"b","count":-5,"flag":true,"day":"2026-11-05"}` ).
  ENDMETHOD.

  METHOD false_and_numbers.
    DATA l_amount TYPE p LENGTH 8 DECIMALS 2 VALUE '12.50'.
    DATA(l_flat) = VALUE ty_flat( name = `x` count = 0 flag = abap_false day = '20260101' ).

    cl_abap_unit_assert=>assert_equals(
      act = m_cut->serialize( l_flat )
      exp = `{"name":"x","count":0,"flag":false,"day":"2026-01-01"}` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->serialize( l_amount ) exp = `12.50` ).
  ENDMETHOD.

  METHOD table_as_array.
    DATA(l_numbers) = VALUE ty_numbers( ( 1 ) ( 2 ) ( 3 ) ).
    DATA(l_texts) = VALUE string_table( ( `x` ) ( `y` ) ).
    DATA l_empty TYPE string_table.

    cl_abap_unit_assert=>assert_equals( act = m_cut->serialize( l_numbers ) exp = `[1,2,3]` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->serialize( l_texts ) exp = `["x","y"]` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->serialize( l_empty ) exp = `[]` ).
  ENDMETHOD.

  METHOD nested_structure.
    DATA(l_nested) = VALUE ty_nested( id = 'A1' lines = VALUE #( ( `l1` ) ) ).

    cl_abap_unit_assert=>assert_equals(
      act = m_cut->serialize( l_nested )
      exp = `{"id":"A1","lines":["l1"]}` ).
  ENDMETHOD.

  METHOD escapes_special_chars.
    DATA(l_text) = |a\\b{ cl_abap_char_utilities=>newline }{ cl_abap_char_utilities=>horizontal_tab }"|.

    cl_abap_unit_assert=>assert_equals(
      act = m_cut->quote( l_text )
      exp = `"a\\b\n\t\""` ).
  ENDMETHOD.

  METHOD control_char_as_unicode.
    DATA(l_text) = |x{ cl_abap_conv_in_ce=>uccpi( 1 ) }y|.

    cl_abap_unit_assert=>assert_equals( act = m_cut->quote( l_text ) exp = `"x\u0001y"` ).
  ENDMETHOD.

  METHOD data_reference_followed.
    DATA l_value TYPE i VALUE 7.
    DATA(l_ref) = REF #( l_value ).

    cl_abap_unit_assert=>assert_equals( act = m_cut->serialize( l_ref ) exp = `7` ).
  ENDMETHOD.

  METHOD unbound_reference_null.
    DATA l_ref TYPE REF TO data.
    DATA l_object TYPE REF TO object.

    cl_abap_unit_assert=>assert_equals( act = m_cut->serialize( l_ref ) exp = `null` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->serialize( l_object ) exp = `null` ).
  ENDMETHOD.

  METHOD exception_chain.
    DATA(l_inner) = NEW cx_sy_zerodivide( ).
    DATA(l_outer) = NEW ltd_exception( previous = l_inner ).

    DATA(l_json) = m_cut->serialize_exception( l_outer ).

    cl_abap_unit_assert=>assert_equals( act = count( val = l_json sub = `"class":` ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_json CS `"class":"LTD_EXCEPTION"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_json CS `"class":"CX_SY_ZERODIVIDE"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( l_json CP `[{*}]` ) ).
  ENDMETHOD.

  METHOD unbound_exception_initial.
    cl_abap_unit_assert=>assert_initial( m_cut->serialize_exception( VALUE #( ) ) ).
  ENDMETHOD.

  METHOD pairs_object.
    DATA(l_pairs) = VALUE zlog4abp_cl_json=>ty_pairs( ( name = `order` value = `4711` )
                                                      ( name = `step` value = `a"b` ) ).

    cl_abap_unit_assert=>assert_equals(
      act = m_cut->object_from_pairs( l_pairs )
      exp = `{"order":"4711","step":"a\"b"}` ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->object_from_pairs( VALUE #( ) ) exp = `{}` ).
  ENDMETHOD.

ENDCLASS.
