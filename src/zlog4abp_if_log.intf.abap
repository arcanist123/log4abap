"! <p class="shorttext synchronized">log4abap: logger API</p>
"! Obtain an instance with ZLOG4ABP_CL_FACTORY=>GET( 'ZSD.IMPORT.PRICING' ).
"! <br/>The level check is the first operation of every log method. A disabled
"! statement does not format, serialize or call the supplier. Do not pass
"! string templates to TRACE or DEBUG unless guarded by IS_ENABLED( ):
"! ABAP evaluates templates before the call.
INTERFACE zlog4abp_if_log PUBLIC.

  CONSTANTS:
    BEGIN OF c_level,
      trace TYPE int1 VALUE 1,
      debug TYPE int1 VALUE 2,
      info  TYPE int1 VALUE 3,
      warn  TYPE int1 VALUE 4,
      error TYPE int1 VALUE 5,
      off   TYPE int1 VALUE 6,
    END OF c_level.

  "! Log at TRACE level
  "! @parameter i_message | Message; {} placeholders are replaced by i_val1..i_val4, then i_args
  "! @parameter i_val1 | First placeholder value (elementary as text, structures/tables as JSON)
  "! @parameter i_val2 | Second placeholder value
  "! @parameter i_val3 | Third placeholder value
  "! @parameter i_val4 | Fourth placeholder value
  "! @parameter i_args | Further placeholder values, already as text
  "! @parameter i_data | Payload, serialized to JSON
  "! @parameter i_exception | Exception; the full previous-chain is recorded
  "! @parameter i_supplier | Deferred message and payload, only called when enabled
  METHODS trace
    IMPORTING
      i_message   TYPE csequence OPTIONAL
      i_val1      TYPE any OPTIONAL
      i_val2      TYPE any OPTIONAL
      i_val3      TYPE any OPTIONAL
      i_val4      TYPE any OPTIONAL
      i_args      TYPE string_table OPTIONAL
      i_data      TYPE any OPTIONAL
      i_exception TYPE REF TO cx_root OPTIONAL
      i_supplier  TYPE REF TO zlog4abp_if_supplier OPTIONAL
    PREFERRED PARAMETER i_message.

  "! Log at DEBUG level; parameters as in TRACE
  "! @parameter i_message | Message with {} placeholders
  "! @parameter i_val1 | First placeholder value
  "! @parameter i_val2 | Second placeholder value
  "! @parameter i_val3 | Third placeholder value
  "! @parameter i_val4 | Fourth placeholder value
  "! @parameter i_args | Further placeholder values
  "! @parameter i_data | Payload
  "! @parameter i_exception | Exception
  "! @parameter i_supplier | Deferred message and payload
  METHODS debug
    IMPORTING
      i_message   TYPE csequence OPTIONAL
      i_val1      TYPE any OPTIONAL
      i_val2      TYPE any OPTIONAL
      i_val3      TYPE any OPTIONAL
      i_val4      TYPE any OPTIONAL
      i_args      TYPE string_table OPTIONAL
      i_data      TYPE any OPTIONAL
      i_exception TYPE REF TO cx_root OPTIONAL
      i_supplier  TYPE REF TO zlog4abp_if_supplier OPTIONAL
    PREFERRED PARAMETER i_message.

  "! Log at INFO level; parameters as in TRACE
  "! @parameter i_message | Message with {} placeholders
  "! @parameter i_val1 | First placeholder value
  "! @parameter i_val2 | Second placeholder value
  "! @parameter i_val3 | Third placeholder value
  "! @parameter i_val4 | Fourth placeholder value
  "! @parameter i_args | Further placeholder values
  "! @parameter i_data | Payload
  "! @parameter i_exception | Exception
  "! @parameter i_supplier | Deferred message and payload
  METHODS info
    IMPORTING
      i_message   TYPE csequence OPTIONAL
      i_val1      TYPE any OPTIONAL
      i_val2      TYPE any OPTIONAL
      i_val3      TYPE any OPTIONAL
      i_val4      TYPE any OPTIONAL
      i_args      TYPE string_table OPTIONAL
      i_data      TYPE any OPTIONAL
      i_exception TYPE REF TO cx_root OPTIONAL
      i_supplier  TYPE REF TO zlog4abp_if_supplier OPTIONAL
    PREFERRED PARAMETER i_message.

  "! Log at WARN level; parameters as in TRACE. Captures the source position.
  "! @parameter i_message | Message with {} placeholders
  "! @parameter i_val1 | First placeholder value
  "! @parameter i_val2 | Second placeholder value
  "! @parameter i_val3 | Third placeholder value
  "! @parameter i_val4 | Fourth placeholder value
  "! @parameter i_args | Further placeholder values
  "! @parameter i_data | Payload
  "! @parameter i_exception | Exception
  "! @parameter i_supplier | Deferred message and payload
  METHODS warn
    IMPORTING
      i_message   TYPE csequence OPTIONAL
      i_val1      TYPE any OPTIONAL
      i_val2      TYPE any OPTIONAL
      i_val3      TYPE any OPTIONAL
      i_val4      TYPE any OPTIONAL
      i_args      TYPE string_table OPTIONAL
      i_data      TYPE any OPTIONAL
      i_exception TYPE REF TO cx_root OPTIONAL
      i_supplier  TYPE REF TO zlog4abp_if_supplier OPTIONAL
    PREFERRED PARAMETER i_message.

  "! Log at ERROR level; parameters as in TRACE. Captures the source position
  "! and flushes the logger's appenders immediately.
  "! @parameter i_message | Message with {} placeholders
  "! @parameter i_val1 | First placeholder value
  "! @parameter i_val2 | Second placeholder value
  "! @parameter i_val3 | Third placeholder value
  "! @parameter i_val4 | Fourth placeholder value
  "! @parameter i_args | Further placeholder values
  "! @parameter i_data | Payload
  "! @parameter i_exception | Exception
  "! @parameter i_supplier | Deferred message and payload
  METHODS error
    IMPORTING
      i_message   TYPE csequence OPTIONAL
      i_val1      TYPE any OPTIONAL
      i_val2      TYPE any OPTIONAL
      i_val3      TYPE any OPTIONAL
      i_val4      TYPE any OPTIONAL
      i_args      TYPE string_table OPTIONAL
      i_data      TYPE any OPTIONAL
      i_exception TYPE REF TO cx_root OPTIONAL
      i_supplier  TYPE REF TO zlog4abp_if_supplier OPTIONAL
    PREFERRED PARAMETER i_message.

  "! Log a T100 message, by default the one in SY-MSGID/SY-MSGNO/SY-MSGV1..4.
  "! The message key is stored on the event.
  "! @parameter i_level | Level; if initial, derived from i_msgty (E/A/X = ERROR, W = WARN, otherwise INFO)
  "! @parameter i_msgid | Message class
  "! @parameter i_msgty | Message type, used only to derive the level
  "! @parameter i_msgno | Message number
  "! @parameter i_msgv1 | Message variable 1
  "! @parameter i_msgv2 | Message variable 2
  "! @parameter i_msgv3 | Message variable 3
  "! @parameter i_msgv4 | Message variable 4
  "! @parameter i_data | Payload
  "! @parameter i_exception | Exception
  METHODS t100
    IMPORTING
      i_level     TYPE int1 OPTIONAL
      i_msgid     TYPE symsgid DEFAULT sy-msgid
      i_msgty     TYPE symsgty DEFAULT sy-msgty
      i_msgno     TYPE symsgno DEFAULT sy-msgno
      i_msgv1     TYPE symsgv DEFAULT sy-msgv1
      i_msgv2     TYPE symsgv DEFAULT sy-msgv2
      i_msgv3     TYPE symsgv DEFAULT sy-msgv3
      i_msgv4     TYPE symsgv DEFAULT sy-msgv4
      i_data      TYPE any OPTIONAL
      i_exception TYPE REF TO cx_root OPTIONAL.

  "! Whether a statement at the given level would be logged
  "! @parameter i_level | Level, see C_LEVEL
  "! @parameter r_result | abap_true if enabled
  METHODS is_enabled
    IMPORTING i_level         TYPE int1
    RETURNING VALUE(r_result) TYPE abap_bool.

  "! Category of this logger, e.g. ZSD.IMPORT.PRICING
  "! @parameter r_result | Category
  METHODS get_category
    RETURNING VALUE(r_result) TYPE string.

  "! Flush the buffered appenders of this logger
  METHODS flush.

ENDINTERFACE.
