macro intel_iommu.decl_mmio name {
        name::
                .version                dd ?
                                        dd ?  ; reserved
                .capability             dq ?
                .ext_capability         dq ?
                .global_command         dd ?
                .global_status          dd ?
                .root_table_addr        dq ?
                .context_command        dq ?
                                        dd ?  ; reserved
                .fault_status           dd ?
                .fault_event_control    dd ?
                .fault_event_data       dd ?
                .fault_event_addr       dd ?
                .fault_event_addr_h     dd ?
                                        dq ?  ; reserved
                                        dq ?  ; reserved
                                        dq ?  ; reserved
                                        dd ?  ; reserved
                .prot_mem_enable        dd ?
                .prot_low_mem_base      dd ?
                .prot_low_mem_limit     dd ?
                .prot_high_mem_base     dq ?
                .prot_high_mem_limit    dq ?
                .invalidation_queue_head                dq ?
                .invalidation_queue_tail                dq ?
                .invalidation_queue_addr                dq ?
                                                        dd ?  ; reserved
                .invalidation_completion_status         dd ?
                .invalidation_completion_event_ctrl     dd ?
                .invalidation_completion_event_data     dd ?
                .invalidation_completion_event_addr     dd ?
                .invalidation_completion_event_addr_h   dd ?
                .invalidation_queue_error_record        dq ?
                .intr_remap_tbl_addr                    dq ?
                .page_request_queue_head                dq ?
                .page_request_queue_tail                dq ?
                .page_request_queue_addr                dq ?
                ; ... etc
        assert name#.root_table_addr         - name#.version = 0x20
        assert name#.fault_event_addr        - name#.version = 0x40
        assert name#.invalidation_queue_head - name#.version = 0x80
        assert name#.page_request_queue_addr - name#.version = 0xd0
}
