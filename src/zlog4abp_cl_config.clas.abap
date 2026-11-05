"! <p class="shorttext synchronized">log4abap: configuration rules and resolution</p>
"! Resolves level and appenders for a category and user from ZLOG4ABP_CONFIG rows:
"! <ol>
"! <li>Expired rows (VALID_TO in the past) are ignored.</li>
"! <li>Rows of the user are searched from the longest matching category prefix down to *.</li>
"! <li>Then rows of user * in the same order.</li>
"! <li>Otherwise the built-in default applies: WARN with EVENT,BAL.</li>
"! </ol>
"! Prefixes match on full segments only: rule ZSD.IMP does not match ZSD.IMPORT.
"! The first matching row supplies both level and appenders (no additivity).
CLASS zlog4abp_cl_config DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_rules TYPE STANDARD TABLE OF zlog4abp_config WITH DEFAULT KEY.
    TYPES:
      BEGIN OF ty_resolution,
        level     TYPE int1,
        appenders TYPE string_table,
      END OF ty_resolution.

    CONSTANTS c_wildcard TYPE c LENGTH 1 VALUE '*'.
    CONSTANTS c_separator TYPE c LENGTH 1 VALUE '.'.
    CONSTANTS c_default_level TYPE int1 VALUE zlog4abp_if_log=>c_level-warn.
    CONSTANTS c_default_appenders TYPE string VALUE `EVENT,BAL`.

    "! Read all rules from table ZLOG4ABP_CONFIG. Never raises an exception;
    "! if the table cannot be read, only the built-in default applies.
    "! @parameter r_result | Configuration
    CLASS-METHODS load
      RETURNING VALUE(r_result) TYPE REF TO zlog4abp_cl_config.

    "! Normalize a category: uppercase, without blanks or a trailing separator
    "! @parameter i_category | Category
    "! @parameter r_result | Normalized category, * if empty
    CLASS-METHODS normalize_category
      IMPORTING i_category      TYPE csequence
      RETURNING VALUE(r_result) TYPE string.

    "! Split a comma-separated appender list into uppercase names
    "! @parameter i_appenders | e.g. EVENT,BAL
    "! @parameter r_result | Names without duplicates, in list order
    CLASS-METHODS split_appenders
      IMPORTING i_appenders     TYPE csequence
      RETURNING VALUE(r_result) TYPE string_table.

    "! @parameter i_rules | Configuration rows
    "! @parameter i_now | Time used for the expiry check; current UTC time if initial
    METHODS constructor
      IMPORTING i_rules TYPE ty_rules
                i_now   TYPE timestampl OPTIONAL.

    "! Resolve level and appenders
    "! @parameter i_category | Category, e.g. ZSD.IMPORT.PRICING
    "! @parameter i_uname | User
    "! @parameter r_result | Level and appender names
    METHODS resolve
      IMPORTING i_category      TYPE csequence
                i_uname         TYPE syuname DEFAULT sy-uname
      RETURNING VALUE(r_result) TYPE ty_resolution.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_rule,
        uname     TYPE syuname,
        category  TYPE string,
        level     TYPE int1,
        appenders TYPE string_table,
      END OF ty_rule,
      ty_rule_index TYPE HASHED TABLE OF ty_rule WITH UNIQUE KEY uname category.

    DATA m_rules TYPE ty_rule_index.

    METHODS prefixes
      IMPORTING i_category      TYPE string
      RETURNING VALUE(r_result) TYPE string_table.

ENDCLASS.



CLASS zlog4abp_cl_config IMPLEMENTATION.


  METHOD load.
    DATA l_rules TYPE ty_rules.

    TRY.
        SELECT category, uname, log_level, appenders, valid_to
          FROM zlog4abp_config
          INTO CORRESPONDING FIELDS OF TABLE @l_rules. "#EC CI_SUBRC
      CATCH cx_root.
        CLEAR l_rules.
    ENDTRY.
    r_result = NEW #( i_rules = l_rules ).
  ENDMETHOD.


  METHOD normalize_category.
    r_result = to_upper( condense( val = i_category del = ` ` ) ).
    " Trailing separators and wildcards are dropped: ZSD.* and ZSD. mean ZSD
    WHILE strlen( r_result ) > 1
        AND substring( val = r_result off = strlen( r_result ) - 1 ) CA '.*'.
      r_result = substring( val = r_result len = strlen( r_result ) - 1 ).
    ENDWHILE.
    IF r_result IS INITIAL.
      r_result = c_wildcard.
    ENDIF.
  ENDMETHOD.


  METHOD split_appenders.
    DATA l_names TYPE string_table.

    SPLIT to_upper( i_appenders ) AT ',' INTO TABLE l_names.
    LOOP AT l_names INTO DATA(name).
      name = condense( val = name del = ` ` ).
      IF name IS NOT INITIAL AND NOT line_exists( r_result[ table_line = name ] ).
        APPEND name TO r_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD constructor.
    DATA l_now TYPE timestampl.

    l_now = i_now.
    IF l_now IS INITIAL.
      GET TIME STAMP FIELD l_now.
    ENDIF.

    LOOP AT i_rules INTO DATA(row).
      IF row-valid_to IS NOT INITIAL AND row-valid_to < l_now.
        CONTINUE.
      ENDIF.
      IF row-log_level < zlog4abp_if_log=>c_level-trace OR row-log_level > zlog4abp_if_log=>c_level-off.
        CONTINUE.
      ENDIF.
      DATA(l_rule) = VALUE ty_rule(
        uname     = to_upper( row-uname )
        category  = normalize_category( row-category )
        level     = row-log_level
        appenders = split_appenders( row-appenders ) ).
      IF l_rule-uname IS INITIAL.
        l_rule-uname = c_wildcard.
      ENDIF.
      INSERT l_rule INTO TABLE m_rules.
    ENDLOOP.
  ENDMETHOD.


  METHOD resolve.
    DATA l_users TYPE STANDARD TABLE OF syuname WITH DEFAULT KEY.

    DATA(l_prefixes) = prefixes( normalize_category( i_category ) ).

    IF i_uname IS NOT INITIAL AND i_uname <> c_wildcard.
      APPEND i_uname TO l_users.
    ENDIF.
    APPEND c_wildcard TO l_users.

    LOOP AT l_users INTO DATA(user).
      LOOP AT l_prefixes INTO DATA(prefix).
        READ TABLE m_rules INTO DATA(l_rule) WITH TABLE KEY uname = user category = prefix.
        IF sy-subrc = 0.
          r_result-level = l_rule-level.
          r_result-appenders = l_rule-appenders.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    r_result-level = c_default_level.
    r_result-appenders = split_appenders( c_default_appenders ).
  ENDMETHOD.


  METHOD prefixes.
    DATA l_segments TYPE string_table.
    DATA l_prefix TYPE string.

    IF i_category <> c_wildcard.
      SPLIT i_category AT c_separator INTO TABLE l_segments.
      LOOP AT l_segments INTO DATA(segment).
        IF l_prefix IS INITIAL.
          l_prefix = segment.
        ELSE.
          l_prefix = l_prefix && c_separator && segment.
        ENDIF.
        INSERT l_prefix INTO r_result INDEX 1.
      ENDLOOP.
    ENDIF.
    APPEND c_wildcard TO r_result.
  ENDMETHOD.

ENDCLASS.
