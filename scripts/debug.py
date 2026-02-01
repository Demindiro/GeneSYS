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
    for b in data:
        if b == 0:
            x.append(1 + len(nx))
            x.extend(nx)
        else:
            nx.append(b)
    x.append(1 + len(nx))
    x.extend(nx)
    x.append(0)
    return bytes(x)

def encode(data):
    return encode_cobs(data + crc32c(data).to_bytes(4, 'little'))

def connect(path):
    import socket
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(path)
    return s

def reset(sock):
    # forcibly delimit any previous packet
    sock.sendall(b'\0')

def cmd_echo(sock, data):
    print(encode(b'\0' + data))
    print(encode(b'\0' + data).hex())
    sock.sendall(encode(b'\0' + data))

def main(path):
    import socket
    s = connect(path)
    reset(s)
    cmd_echo(s, b'123456789')
    while True:
        c = s.recv(1)
        if not c:
            break
        print(c)
    # workaround QEMU apparently forgetting to set POLLIN
    # whenever POLLHUP is passed too.
    time.sleep(0.1)

if __name__ == '__main__':
    import sys, time
    main(*sys.argv[1:])
