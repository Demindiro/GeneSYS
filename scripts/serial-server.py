#!/usr/bin/env python3

def main():
    from socket import socket, AF_UNIX, SOCK_STREAM
    import os
    import debug

    try:
        os.remove('/tmp/genesys.unix')
    except:
        pass
    server = socket(AF_UNIX, SOCK_STREAM)
    server.bind('/tmp/genesys.unix')
    server.listen(5)
    while True:
        try:
            print('waiting for client...')
            client, _ = server.accept()
            print('connected (line mode)')
            while True:
                x, = client.recv(1)
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
                x, = client.recv(1)
                buf.append(x)
                if x == 0:
                    print(debug.decode(bytes(buf)))
                    buf.clear()
            print('disconnected, last = ', buf)
        except Exception as e:
            print('error:', e)
            pass

if __name__ == '__main__':
    main()
