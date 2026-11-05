"! <p class="shorttext synchronized">log4abap: deferred message and payload</p>
"! Implement this interface when building the message or payload is expensive.
"! The logger calls it only when the level is enabled.
INTERFACE zlog4abp_if_supplier PUBLIC.

  "! Message text. If not initial, it replaces the I_MESSAGE of the log call.
  "! It may contain {} placeholders.
  "! @parameter r_result | Message text
  METHODS get_message
    RETURNING VALUE(r_result) TYPE string.

  "! Payload. Used only when the log call passes no I_DATA.
  "! @parameter r_result | Reference to the payload, or unbound for none
  METHODS get_data
    RETURNING VALUE(r_result) TYPE REF TO data.

ENDINTERFACE.
