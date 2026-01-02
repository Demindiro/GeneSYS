PAGE_SIZE_P2 = 12
PAGE_SIZE = 1 shl PAGE_SIZE_P2

org 0
db "GeneSYS BOOT"
db PAGE_SIZE_P2, 0
dw 0x8664
dd kernel.page_count
dd init.page_count
dd aux.page_count
assert $ = 28
times (PAGE_SIZE - $) db 0

macro object name, path {
	align PAGE_SIZE
	name: file path
	times ((-$) and (PAGE_SIZE - 1)) db 0
	.page_count = ($ - name) shr PAGE_SIZE_P2
}
object kernel, "build/kernel"
object init, "build/init"
object aux, "build/aux"
