#!/usr/bin/env python3

def crc32c(data):
    POLY = 0x82f63b78
    x = 0xffff_ffff
    for b in data:
        x ^= b
        for _ in range(8):
            x = (x >> 1) ^ (-(x & 1) & POLY)
    return x ^ 0xffff_ffff

def encode_cobs(data):
    x = []
    nx = []
    def f(n):
        x.append(n)
        x.extend(nx)
        nx.clear()
    for b in data:
        if b == 0:
            f(1 + len(nx))
        else:
            nx.append(b)
        if len(nx) >= 254:
            f(0xff)
    if nx:
        f(1 + len(nx))
    x.append(0)
    return bytes(x)

def decode_cobs(packet):
    r = []
    n = 0
    nn = 255
    for i in range(len(packet) + 1):
        x = packet[i]
        if x == 0:
            assert i == len(packet) - 1
            break
        if n == 0:
            if nn != 255:
                r.append(0)
            nn = x
            n = x - 1
        else:
            r.append(x)
            n -= 1
    return bytes(r)

def encode(data):
    return encode_cobs(data + crc32c(data).to_bytes(4, 'little'))

def decode(data):
    data = decode_cobs(data)
    return data[:-4]

def send(sock, data):
    return sock.sendall(encode(data))

def recv_raw(sock) -> bytes:
    r = b''
    while True:
        x = sock.recv(1)
        r += x
        if x in (b'\0', b''):
            break
    return r

def recv(sock) -> bytes:
    return decode(recv_raw(sock))

def cmd(sock, cmd_id, data) -> bytes:
    send(sock, bytes([cmd_id]) + data)
    return recv(sock)

def connect(path):
    import socket
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(path)
    return s

def reset(sock):
    # forcibly delimit any previous packet
    sock.sendall(b'\0')

def cmd_echo(sock, data):
    data = data.encode('utf-8')
    send(sock, b'\0' + data)
    want = encode(b'\0' + data)
    r = recv_raw(sock)
    print('want:', want)
    print('got: ', r)
    print('OK' if want == r else 'FAIL')

def cmd_identify(sock):
    r = cmd(sock, 1, b'')
    version = int.from_bytes(r[0:2], 'little')
    arch    = int.from_bytes(r[2:4], 'little')
    extra   = r[4:]
    print('version:', hex(version))
    print('architecture:', hex(arch))
    print('extra:', extra)

def _test_echo(sock):
    for x in ['', '123456789', 'a' * 253, 'x' * 254, 'y' * 255, 'z' * 256]:
        cmd_echo(sock, x)

def main(path, subcmd, *args):
    import socket
    s = connect(path)
    reset(s)
    {
        'echo': cmd_echo,
        'identify': cmd_identify,
        '_test_echo': _test_echo,
    }[subcmd](s, *args)
    # workaround QEMU apparently forgetting to set POLLIN
    # whenever POLLHUP is passed too.
    time.sleep(0.1)

def _test_cobs():
    cases = [
        b'',
        b'123456789',
        b'x' * 254,
        b'y' * 255,
        b'z' * 256,
    ]
    for x in cases:
        y = encode_cobs(x)
        z = decode_cobs(y)
        assert x == z, f'\n{x}\n\t<>\n{z}\n\t:\n{y}'

def _test_crc():
    for x in [b'', b'x', b'xyz', b'123456789']:
        y = crc32c(x)
        assert crc32c(x + y.to_bytes(4, 'little')) == 0x48674bc7

if __name__ == '__main__':
    _test_cobs()
    _test_crc()
    import sys, time
    main(*sys.argv[1:])
