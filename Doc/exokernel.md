What is an exokernel?
=====================

An exokernel is a type of kernel that avoids _software abstractions_,
focusing entirely on _hardware_ abstractions and security.
The concept of an exokernel is orthogonal to other concepts such
as micro- or monolithic kernel: an exokernel can be a microkernel,
a monolithic kernel, something else or a hybrid thereof.

Software abstractions are provided by a _library OS_: a layer that
sits between the kernel and user applications.
The library OS is responsible for providing abstractions such as
filesystem drivers, scheduling, demand-paging ...

The set of sensible, minimal hardware abstractions varies with
architecture and platform. Hence, GeneSYS does not provide a
single kernel but a family of kernels with similar purposes and design.
See the [architecture](arch.md) chapter for more information.
