# Boot process

The bootloader probes the hardware and selects the most appropriate kernel
to run on the system.
The bootloader attempts to perform as much setup work as possible to reduce
the amount of logic needed in the kernel.

As the bootloader needs to run only once at system start from a (typically)
well-known state it has lower requirements correctness. (unlike the kernel
which needs to be able to run forever).

## UEFI

As UEFI is complex and painful to interact with directly from assembly,
the bootloader is written in **Rust**.

## Kernel profiles

Refer to architecture pages for all available kernel variants.
This section documents common profiles.

### Minimal

The minimal kernel has the minimal configuration required to succesfully
run on a system. It does not take advantage of more advanced features to
keep the logic simple.
