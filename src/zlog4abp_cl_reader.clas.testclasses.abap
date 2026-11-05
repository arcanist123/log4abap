"! Returns canned rows instead of reading the database and records the selection.
CLASS ltd_reader DEFINITION FINAL FOR TESTING INHERITING FROM zlog4abp_cl_reader.
  PUBLIC SECTION.
    METHODS set_rows IMPORTING i_rows TYPE ty_rows.
    METHODS set_authorized IMPORTING i_authorized TYPE abap_bool.
    METHODS get_selection RETURNING VALUE(r_result) TYPE ty_selection.
  PROTECTED SECTION.
    METHODS select_rows REDEFINITION.
    METHODS check_authority REDEFINITION.
  PRIVATE SECTION.
    DATA m_rows TYPE ty_rows.
    DATA m_authorized TYPE abap_bool VALUE abap_true.
    DATA m_selection TYPE ty_selection.
ENDCLASS.

CLASS ltd_reader IMPLEMENTATION.
  METHOD select_rows.
    m_selection = i_selection.
    LOOP AT m_rows INTO DATA(row) TO i_selection-max_rows.
      APPEND row TO r_result.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_authority.
    r_result = m_authorized.
  ENDMETHOD.

  METHOD set_rows.
    m_rows = i_rows.
  ENDMETHOD.

  METHOD set_authorized.
    m_authorized = i_authorized.
  ENDMETHOD.

  METHOD get_selection.
    r_result = m_selection.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_reader DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA m_cut TYPE REF TO ltd_reader.

    METHODS setup.
    METHODS category_on_segments FOR TESTING RAISING cx_static_check.
    METHODS category_all FOR TESTING RAISING cx_static_check.
    METHODS category_escapes_pattern FOR TESTING RAISING cx_static_check.
    METHODS timestamp_iso FOR TESTING RAISING cx_static_check.
    METHODS timestamp_initial FOR TESTING RAISING cx_static_check.
    METHODS filter_to_selection FOR TESTING RAISING cx_static_check.
    METHODS time_range_open_end FOR TESTING RAISING cx_static_check.
    METHODS default_max_rows FOR TESTING RAISING cx_static_check.
    METHODS more_rows_flagged FOR TESTING RAISING cx_static_check.
    METHODS not_authorized FOR TESTING RAISING cx_static_check.
    METHODS json_fields FOR TESTING RAISING cx_static_check.
    METHODS json_without_payload FOR TESTING RAISING cx_static_check.
    METHODS json_raw_payload FOR TESTING RAISING cx_static_check.
    METHODS json_stored_truncation FOR TESTING RAISING cx_static_check.
    METHODS json_reader_truncation FOR TESTING RAISING cx_static_check.
    METHODS read_json_lines FOR TESTING RAISING cx_static_check.
    METHODS split_short_line FOR TESTING RAISING cx_static_check.
    METHODS split_long_line FOR TESTING RAISING cx_static_check.
    METHODS split_trailing_blank FOR TESTING RAISING cx_static_check.

    METHODS sample_row
      RETURNING VALUE(r_result) TYPE zlog4abp_cl_reader=>ty_row.
    METHODS join
      IMPORTING i_lines         TYPE string_table
      RETURNING VALUE(r_result) TYPE string.
ENDCLASS.


