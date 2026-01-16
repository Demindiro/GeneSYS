Compute model
=============

One of the major goals of _GeneSYS_ is to be highly reliable:
it should survive severely malfunctioning OSes.
This is primarily to ensure the system can always be debugged
in a reasonable manner.

To make this practical, the kernel is modeled as a separate processor,
with its own region memory.
This memory is completely inaccessible to OSes,
reducing the risk of corruption.

```
        code  data  serial   <--- exclusive to kernel
            \  |   /
             Kernel
            /  |   \
          OS   OS  ...
```

The kernel communicates over a serial interface.
The kernel has exclusive access to this interface to ensure a communication
channel is always available.
