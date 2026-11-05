"! <p class="shorttext synchronized">log4abap: logger factory and cache</p>
"! Entry point of the framework:
"! DATA(l_log) = zlog4abp_cl_factory=&gt;get( 'ZSD.IMPORT.PRICING' ).
"! Reads ZLOG4ABP_CONFIG once per internal session and caches one logger per
"! category and one appender instance per appender name, so buffers are shared
"! by all loggers of the session.
"! <br/>Appender name ABC maps to class ZLOG4ABP_CL_APPENDER_ABC. Names that
"! cannot be created are ignored. REGISTER_APPENDER( ) can supply instances
"! directly, for example in unit tests.
CLASS zlog4abp_cl_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Class name prefix of appenders created from configuration names
    CONSTANTS c_appender_class_prefix TYPE string VALUE `ZLOG4ABP_CL_APPENDER_`.

    "! Logger for a category. Never raises an exception; on internal failure
    "! a logger with level OFF is returned.
    "! @parameter i_category | Dot-separated category, e.g. ZSD.IMPORT.PRICING
    "! @parameter r_result | Cached logger
    CLASS-METHODS get
      IMPORTING i_category      TYPE csequence
      RETURNING VALUE(r_result) TYPE REF TO zlog4abp_if_log.

    "! Flush every appender instance of this internal session. Call at the end
    "! of processing and at milestones of long-running programs and jobs.
    CLASS-METHODS flush_all.

    "! Appender instance for a configuration name, created on first use
    "! @parameter i_name | Appender name, e.g. EVENT
    "! @parameter r_result | Instance, unbound if it cannot be created
    CLASS-METHODS get_appender
      IMPORTING i_name          TYPE csequence
      RETURNING VALUE(r_result) TYPE REF TO zlog4abp_if_appender.

    "! Use the given instance for an appender name. Loggers created afterwards
    "! receive it; existing loggers are discarded.
    "! @parameter i_name | Appender name, e.g. MEMORY
    "! @parameter i_appender | Instance
    CLASS-METHODS register_appender
      IMPORTING i_name     TYPE csequence
                i_appender TYPE REF TO zlog4abp_if_appender.

    "! Replace the configuration and discard all cached loggers and appenders.
    "! Intended for unit tests; productive code uses table ZLOG4ABP_CONFIG.
    "! @parameter i_config | Configuration; unbound to read the table again on next use
    CLASS-METHODS set_config
      IMPORTING i_config TYPE REF TO zlog4abp_cl_config OPTIONAL.

    "! Maximum payload length for loggers created afterwards
    "! @parameter i_max_payload | Length in characters
    CLASS-METHODS set_max_payload
      IMPORTING i_max_payload TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_logger,
        category TYPE string,
        logger   TYPE REF TO zlog4abp_if_log,
      END OF ty_logger,
      ty_loggers TYPE HASHED TABLE OF ty_logger WITH UNIQUE KEY category,
      BEGIN OF ty_appender,
        name     TYPE string,
        appender TYPE REF TO zlog4abp_if_appender,
      END OF ty_appender,
      ty_appender_cache TYPE HASHED TABLE OF ty_appender WITH UNIQUE KEY name.

    CLASS-DATA g_config TYPE REF TO zlog4abp_cl_config.
    CLASS-DATA g_loggers TYPE ty_loggers.
    CLASS-DATA g_appenders TYPE ty_appender_cache.
    CLASS-DATA g_max_payload TYPE i VALUE zlog4abp_cl_logger=>c_default_max_payload.

    CLASS-METHODS create_logger
      IMPORTING i_category      TYPE string
      RETURNING VALUE(r_result) TYPE REF TO zlog4abp_if_log.

    CLASS-METHODS create_appender
      IMPORTING i_name          TYPE string
      RETURNING VALUE(r_result) TYPE REF TO zlog4abp_if_appender.

ENDCLASS.



CLASS zlog4abp_cl_factory IMPLEMENTATION.


  METHOD get.
    TRY.
        DATA(l_category) = zlog4abp_cl_config=>normalize_category( i_category ).
        READ TABLE g_loggers INTO DATA(l_cached) WITH TABLE KEY category = l_category.
        IF sy-subrc = 0.
          r_result = l_cached-logger.
          RETURN.
        ENDIF.
        r_result = create_logger( l_category ).
        INSERT VALUE #( category = l_category logger = r_result ) INTO TABLE g_loggers.
      CATCH cx_root.
        r_result = NEW zlog4abp_cl_logger( i_category  = i_category
                                           i_threshold = zlog4abp_if_log=>c_level-off ).
    ENDTRY.
  ENDMETHOD.


  METHOD flush_all.
    LOOP AT g_appenders INTO DATA(entry) WHERE appender IS BOUND.
      TRY.
          entry-appender->flush( ).
        CATCH cx_root ##NO_HANDLER.
          " A failing appender must not affect the caller or the other appenders.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_appender.
    DATA(l_name) = to_upper( condense( val = i_name del = ` ` ) ).
    READ TABLE g_appenders INTO DATA(l_cached) WITH TABLE KEY name = l_name.
    IF sy-subrc = 0.
      r_result = l_cached-appender.
      RETURN.
    ENDIF.
    " Unbound results are cached too, so a bad name is tried only once.
    r_result = create_appender( l_name ).
    INSERT VALUE #( name = l_name appender = r_result ) INTO TABLE g_appenders.
  ENDMETHOD.


  METHOD register_appender.
    DATA(l_name) = to_upper( condense( val = i_name del = ` ` ) ).
    DELETE TABLE g_appenders WITH TABLE KEY name = l_name.
    INSERT VALUE #( name = l_name appender = i_appender ) INTO TABLE g_appenders.
    CLEAR g_loggers.
  ENDMETHOD.


  METHOD set_config.
    g_config = i_config.
    CLEAR: g_loggers, g_appenders.
  ENDMETHOD.


  METHOD set_max_payload.
    g_max_payload = i_max_payload.
    CLEAR g_loggers.
  ENDMETHOD.


  METHOD create_logger.
    DATA l_appenders TYPE zlog4abp_cl_logger=>ty_appenders.

    IF g_config IS NOT BOUND.
      g_config = zlog4abp_cl_config=>load( ).
    ENDIF.

    DATA(l_resolution) = g_config->resolve( i_category ).
    LOOP AT l_resolution-appenders INTO DATA(name).
      DATA(l_appender) = get_appender( name ).
      IF l_appender IS BOUND.
        APPEND l_appender TO l_appenders.
      ENDIF.
    ENDLOOP.

    r_result = NEW zlog4abp_cl_logger( i_category    = i_category
                                       i_threshold   = l_resolution-level
                                       i_appenders   = l_appenders
                                       i_max_payload = g_max_payload ).
  ENDMETHOD.


  METHOD create_appender.
    DATA l_object TYPE REF TO object.
    DATA l_class TYPE seoclsname.

    " Only plain names; the class name must fit into 30 characters.
    IF i_name IS INITIAL
        OR i_name CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'
        OR strlen( c_appender_class_prefix ) + strlen( i_name ) > 30.
      RETURN.
    ENDIF.

    l_class = c_appender_class_prefix && i_name.
    TRY.
        CREATE OBJECT l_object TYPE (l_class).
        r_result ?= l_object.
      CATCH cx_root.
        CLEAR r_result.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
