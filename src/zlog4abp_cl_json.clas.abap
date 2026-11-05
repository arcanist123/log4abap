"! <p class="shorttext synchronized">log4abap: JSON serialization</p>
"! The only class in the framework that produces JSON. It walks the data with
"! RTTI, so it needs no serializer outside the kernel and runs on 7.50 as is.
"! <ul>
"! <li>Component names are written in lowercase.</li>
"! <li>Boolean-typed CHAR 1 fields (ABAP_BOOL, XFELD, ...) become true / false.</li>
"! <li>Numbers are unquoted; dates and times use ISO format.</li>
"! <li>Data references are followed; object references become the class name,
"!     exceptions become their chain.</li>
"! </ul>
"! The class is not final, so unit tests can substitute it.
CLASS zlog4abp_cl_json DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_pair,
        name  TYPE string,
        value TYPE string,
      END OF ty_pair,
      ty_pairs TYPE STANDARD TABLE OF ty_pair WITH DEFAULT KEY.

    "! Nesting depth after which values are written as null (protects against cycles)
    CONSTANTS c_max_depth TYPE i VALUE 32.
    "! Maximum number of exceptions written from one previous-chain
    CONSTANTS c_max_chain TYPE i VALUE 20.

    CLASS-METHODS class_constructor.

    "! Serialize any data object to JSON. Never raises an exception.
    "! @parameter i_data | Data object
    "! @parameter r_result | JSON text
    METHODS serialize
      IMPORTING i_data          TYPE any
      RETURNING VALUE(r_result) TYPE string.

    "! Serialize an exception and its PREVIOUS chain as a JSON array.
    "! @parameter i_exception | Exception, may be unbound
    "! @parameter r_result | JSON array, or initial if i_exception is unbound
    METHODS serialize_exception
      IMPORTING i_exception     TYPE REF TO cx_root
      RETURNING VALUE(r_result) TYPE string.

    "! Write a flat JSON object of string values
    "! @parameter i_pairs | Names and values, written in table order
    "! @parameter r_result | JSON object
    METHODS object_from_pairs
      IMPORTING i_pairs         TYPE ty_pairs
      RETURNING VALUE(r_result) TYPE string.

    "! Quote and escape a text as a JSON string
    "! @parameter i_text | Text
    "! @parameter r_result | JSON string literal including quotes
    METHODS quote
      IMPORTING i_text          TYPE csequence
      RETURNING VALUE(r_result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_escape,
        char        TYPE c LENGTH 1,
        replacement TYPE string,
      END OF ty_escape,
      ty_escapes TYPE STANDARD TABLE OF ty_escape WITH DEFAULT KEY.

    CLASS-DATA g_escapes TYPE ty_escapes.
    CLASS-DATA g_control_chars TYPE string.

    METHODS write_any
      IMPORTING i_data          TYPE any
                i_depth         TYPE i
      RETURNING VALUE(r_result) TYPE string.

    METHODS write_elementary
      IMPORTING i_data          TYPE any
                i_type          TYPE REF TO cl_abap_typedescr
      RETURNING VALUE(r_result) TYPE string.

    METHODS write_structure
      IMPORTING i_data          TYPE any
                i_type          TYPE REF TO cl_abap_typedescr
                i_depth         TYPE i
      RETURNING VALUE(r_result) TYPE string.

    METHODS write_table
      IMPORTING i_data          TYPE any
                i_depth         TYPE i
      RETURNING VALUE(r_result) TYPE string.

    METHODS write_reference
      IMPORTING i_data          TYPE any
                i_type          TYPE REF TO cl_abap_typedescr
                i_depth         TYPE i
      RETURNING VALUE(r_result) TYPE string.

    METHODS is_boolean_type
      IMPORTING i_type          TYPE REF TO cl_abap_typedescr
      RETURNING VALUE(r_result) TYPE abap_bool.

ENDCLASS.



CLASS zlog4abp_cl_json IMPLEMENTATION.


  METHOD class_constructor.
    DATA l_hex TYPE x LENGTH 1.
    DATA l_char TYPE c LENGTH 1.
    DATA l_replacement TYPE string.

    " Code points 1..31 are JSON control characters and must be escaped.
    DO 31 TIMES.
      l_hex = sy-index.
      l_char = cl_abap_conv_in_ce=>uccpi( sy-index ).
      CASE sy-index.
        WHEN 8.
          l_replacement = `\b`.
        WHEN 9.
          l_replacement = `\t`.
        WHEN 10.
          l_replacement = `\n`.
        WHEN 12.
          l_replacement = `\f`.
        WHEN 13.
          l_replacement = `\r`.
        WHEN OTHERS.
          l_replacement = |\\u00{ l_hex }|.
      ENDCASE.
      APPEND VALUE #( char = l_char replacement = l_replacement ) TO g_escapes.
      g_control_chars = g_control_chars && l_char.
    ENDDO.
  ENDMETHOD.


  METHOD serialize.
    TRY.
        r_result = write_any( i_data = i_data i_depth = 0 ).
      CATCH cx_root INTO DATA(l_error).
        r_result = `{"serialization_error":` && quote( l_error->get_text( ) ) && `}`.
    ENDTRY.
  ENDMETHOD.


  METHOD serialize_exception.
    DATA l_parts TYPE string_table.
    DATA l_program TYPE syrepid.
    DATA l_include TYPE syrepid.
    DATA l_line TYPE i.
    DATA l_t100 TYPE string.

    IF i_exception IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        DATA(l_current) = i_exception.
        WHILE l_current IS BOUND AND lines( l_parts ) < c_max_chain.
          CLEAR: l_program, l_include, l_line, l_t100.
          l_current->get_source_position(
            IMPORTING
              program_name = l_program
              include_name = l_include
              source_line  = l_line ).

          TRY.
              DATA(l_t100_message) = CAST if_t100_message( l_current ).
              l_t100 = |,"msgid":{ quote( l_t100_message->t100key-msgid ) }|
                    && |,"msgno":{ quote( |{ l_t100_message->t100key-msgno }| ) }|.
            CATCH cx_sy_move_cast_error.
              CLEAR l_t100.
          ENDTRY.

          APPEND `{"class":` && quote( cl_abap_typedescr=>describe_by_object_ref( l_current )->get_relative_name( ) )
              && `,"text":` && quote( l_current->get_text( ) )
              && `,"program":` && quote( l_program )
              && `,"include":` && quote( l_include )
              && `,"line":` && |{ l_line }|
              && l_t100
              && `}` TO l_parts.

          l_current = l_current->previous.
        ENDWHILE.
        r_result = `[` && concat_lines_of( table = l_parts sep = `,` ) && `]`.
      CATCH cx_root INTO DATA(l_error).
        r_result = `[{"serialization_error":` && quote( l_error->get_text( ) ) && `}]`.
    ENDTRY.
  ENDMETHOD.


  METHOD object_from_pairs.
    DATA l_parts TYPE string_table.

    LOOP AT i_pairs INTO DATA(pair).
      APPEND quote( pair-name ) && `:` && quote( pair-value ) TO l_parts.
    ENDLOOP.
    r_result = `{` && concat_lines_of( table = l_parts sep = `,` ) && `}`.
  ENDMETHOD.


  METHOD quote.
    r_result = i_text.
    IF r_result CA `\"`.
      REPLACE ALL OCCURRENCES OF `\` IN r_result WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN r_result WITH `\"`.
    ENDIF.
    IF r_result CA g_control_chars.
      LOOP AT g_escapes INTO DATA(escape).
        REPLACE ALL OCCURRENCES OF escape-char IN r_result WITH escape-replacement.
      ENDLOOP.
    ENDIF.
    r_result = `"` && r_result && `"`.
  ENDMETHOD.


  METHOD write_any.
    IF i_depth > c_max_depth.
      r_result = `null`.
      RETURN.
    ENDIF.

    DATA(l_type) = cl_abap_typedescr=>describe_by_data( i_data ).
    CASE l_type->kind.
      WHEN cl_abap_typedescr=>kind_elem.
        r_result = write_elementary( i_data = i_data i_type = l_type ).
      WHEN cl_abap_typedescr=>kind_struct.
        r_result = write_structure( i_data = i_data i_type = l_type i_depth = i_depth ).
      WHEN cl_abap_typedescr=>kind_table.
        r_result = write_table( i_data = i_data i_depth = i_depth ).
      WHEN cl_abap_typedescr=>kind_ref.
        r_result = write_reference( i_data = i_data i_type = l_type i_depth = i_depth ).
      WHEN OTHERS.
        r_result = `null`.
    ENDCASE.
  ENDMETHOD.


  METHOD write_elementary.
    FIELD-SYMBOLS <l_value> TYPE simple.
    DATA l_date TYPE d.
    DATA l_time TYPE t.

    ASSIGN i_data TO <l_value>.

    CASE i_type->type_kind.
      WHEN cl_abap_typedescr=>typekind_int
        OR cl_abap_typedescr=>typekind_int1
        OR cl_abap_typedescr=>typekind_int2
        OR cl_abap_typedescr=>typekind_int8
        OR cl_abap_typedescr=>typekind_packed
        OR cl_abap_typedescr=>typekind_decfloat
        OR cl_abap_typedescr=>typekind_decfloat16
        OR cl_abap_typedescr=>typekind_decfloat34
        OR cl_abap_typedescr=>typekind_float.
        r_result = |{ <l_value> }|.
      WHEN cl_abap_typedescr=>typekind_date.
        l_date = <l_value>.
        r_result = quote( |{ l_date DATE = ISO }| ).
      WHEN cl_abap_typedescr=>typekind_time.
        l_time = <l_value>.
        r_result = quote( |{ l_time TIME = ISO }| ).
      WHEN cl_abap_typedescr=>typekind_char.
        IF is_boolean_type( i_type ) = abap_true AND <l_value> = abap_true.
          r_result = `true`.
        ELSEIF is_boolean_type( i_type ) = abap_true AND <l_value> IS INITIAL.
          r_result = `false`.
        ELSE.
          r_result = quote( |{ <l_value> }| ).
        ENDIF.
      WHEN OTHERS.
        r_result = quote( |{ <l_value> }| ).
    ENDCASE.
  ENDMETHOD.


  METHOD write_structure.
    DATA l_parts TYPE string_table.
    FIELD-SYMBOLS <l_component> TYPE any.

    DATA(l_struct) = CAST cl_abap_structdescr( i_type ).
    LOOP AT l_struct->components INTO DATA(component).
      ASSIGN COMPONENT component-name OF STRUCTURE i_data TO <l_component>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      APPEND quote( to_lower( component-name ) ) && `:`
          && write_any( i_data = <l_component> i_depth = i_depth + 1 ) TO l_parts.
    ENDLOOP.
    r_result = `{` && concat_lines_of( table = l_parts sep = `,` ) && `}`.
  ENDMETHOD.


  METHOD write_table.
    DATA l_parts TYPE string_table.
    FIELD-SYMBOLS <l_table> TYPE ANY TABLE.

    ASSIGN i_data TO <l_table>.
    LOOP AT <l_table> ASSIGNING FIELD-SYMBOL(<line>).
      APPEND write_any( i_data = <line> i_depth = i_depth + 1 ) TO l_parts.
    ENDLOOP.
    r_result = `[` && concat_lines_of( table = l_parts sep = `,` ) && `]`.
  ENDMETHOD.


  METHOD write_reference.
    DATA l_object TYPE REF TO object.
    DATA l_data TYPE REF TO data.
    FIELD-SYMBOLS <l_target> TYPE any.

    DATA(l_referenced) = CAST cl_abap_refdescr( i_type )->get_referenced_type( ).
    IF l_referenced->kind = cl_abap_typedescr=>kind_class
        OR l_referenced->kind = cl_abap_typedescr=>kind_intf.
      l_object = i_data.
      IF l_object IS NOT BOUND.
        r_result = `null`.
      ELSEIF l_object IS INSTANCE OF cx_root.
        r_result = serialize_exception( CAST cx_root( l_object ) ).
      ELSE.
        r_result = quote( cl_abap_typedescr=>describe_by_object_ref( l_object )->get_relative_name( ) ).
      ENDIF.
    ELSE.
      l_data = i_data.
      IF l_data IS NOT BOUND.
        r_result = `null`.
      ELSE.
        ASSIGN l_data->* TO <l_target>.
        r_result = write_any( i_data = <l_target> i_depth = i_depth + 1 ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD is_boolean_type.
    IF i_type->length <> cl_abap_char_utilities=>charsize.
      RETURN.
    ENDIF.
    CASE i_type->get_relative_name( ).
      WHEN 'ABAP_BOOL' OR 'ABAP_BOOLEAN' OR 'XSDBOOLEAN' OR 'BOOLEAN' OR 'BOOLE_D' OR 'XFELD' OR 'FLAG'.
        r_result = abap_true.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