CLASS ltc_reader IMPLEMENTATION.

  METHOD setup.
    m_cut = NEW #( ).
  ENDMETHOD.

  METHOD sample_row.
    r_result = VALUE #(
      event_id       = '0242AC1100111FE1B6A0B6F5A152A06A'
      run_id         = '0242AC1100111FE1B6A0B6F5A152A000'
      event_ts       = '20261105090500.125'
      seq_no         = 7
      log_level      = zlog4abp_if_log=>c_level-error
      category       = 'ZSD.IMPORT'
      uname          = 'JDOE'
      program_name   = 'ZSD_IMPORT'
      msg_text       = `Posting "failed"`
      context_json   = `{"order":"42"}`
      exception_json = `[{"class":"CX_X"}]` ).
  ENDMETHOD.

  METHOD join.
    LOOP AT i_lines INTO DATA(line).
      IF sy-tabix = 1.
        r_result = line.
      ELSE.
        r_result = r_result && substring( val = line off = 1 ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD category_on_segments.
    DATA(l_range) = zlog4abp_cl_reader=>category_range( 'zsd.import.' ).
    cl_abap_unit_assert=>assert_equals(
      act = l_range
      exp = VALUE zlog4abp_cl_reader=>ty_categories( ( sign = 'I' option = 'EQ' low = 'ZSD.IMPORT' )
                                                     ( sign = 'I' option = 'CP' low = 'ZSD.IMPORT.*' ) ) ).
    " The range treats ZSD.IMPORTS as a different category
    cl_abap_unit_assert=>assert_false( xsdbool( CONV zlog4abp_category( 'ZSD.IMPORTS' ) IN l_range ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( CONV zlog4abp_category( 'ZSD.IMPORT.PRICING' ) IN l_range ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( CONV zlog4abp_category( 'ZSD.IMPORT' ) IN l_range ) ).
  ENDMETHOD.

  METHOD category_all.
    cl_abap_unit_assert=>assert_initial( zlog4abp_cl_reader=>category_range( '' ) ).
    cl_abap_unit_assert=>assert_initial( zlog4abp_cl_reader=>category_range( '*' ) ).
  ENDMETHOD.

  METHOD category_escapes_pattern.
    DATA(l_range) = zlog4abp_cl_reader=>category_range( 'Z+A' ).
    cl_abap_unit_assert=>assert_equals( act = l_range[ 2 ]-low exp = 'Z#+A.*' ).
    cl_abap_unit_assert=>assert_false( xsdbool( CONV zlog4abp_category( 'ZXA.B' ) IN l_range ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( CONV zlog4abp_category( 'Z+A.B' ) IN l_range ) ).
  ENDMETHOD.

  METHOD timestamp_iso.
    cl_abap_unit_assert=>assert_equals(
      act = zlog4abp_cl_reader=>format_timestamp( '20261105090500.125' )
      exp = `2026-11-05T09:05:00.125Z` ).
    cl_abap_unit_assert=>assert_equals(
      act = zlog4abp_cl_reader=>format_timestamp( '20260101000000' )
      exp = `2026-01-01T00:00:00.000Z` ).
  ENDMETHOD.

  METHOD timestamp_initial.
    cl_abap_unit_assert=>assert_initial( zlog4abp_cl_reader=>format_timestamp( 0 ) ).
  ENDMETHOD.

  METHOD filter_to_selection.
    m_cut->read( VALUE #( run_id       = '0242AC1100111FE1B6A0B6F5A152A000'
                          from_ts      = '20261105000000'
                          to_ts        = '20261105235959'
                          min_level    = zlog4abp_if_log=>c_level-warn
                          category     = 'ZSD'
                          job_name     = 'NIGHTLY'
                          with_payload = abap_true
                          max_rows     = 10 ) ).
    DATA(l_selection) = m_cut->get_selection( ).

    cl_abap_unit_assert=>assert_equals( act = l_selection-run_ids[ 1 ]-low exp = '0242AC1100111FE1B6A0B6F5A152A000' ).
    cl_abap_unit_assert=>assert_equals( act = l_selection-timestamps[ 1 ]-option exp = 'BT' ).
    cl_abap_unit_assert=>assert_equals( act = l_selection-timestamps[ 1 ]-high exp = '20261105235959' ).
    cl_abap_unit_assert=>assert_equals( act = l_selection-levels[ 1 ]-option exp = 'GE' ).
    cl_abap_unit_assert=>assert_equals( act = l_selection-levels[ 1 ]-low exp = zlog4abp_if_log=>c_level-warn ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_selection-categories ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_selection-job_names[ 1 ]-low exp = 'NIGHTLY' ).
    cl_abap_unit_assert=>assert_true( l_selection-with_payload ).
    cl_abap_unit_assert=>assert_equals( act = l_selection-max_rows exp = 11 ).
  ENDMETHOD.

  METHOD time_range_open_end.
    m_cut->read( VALUE #( from_ts = '20261105000000' ) ).
    DATA(l_selection) = m_cut->get_selection( ).

    cl_abap_unit_assert=>assert_equals( act = l_selection-timestamps[ 1 ]-option exp = 'GE' ).
    cl_abap_unit_assert=>assert_initial( l_selection-run_ids ).
    cl_abap_unit_assert=>assert_initial( l_selection-levels ).
    cl_abap_unit_assert=>assert_initial( l_selection-categories ).
    cl_abap_unit_assert=>assert_initial( l_selection-job_names ).
    cl_abap_unit_assert=>assert_false( l_selection-with_payload ).
  ENDMETHOD.

  METHOD default_max_rows.
    m_cut->read( VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals( act = m_cut->get_selection( )-max_rows
                                        exp = zlog4abp_cl_reader=>c_default_max_rows + 1 ).
  ENDMETHOD.

  METHOD more_rows_flagged.
    m_cut->set_rows( VALUE #( ( seq_no = 1 ) ( seq_no = 2 ) ( seq_no = 3 ) ) ).

    DATA(l_result) = m_cut->read( VALUE #( max_rows = 2 ) ).
    cl_abap_unit_assert=>assert_true( l_result-more ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_result-rows ) exp = 2 ).

    l_result = m_cut->read( VALUE #( max_rows = 3 ) ).
    cl_abap_unit_assert=>assert_false( l_result-more ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_result-rows ) exp = 3 ).
  ENDMETHOD.

  METHOD not_authorized.
    m_cut->set_authorized( abap_false ).
    TRY.
        m_cut->read( VALUE #( ) ).
        cl_abap_unit_assert=>fail( 'Exception expected' ).
      CATCH zlog4abp_cx_not_authorized INTO DATA(l_error).
        cl_abap_unit_assert=>assert_equals( act = l_error->get_activity( ) exp = '03' ).
        cl_abap_unit_assert=>assert_char_cp( act = l_error->get_text( ) exp = '*ZLOG4ABP_R*03*' ).
    ENDTRY.
  ENDMETHOD.

  METHOD json_fields.
    DATA(l_json) = m_cut->to_json( sample_row( ) ).

    cl_abap_unit_assert=>assert_equals(
      act = l_json
      exp = `{"event_id":"0242AC1100111FE1B6A0B6F5A152A06A","run_id":"0242AC1100111FE1B6A0B6F5A152A000",`
         && `"ts":"2026-11-05T09:05:00.125Z","seq_no":7,"level":"ERROR","category":"ZSD.IMPORT",`
         && `"message":"Posting \"failed\"","msgid":null,"msgno":null,"source_pos":null,"user":"JDOE",`
         && `"program":"ZSD_IMPORT","job_name":null,"job_count":null,"context":{"order":"42"},`
         && `"exception":[{"class":"CX_X"}],"has_payload":false,"payload_len":0,"payload":null,`
         && `"payload_truncated":false}` ).
  ENDMETHOD.

  METHOD json_without_payload.
    DATA(l_row) = sample_row( ).
    l_row-has_payload = abap_true.
    l_row-payload_len = 7.
    l_row-payload_json = `{"a":1}`.
    CLEAR: l_row-context_json, l_row-exception_json.

    DATA(l_json) = m_cut->to_json( l_row ).
    cl_abap_unit_assert=>assert_char_cp( act = l_json exp = '*"context":{},"exception":[],*' ).
    cl_abap_unit_assert=>assert_char_cp( act = l_json exp = '*"has_payload":true,"payload_len":7,"payload":null,*' ).
  ENDMETHOD.

  METHOD json_raw_payload.
    DATA(l_row) = sample_row( ).
    l_row-has_payload = abap_true.
    l_row-payload_len = 7.
    l_row-payload_json = `{"a":1}`.
    l_row-msgid = 'ZSD'.
    l_row-msgno = '012'.

    DATA(l_json) = m_cut->to_json( i_row = l_row i_with_payload = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = l_json exp = '*"payload":{"a":1},"payload_truncated":false}' ).
    cl_abap_unit_assert=>assert_char_cp( act = l_json exp = '*"msgid":"ZSD","msgno":"012",*' ).
  ENDMETHOD.

  METHOD json_stored_truncation.
    DATA(l_row) = sample_row( ).
    l_row-has_payload = abap_true.
    l_row-payload_trunc = abap_true.
    l_row-payload_len = 3000.
    l_row-payload_json = `{"text":"abc`.

    DATA(l_json) = m_cut->to_json( i_row = l_row i_with_payload = abap_true ).
    cl_abap_unit_assert=>assert_char_cp(
      act = l_json
      exp = '*"payload_len":3000,"payload":"{\"text\":\"abc","payload_truncated":true}' ).
  ENDMETHOD.

  METHOD json_reader_truncation.
    DATA(l_row) = sample_row( ).
    l_row-has_payload = abap_true.
    l_row-payload_len = 13.
    l_row-payload_json = `{"text":"ab"}`.

    DATA(l_json) = m_cut->to_json( i_row = l_row i_with_payload = abap_true i_max_payload = 5 ).
    cl_abap_unit_assert=>assert_char_cp(
      act = l_json
      exp = '*"payload_len":13,"payload":"{\"tex","payload_truncated":true}' ).
  ENDMETHOD.

  METHOD read_json_lines.
    m_cut->set_rows( VALUE #( ( sample_row( ) ) ( sample_row( ) ) ) ).
    DATA(l_lines) = m_cut->read_json( VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( l_lines ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = l_lines[ 1 ] exp = m_cut->to_json( sample_row( ) ) ).
  ENDMETHOD.

  METHOD split_short_line.
    DATA(l_lines) = zlog4abp_cl_reader=>split_line( i_line = `{"a":1}` i_width = 255 ).
    cl_abap_unit_assert=>assert_equals( act = l_lines exp = VALUE string_table( ( `{"a":1}` ) ) ).
  ENDMETHOD.

  METHOD split_long_line.
    DATA l_line TYPE string.

    DO 60 TIMES.
      l_line = l_line && |"k{ sy-index }":"v",|.
    ENDDO.
    l_line = `{` && l_line && `"end":1}`.

    DATA(l_lines) = zlog4abp_cl_reader=>split_line( i_line = l_line i_width = 100 ).
    cl_abap_unit_assert=>assert_true( xsdbool( lines( l_lines ) > 1 ) ).
    LOOP AT l_lines INTO DATA(line).
      cl_abap_unit_assert=>assert_true( xsdbool( strlen( line ) <= 100 ) ).
      IF sy-tabix > 1.
        cl_abap_unit_assert=>assert_equals( act = substring( val = line len = 1 )
                                            exp = zlog4abp_cl_reader=>c_continuation ).
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = join( l_lines ) exp = l_line ).
  ENDMETHOD.

  METHOD split_trailing_blank.
    " Width 16 gives chunks of 10 characters; the 10th character is a blank.
    DATA(l_lines) = zlog4abp_cl_reader=>split_line( i_line = `{"t":"abc defghij"}` i_width = 16 ).
    cl_abap_unit_assert=>assert_equals( act = l_lines[ 1 ] exp = `{"t":"abc\u0020` ).
    cl_abap_unit_assert=>assert_equals( act = join( l_lines ) exp = `{"t":"abc\u0020defghij"}` ).
    LOOP AT l_lines INTO DATA(line).
      cl_abap_unit_assert=>assert_true( xsdbool( strlen( line ) <= 16 ) ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
