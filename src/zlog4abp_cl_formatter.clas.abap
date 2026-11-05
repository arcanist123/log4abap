"! <p class="shorttext synchronized">log4abap: message formatting</p>
"! Replaces {} placeholders and converts values to text.
"! <ul>
"! <li>Placeholders are replaced left to right with the given values.</li>
"! <li>A placeholder without a value stays as the literal {}.</li>
"! <li>Values without a placeholder are ignored.</li>
"! <li>Text inserted for a placeholder is never scanned again.</li>
"! </ul>
"! The class is not final, so unit tests can substitute it.
CLASS zlog4abp_cl_formatter DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_placeholder TYPE string VALUE `{}`.

    "! @parameter i_json | JSON serializer for structures and tables; a default one if not supplied
    METHODS constructor
      IMPORTING i_json TYPE REF TO zlog4abp_cl_json OPTIONAL.

    "! Replace the {} placeholders in i_pattern
    "! @parameter i_pattern | Pattern
    "! @parameter i_values | Values as text, in placeholder order
    "! @parameter r_result | Formatted message
    METHODS format
      IMPORTING i_pattern       TYPE csequence
                i_values        TYPE string_table
      RETURNING VALUE(r_result) TYPE string.

    "! Convert a value to text: elementary values as text (dates and times in
    "! ISO format), structures and tables as JSON, references dereferenced.
    "! @parameter i_value | Value
    "! @parameter r_result | Text
    METHODS to_text
      IMPORTING i_value         TYPE any
      RETURNING VALUE(r_result) TYPE string.

    "! Text of a T100 message
    "! @parameter i_msgid | Message class
    "! @parameter i_msgno | Message number
    "! @parameter i_msgv1 | Variable 1
    "! @parameter i_msgv2 | Variable 2
    "! @parameter i_msgv3 | Variable 3
    "! @parameter i_msgv4 | Variable 4
    "! @parameter r_result | Message text
    METHODS t100_text
      IMPORTING i_msgid         TYPE symsgid
                i_msgno         TYPE symsgno
                i_msgv1         TYPE symsgv OPTIONAL
                i_msgv2         TYPE symsgv OPTIONAL
                i_msgv3         TYPE symsgv OPTIONAL
                i_msgv4         TYPE symsgv OPTIONAL
      RETURNING VALUE(r_result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA m_json TYPE REF TO zlog4abp_cl_json.

ENDCLASS.



CLASS zlog4abp_cl_formatter IMPLEMENTATION.


  METHOD constructor.
    IF i_json IS BOUND.
      m_json = i_json.
    ELSE.
      m_json = NEW #( ).
    ENDIF.
  ENDMETHOD.


  METHOD format.
    DATA l_pattern TYPE string.
    DATA l_position TYPE i.
    DATA l_match TYPE i.
    DATA l_index TYPE i.

    l_pattern = i_pattern.
    DATA(l_count) = lines( i_values ).

    WHILE l_index < l_count.
      l_match = find( val = l_pattern sub = c_placeholder off = l_position ).
      IF l_match < 0.
        EXIT.
      ENDIF.
      l_index = l_index + 1.
      r_result = r_result
              && substring( val = l_pattern off = l_position len = l_match - l_position )
              && i_values[ l_index ].
      l_position = l_match + strlen( c_placeholder ).
    ENDWHILE.

    r_result = r_result && substring( val = l_pattern off = l_position ).
  ENDMETHOD.


  METHOD to_text.
    FIELD-SYMBOLS <l_value> TYPE simple.
    FIELD-SYMBOLS <l_target> TYPE any.
    DATA l_date TYPE d.
    DATA l_time TYPE t.
    DATA l_data TYPE REF TO data.
    DATA l_object TYPE REF TO object.

    TRY.
        DATA(l_type) = cl_abap_typedescr=>describe_by_data( i_value ).
        CASE l_type->kind.
          WHEN cl_abap_typedescr=>kind_elem.
            ASSIGN i_value TO <l_value>.
            CASE l_type->type_kind.
              WHEN cl_abap_typedescr=>typekind_date.
                l_date = <l_value>.
                r_result = |{ l_date DATE = ISO }|.
              WHEN cl_abap_typedescr=>typekind_time.
                l_time = <l_value>.
                r_result = |{ l_time TIME = ISO }|.
              WHEN OTHERS.
                r_result = |{ <l_value> }|.
            ENDCASE.

          WHEN cl_abap_typedescr=>kind_ref.
            DATA(l_referenced) = CAST cl_abap_refdescr( l_type )->get_referenced_type( ).
            IF l_referenced->kind = cl_abap_typedescr=>kind_class
                OR l_referenced->kind = cl_abap_typedescr=>kind_intf.
              l_object = i_value.
              IF l_object IS INSTANCE OF cx_root.
                r_result = CAST cx_root( l_object )->get_text( ).
              ELSEIF l_object IS BOUND.
                r_result = cl_abap_typedescr=>describe_by_object_ref( l_object )->get_relative_name( ).
              ENDIF.
            ELSE.
              l_data = i_value.
              IF l_data IS BOUND.
                ASSIGN l_data->* TO <l_target>.
                r_result = to_text( <l_target> ).
              ENDIF.
            ENDIF.

          WHEN OTHERS.
            r_result = m_json->serialize( i_value ).
        ENDCASE.
      CATCH cx_root.
        r_result = `?`.
    ENDTRY.
  ENDMETHOD.


  METHOD t100_text.
    IF i_msgid IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        MESSAGE ID i_msgid TYPE 'S' NUMBER i_msgno
          WITH i_msgv1 i_msgv2 i_msgv3 i_msgv4
          INTO r_result.
      CATCH cx_root.
        r_result = |{ i_msgid }{ i_msgno }|.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
