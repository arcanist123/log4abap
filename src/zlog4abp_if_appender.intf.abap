"! <p class="shorttext synchronized">log4abap: appender contract</p>
"! An appender receives enabled events from loggers. The framework calls every
"! method inside TRY ... CATCH cx_root, so a failing appender never stops the
"! application or the other appenders. Appenders must not log through the
"! framework themselves.
"! <br/>Appender ABC is created by the factory as class ZLOG4ABP_CL_APPENDER_ABC
"! (public, no mandatory constructor parameters) when configuration names ABC.
INTERFACE zlog4abp_if_appender PUBLIC.

  TYPES ty_events TYPE STANDARD TABLE OF zlog4abp_s_event WITH DEFAULT KEY.

  "! Receive one event
  "! @parameter i_event | The event
  METHODS append
    IMPORTING i_event TYPE zlog4abp_s_event.

  "! Write any buffered events
  METHODS flush.

ENDINTERFACE.
