CR0.PE = 1 shl  0
CR0.MP = 1 shl  1
CR0.EM = 1 shl  2
CR0.PG = 1 shl 31

CR4.PAE         =  1 shl  5
CR4.PGE         =  1 shl  7
CR4.OSFXSR      =  1 shl  9
CR4.OSXMMEXCPT  =  1 shl 10
CR4.PCIDE       =  1 shl 17

MSR.EFER = 0xc0000080
MSR.EFER.SCE = 1 shl 0
MSR.EFER.LME = 1 shl 8

