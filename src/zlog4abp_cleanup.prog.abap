*&---------------------------------------------------------------------*
*& log4abap: delete expired events from ZLOG4ABP_EVENT
*&---------------------------------------------------------------------*
*& Retention in days per level group; 0 keeps the events of that group.
*& Rows are deleted in packages, and each package is committed on its own.
*& In test mode the report only counts the rows it would delete.
*&
*& Needs authorization object ZLOG4ABP_R with activity 06 (03 in test mode).
*& Application logs of object ZLOG4ABP expire after the date set by the BAL
*& appender; delete them with SLG2 (report SBAL_DELETE).
*&---------------------------------------------------------------------*
REPORT zlog4abp_cleanup.

PARAMETERS p_debug TYPE i DEFAULT 3.
PARAMETERS p_info TYPE i DEFAULT 30.
PARAMETERS p_error TYPE i DEFAULT 180.
PARAMETERS p_pack TYPE i DEFAULT 1000.
PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.


CLASS lcl_main DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.
ENDCLASS.


CLASS lcl_main IMPLEMENTATION.

  METHOD run.
    DATA l_counts TYPE zlog4abp_cl_cleanup=>ty_counts.

    DATA(l_cleanup) = NEW zlog4abp_cl_cleanup( i_package_size = p_pack ).
    TRY.
        l_counts = l_cleanup->run( i_retention = VALUE #( trace_debug = p_debug
                                                          info_warn   = p_info
                                                          error       = p_error )
                                   i_test      = p_test ).
      CATCH zlog4abp_cx_not_authorized INTO DATA(l_auth_error).
        DATA(l_text) = l_auth_error->get_text( ).
        MESSAGE l_text TYPE 'E'.
      CATCH cx_sy_open_sql_db INTO DATA(l_db_error).
        l_text = l_db_error->get_text( ).
        MESSAGE l_text TYPE 'E'.
    ENDTRY.

    IF p_test = abap_true.
      WRITE / 'Test mode: nothing deleted. Rows that would be deleted:'.
    ELSE.
      WRITE / 'Rows deleted:'.
    ENDIF.
    ULINE.
    LOOP AT l_counts INTO DATA(count).
      DATA(l_level) = zlog4abp_cl_formatter=>level_name( count-level ).
      IF count-days > 0.
        DATA(l_cutoff) = zlog4abp_cl_reader=>format_timestamp( count-cutoff ).
        WRITE: / l_level, count-days, 'days, before', l_cutoff, count-rows.
      ELSE.
        WRITE: / l_level, 'kept (retention 0)'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


AT SELECTION-SCREEN.
  IF p_pack < 1.
    MESSAGE 'Package size must be at least 1' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  lcl_main=>run( ).
