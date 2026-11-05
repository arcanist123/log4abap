CLASS ltc_config DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_now TYPE timestampl VALUE '20261105120000.0000000'.

    DATA m_rules TYPE zlog4abp_cl_config=>ty_rules.

    METHODS setup.
    METHODS add_rule
      IMPORTING i_category  TYPE csequence
                i_uname     TYPE syuname DEFAULT '*'
                i_level     TYPE int1
                i_appenders TYPE csequence DEFAULT 'EVENT'
                i_valid_to  TYPE timestampl OPTIONAL.
    METHODS resolve
      IMPORTING i_category      TYPE csequence
                i_uname         TYPE syuname DEFAULT 'OTHER'
      RETURNING VALUE(r_result) TYPE zlog4abp_cl_config=>ty_resolution.

    METHODS default_without_rules FOR TESTING.
    METHODS global_wildcard_rule FOR TESTING.
    METHODS longest_prefix_wins FOR TESTING.
    METHODS segment_boundary FOR TESTING.
    METHODS user_beats_longer_global FOR TESTING.
    METHODS user_rule_only_for_user FOR TESTING.
    METHODS expired_rule_ignored FOR TESTING.
    METHODS appenders_not_additive FOR TESTING.
    METHODS category_case_insensitive FOR TESTING.
    METHODS invalid_level_ignored FOR TESTING.
    METHODS split_appender_list FOR TESTING.
    METHODS normalize_categories FOR TESTING.
ENDCLASS.


