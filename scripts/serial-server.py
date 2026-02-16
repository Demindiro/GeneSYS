#!/usr/bin/env python3

def rx(socket):
    import debug
    print('connected (line mode)')
    while True:
        x, = socket.recv(1)
        if x == 0:
            break
        c = chr(x)
        if not c in '\t\n\r' and (c < ' ' or c > '~'):
            print(f'\\x{x:02x}', end='')
        else:
            print(c, end='')
    print('switching to COBS mode')
    buf = []
    while True:
        x, = socket.recv(1)
        buf.append(x)
        if x == 0:
            print('<-', debug.decode(bytes(buf)))
            buf.clear()
    print('disconnected, last = ', buf)

def tx(sockets):
    import debug
    while True:
        b = input('>> ')
        b = b'\0' + debug.encode(b'\3\0\0\0\0' + b.encode('utf-8'))
        print('->', b)
        i = 0
        while i < len(b):
            try:
                n = sockets[0].send(b[i:])
            except:
                break
            if n == 0:
                break
            i += n

def main():
    from socket import socket, AF_UNIX, SOCK_STREAM
    from threading import Thread
    import os

    try:
        os.remove('/tmp/genesys.unix')
    except:
        pass
    server = socket(AF_UNIX, SOCK_STREAM)
    server.bind('/tmp/genesys.unix')
    server.listen(5)
    sockets = []
    Thread(target=tx, args=(sockets,)).start()
    while True:
        try:
            print('waiting for client...')
            client, _ = server.accept()
            sockets.append(client)
            rx(client)
        except Exception as e:
            print('error:', e)
            pass
        sockets.clear()

if __name__ == '__main__':
    main()
