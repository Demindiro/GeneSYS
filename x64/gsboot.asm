PAGE_SIZE_P2 = 12
PAGE_SIZE = 1 shl PAGE_SIZE_P2

org 0
db "GeneSYS BOOT"
db PAGE_SIZE_P2, 0
dw 0x8664
dq kernel, kernel.size
dq init, init.size
dq aux, aux.size
assert $ = 64

macro object name, path {
	align PAGE_SIZE
	name: file path
	.size = $ - name
	times ((0 - $) and (PAGE_SIZE - 1)) db 0
}
object kernel, "build/kernel"
object init, "build/init"
object aux, "build/aux"