CLASS ltc_config IMPLEMENTATION.

  METHOD setup.
    CLEAR m_rules.
  ENDMETHOD.

  METHOD add_rule.
    APPEND VALUE #( category  = i_category
                    uname     = i_uname
                    log_level = i_level
                    appenders = i_appenders
                    valid_to  = i_valid_to ) TO m_rules.
  ENDMETHOD.

  METHOD resolve.
    r_result = NEW zlog4abp_cl_config( i_rules = m_rules i_now = c_now )->resolve(
      i_category = i_category
      i_uname    = i_uname ).
  ENDMETHOD.

  METHOD default_without_rules.
    DATA(l_result) = resolve( 'ZSD.IMPORT' ).

    cl_abap_unit_assert=>assert_equals( act = l_result-level exp = zlog4abp_if_log=>c_level-warn ).
    cl_abap_unit_assert=>assert_equals( act = l_result-appenders exp = VALUE string_table( ( `EVENT` ) ( `BAL` ) ) ).
  ENDMETHOD.

  METHOD global_wildcard_rule.
    add_rule( i_category = '*' i_level = zlog4abp_if_log=>c_level-error ).

    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD.IMPORT' )-level exp = zlog4abp_if_log=>c_level-error ).
    cl_abap_unit_assert=>assert_equals( act = resolve( '' )-level exp = zlog4abp_if_log=>c_level-error ).
  ENDMETHOD.

  METHOD longest_prefix_wins.
    add_rule( i_category = '*' i_level = zlog4abp_if_log=>c_level-warn ).
    add_rule( i_category = 'ZSD' i_level = zlog4abp_if_log=>c_level-info ).
    add_rule( i_category = 'ZSD.IMPORT' i_level = zlog4abp_if_log=>c_level-debug ).

    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD.IMPORT.PRICING' )-level
                                        exp = zlog4abp_if_log=>c_level-debug ).
    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD.EXPORT' )-level
                                        exp = zlog4abp_if_log=>c_level-info ).
    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZMM' )-level
                                        exp = zlog4abp_if_log=>c_level-warn ).
  ENDMETHOD.

  METHOD segment_boundary.
    add_rule( i_category = '*' i_level = zlog4abp_if_log=>c_level-error ).
    add_rule( i_category = 'ZSD.IMP' i_level = zlog4abp_if_log=>c_level-trace ).

    " ZSD.IMP must not match ZSD.IMPORT, but matches its own children
    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD.IMPORT' )-level
                                        exp = zlog4abp_if_log=>c_level-error ).
    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD.IMP.X' )-level
                                        exp = zlog4abp_if_log=>c_level-trace ).
    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD.IMP' )-level
                                        exp = zlog4abp_if_log=>c_level-trace ).
    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD' )-level
                                        exp = zlog4abp_if_log=>c_level-error ).
  ENDMETHOD.

  METHOD user_beats_longer_global.
    add_rule( i_category = 'ZSD' i_uname = 'JDOE' i_level = zlog4abp_if_log=>c_level-trace ).
    add_rule( i_category = 'ZSD.IMPORT.PRICING' i_level = zlog4abp_if_log=>c_level-error ).

    cl_abap_unit_assert=>assert_equals( act = resolve( i_category = 'ZSD.IMPORT.PRICING' i_uname = 'JDOE' )-level
                                        exp = zlog4abp_if_log=>c_level-trace ).
  ENDMETHOD.

  METHOD user_rule_only_for_user.
    add_rule( i_category = 'ZSD' i_uname = 'JDOE' i_level = zlog4abp_if_log=>c_level-trace ).
    add_rule( i_category = 'ZSD.IMPORT.PRICING' i_level = zlog4abp_if_log=>c_level-error ).

    cl_abap_unit_assert=>assert_equals( act = resolve( i_category = 'ZSD.IMPORT.PRICING' i_uname = 'OTHER' )-level
                                        exp = zlog4abp_if_log=>c_level-error ).
    cl_abap_unit_assert=>assert_equals( act = resolve( i_category = 'ZMM' i_uname = 'JDOE' )-level
                                        exp = zlog4abp_if_log=>c_level-warn ).
  ENDMETHOD.

  METHOD expired_rule_ignored.
    add_rule( i_category = 'ZSD' i_uname = 'JDOE' i_level = zlog4abp_if_log=>c_level-trace
              i_valid_to = '20261105110000.0000000' ).
    add_rule( i_category = 'ZSD' i_level = zlog4abp_if_log=>c_level-info
              i_valid_to = '20261105130000.0000000' ).

    " The expired user rule is skipped; the still valid global rule applies
    cl_abap_unit_assert=>assert_equals( act = resolve( i_category = 'ZSD.IMPORT' i_uname = 'JDOE' )-level
                                        exp = zlog4abp_if_log=>c_level-info ).
  ENDMETHOD.

  METHOD appenders_not_additive.
    add_rule( i_category = '*' i_level = zlog4abp_if_log=>c_level-warn i_appenders = 'EVENT,BAL' ).
    add_rule( i_category = 'ZSD' i_level = zlog4abp_if_log=>c_level-debug i_appenders = 'MEMORY' ).

    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD.IMPORT' )-appenders
                                        exp = VALUE string_table( ( `MEMORY` ) ) ).
  ENDMETHOD.

  METHOD category_case_insensitive.
    add_rule( i_category = 'zsd.import' i_level = zlog4abp_if_log=>c_level-debug ).

    cl_abap_unit_assert=>assert_equals( act = resolve( 'Zsd.Import.Pricing' )-level
                                        exp = zlog4abp_if_log=>c_level-debug ).
  ENDMETHOD.

  METHOD invalid_level_ignored.
    add_rule( i_category = 'ZSD' i_level = 0 ).
    add_rule( i_category = 'ZMM' i_level = 9 ).

    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZSD' )-level exp = zlog4abp_cl_config=>c_default_level ).
    cl_abap_unit_assert=>assert_equals( act = resolve( 'ZMM' )-level exp = zlog4abp_cl_config=>c_default_level ).
  ENDMETHOD.

  METHOD split_appender_list.
    cl_abap_unit_assert=>assert_equals(
      act = zlog4abp_cl_config=>split_appenders( ' event, bal ,,EVENT' )
      exp = VALUE string_table( ( `EVENT` ) ( `BAL` ) ) ).
    cl_abap_unit_assert=>assert_initial( zlog4abp_cl_config=>split_appenders( '' ) ).
  ENDMETHOD.

  METHOD normalize_categories.
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_config=>normalize_category( ' zsd.import. ' )
                                        exp = `ZSD.IMPORT` ).
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_config=>normalize_category( 'ZSD.*' )
                                        exp = `ZSD` ).
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_config=>normalize_category( '' ) exp = `*` ).
    cl_abap_unit_assert=>assert_equals( act = zlog4abp_cl_config=>normalize_category( '*' ) exp = `*` ).
  ENDMETHOD.

ENDCLASS.
