#!/usr/bin/env python3
"""
Extract the TLS certificate from a Microsoft SQL Server.
SQL Server wraps TLS inside the TDS protocol, so plain `openssl s_client`
cannot fetch the certificate. This script performs a TDS Pre-Login
handshake and then a TLS handshake wrapped in TDS packets.

Usage:
    python3 get_sql_cert.py <host> [port]        # prints PEM to stdout
    python3 get_sql_cert.py <host> [port] > sqlserver.pem
"""
import socket
import ssl
import struct
import sys

TDS_PRELOGIN = 0x12


def tds_packet(ptype: int, payload: bytes) -> bytes:
    # type, status=EOM, length, spid, packet id, window
    return struct.pack('>BBHHBB', ptype, 0x01, 8 + len(payload), 0, 0, 0) + payload


def recv_exact(sock: socket.socket, n: int) -> bytes:
    data = b''
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise EOFError('connection closed by server')
        data += chunk
    return data


def read_tds_packet(sock: socket.socket) -> bytes:
    hdr = recv_exact(sock, 8)
    _ptype, _status, length, _spid, _pid, _win = struct.unpack('>BBHHBB', hdr)
    return recv_exact(sock, length - 8)


def build_prelogin() -> bytes:
    # Option table: VERSION (0x00) and ENCRYPTION (0x01), terminated by 0xFF.
    # Each entry: token(1) offset(2 BE) length(2 BE). Offsets are relative
    # to the start of the payload.
    header_len = 5 * 2 + 1
    version_data = struct.pack('>BBHH', 16, 0, 0, 0)   # fake client version 16.0
    encryption_data = b'\x01'                          # ENCRYPT_ON
    entries = (
        struct.pack('>BHH', 0x00, header_len, len(version_data)) +
        struct.pack('>BHH', 0x01, header_len + len(version_data), len(encryption_data)) +
        b'\xff'
    )
    return entries + version_data + encryption_data


def get_certificate(host: str, port: int) -> str:
    sock = socket.create_connection((host, port), timeout=15)
    try:
        # 1. TDS Pre-Login
        sock.sendall(tds_packet(TDS_PRELOGIN, build_prelogin()))
        read_tds_packet(sock)  # server pre-login response (ignored)

        # 2. TLS handshake, wrapped inside TDS packets
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        incoming, outgoing = ssl.MemoryBIO(), ssl.MemoryBIO()
        tls = ctx.wrap_bio(incoming, outgoing, server_hostname=host)

        while True:
            try:
                tls.do_handshake()
                break
            except ssl.SSLWantReadError:
                out = outgoing.read()
                if out:
                    sock.sendall(tds_packet(TDS_PRELOGIN, out))
                incoming.write(read_tds_packet(sock))
        # flush any final handshake bytes
        out = outgoing.read()
        if out:
            sock.sendall(tds_packet(TDS_PRELOGIN, out))

        der = tls.getpeercert(binary_form=True)
        if not der:
            raise RuntimeError('handshake succeeded but no certificate received')
        return ssl.DER_cert_to_PEM_cert(der)
    finally:
        sock.close()


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 1433
    pem = get_certificate(host, port)
    sys.stdout.write(pem)
    # Print a human-readable summary to stderr so stdout stays clean PEM
    try:
        import subprocess
        subprocess.run(
            ['openssl', 'x509', '-noout', '-subject', '-issuer', '-dates', '-ext', 'subjectAltName'],
            input=pem.encode(), stderr=subprocess.DEVNULL, stdout=sys.stderr.buffer,
        )
    except Exception:
        pass


if __name__ == '__main__':
    main()
