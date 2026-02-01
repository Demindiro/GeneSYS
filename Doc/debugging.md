Debugging
=========

The primary interface to debug the kernel is an UART.
A packet-based protocol is used.

All packets are encoded using COBS.
All packets are suffixed with the CRC32C of the contents *before* encoding.

The interface follows a call/return model:
responses are only sent upon request.
This interface is not intended nor suitable for real-time communications.

All integers are in little-endian format,
i.e. low bytes are sent before high bytes.


COBS
----

COBS is very simple. For every packet:

- prepend a byte indicating the offset to the first 0 byte (or EOS).
- replace every zero byte with an offset to the next 0 byte (or EOS).
- if there is no 0 byte (or EOS) within the next 254 bytes,
  insert `0xff` and insert a 0 byte after the 254 bytes.
- when done, append a 0 byte as delimiter

Example:
```
1.      de ad 00 ba ca fe
2.   03 de ad 00 ba ca fe
      '-------^
3.   03 de ad 04 ba ca fe
               '----------^
4.   03 de ad 04 ba ca fe 00

1.      cc cc .. cc cc cc
2.   ff cc cc .. 00 cc cc cc
3.    '----------^
4.   ff cc cc .. 04 cc cc cc
                  '----------^
5.   ff cc cc .. 04 cc cc cc 00
```


Commands
--------

Commands are prefixed with a single byte indicating which command.

### 0. Echo

Request: arbitrary data

Response: same data

### 1. Identify

Request: none

Response:
- `u16` with protocol version (`0x0000` as of writing).
- `u16` identifying the architecture. See architecture-specific documentation.
- arbitrary UTF-8 string. Intended for humans only.

### 2. Read syslog

Request:
- a `u64` timestamp which *should* represent nanoseconds since boot.

Response:
- a `u64` timestamp or `-1` if no further log entries.
  if `-1`, no further data in the packet.
- a `u32` describing the source of the log entry.
  The exact meaning depends on the platform.
- an arbitrary byte string.
  It *should* be valid UTF-8.

### 3. Send message

Request:
- a `u32` describing the target of the message.
- an arbitrary byte string.

Response:
- a `u8` describing whether the packet was succesfully delivered.

### 4. Read bytes

Request:
- a `u128` describing the address to read.
- a `u16` describing the amount of bytes to read (maximum 1024).

Response:
- arbitrary bytes matching the requested length.

### 5. Write bytes

Request:
- a `u128` describing the address to write to.
- arbitrary data.

### 6. Load u8
### 7. Store u8
### 8. Load u16
### 9. Store u16
### 10. Load u32
### 11. Store u32
### 12. Load u64
### 13. Store u64
### 14. Load u128
### 15. Store u128
