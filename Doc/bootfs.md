BootFS
======

The boot "filesystem" is a structure with just 3 objects:

- the kernel
- the init program
- auxiliary data

All three objects are loaded into memory.
The kernel is a plain, position-independent binary with a 12-byte magic.
The init program uses a custom, architecture-specific executable format.
Auxiliary data is loaded at an arbitrary address.

The objects are aligned to a "page size".
Object must be aligned to the maximum of the host page size and disk sector size.

All integers are in little-endian format.

Header
------

| bytes | description        |
| -----:|:------------------ |
|  11:0 | "GeneSYS BOOT"     |
| 12:12 | page size          |
| 13:13 | (zero)             |
| 15:14 | architecture ID    |
| 19:16 | kernel page count  |
| 23:20 | init page count    |
| 27:24 | aux page count     |

The kernel entry point follows immediately after the header.

### Achitecture

#### x86-64

- ID: `0x8664`
- page size = 4096

##### Init program format

| bytes | description        |
| -----:|:------------------ |
|  11:0 | "GeneSYS EXEC"     |
| 13:12 | `0x8664`           |
| 15:14 | `0x0000`           |
| 23:16 | R  page count      |
| 31:24 | X  page count      |
| 39:32 | RW zeropage count  |
| 47:40 | RW page count      |
| 55:48 | entry address      |

The executable is loaded at address `1 << 46`.
There is a 2MiB guard page between the R, X and RW regions.

##### Entry state

All registers zeroed by default.
No stack is set up.

- `rdi`: "GeneSYS!"
- `rsi`: kernel info base

GPT GUID
--------

`0d05491d760c94eabe1064143d679334`
