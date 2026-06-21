Making a list of encountered bugs _in hardware / VMs_ because I'm running into too many of those.

## QEMU

### AMD-Vi IOMMU

#### NextLevel=0 is broken with hugepages (2M)

https://lists.nongnu.org/archive/html/qemu-devel/2026-06/msg03376.html

### Intel VT-d

#### Global Command Register: CFI bit is not checked

```c
    /* This is compatible mode. */
    if (addr.addr.int_mode != VTD_IR_INT_FORMAT_REMAP) {
        memcpy(translated, origin, sizeof(*origin));
        goto out;
    }
```

Checks the address but doesn't check the Global Command register.
