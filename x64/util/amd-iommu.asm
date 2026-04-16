macro amd_iommu.decl_mmio name {
	name:
		.device_table    dq ?
		.command_ring    dq ?
		.event_ring      dq ?
		.control         dq ?
	rb 0x2000 - ($ - name)
		.command_head    dq ?
		.command_tail    dq ?
		.event_head      dq ?
		.event_tail      dq ?
		.status          dq ?
}

AMD_IOMMU.CONTROL::
	.CMD_BUF_EN     = 1 shl 12
	.EVENT_LOG_EN   = 1 shl  2
	.HT_TUN_EN      = 1 shl  1
	.IOMMU_EN       = 1 shl  0

AMD_IOMMU.CMD::
	.COMPLETION_WAIT                =  1
        .INVALIDATE_DEVTAB_ENTRY        =  2
        .INVALIDATE_IOMMU_PAGES         =  3
        .INVALIDATE_IOTLB_PAGES         =  4
        .INVALIDATE_INTERRUPT_TABLE     =  5
        .PREFETCH_IOMMU_PAGES           =  6
        .COMPLETE_PPR_REQUEST           =  7
        .INVALIDATE_IOMMU_ALL           =  8
        .INSERT_GUEST_EVENT             =  9
        .RESET_VMMIO                    = 10

AMD_IOMMU.DTE::
        .0.V            =  1 shl  0
        .0.TV           =  1 shl  1
        .0.MODE.NONE    =  0 shl  9
        .0.MODE.L1      =  1 shl  9
        .0.MODE.L2      =  2 shl  9
        .0.MODE.L3      =  3 shl  9
        .0.MODE.L4      =  4 shl  9
        .0.MODE.L5      =  5 shl  9
        .0.MODE.L6      =  6 shl  9
        .0.IR           =  1 shl 61
        .0.IW           =  1 shl 62

AMD_IOMMU.PTE::
        .IW             =  1 shl 62
        .IR             =  1 shl 61
        .FC             =  1 shl 60
        .U              =  1 shl 59
        .NEXTLVL.0      =  0 shl  9
        .NEXTLVL.1      =  1 shl  9
        .NEXTLVL.2      =  2 shl  9
        .NEXTLVL.3      =  3 shl  9
        .NEXTLVL.4      =  4 shl  9
        .NEXTLVL.5      =  5 shl  9
        .NEXTLVL.6      =  6 shl  9
        .NEXTLVL.7      =  7 shl  9
        .NEXTLVL_SHIFT  = 9
