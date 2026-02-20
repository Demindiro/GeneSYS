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
	.COMPLETION_WAIT        =  1
