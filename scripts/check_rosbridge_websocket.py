#!/usr/bin/env python3
import base64
import hashlib
import json
import os
import socket
import struct
import time

HOST = os.environ.get("ROSBRIDGE_HOST", "127.0.0.1")
PORT = int(os.environ.get("ROSBRIDGE_PORT", "8765"))
TOPIC = os.environ.get("ROSBRIDGE_SMOKE_TOPIC", "/codex_rosbridge_smoke")
PAYLOAD = os.environ.get("ROSBRIDGE_SMOKE_PAYLOAD", "rosbridge smoke ok")


def recv_exact(sock, length):
    data = b""
    while len(data) < length:
        chunk = sock.recv(length - len(data))
        if not chunk:
            raise RuntimeError("socket closed")
        data += chunk
    return data


def send_frame(sock, text):
    payload = text.encode("utf-8")
    header = bytearray([0x81])
    if len(payload) < 126:
        header.append(0x80 | len(payload))
    elif len(payload) < 65536:
        header.append(0x80 | 126)
        header.extend(struct.pack("!H", len(payload)))
    else:
        header.append(0x80 | 127)
        header.extend(struct.pack("!Q", len(payload)))

    mask = os.urandom(4)
    header.extend(mask)
    masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    sock.sendall(header + masked)


def recv_frame(sock):
    first, second = recv_exact(sock, 2)
    opcode = first & 0x0F
    masked = second & 0x80
    length = second & 0x7F

    if length == 126:
        length = struct.unpack("!H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", recv_exact(sock, 8))[0]

    mask = recv_exact(sock, 4) if masked else b""
    payload = recv_exact(sock, length)
    if masked:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    if opcode == 0x8:
        raise RuntimeError("websocket closed")
    if opcode != 0x1:
        return None
    return payload.decode("utf-8")


def main():
    with socket.create_connection((HOST, PORT), timeout=5) as sock:
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            f"GET / HTTP/1.1\r\n"
            f"Host: {HOST}:{PORT}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        sock.sendall(request.encode("ascii"))
        response = sock.recv(4096).decode("iso-8859-1")
        if "101 Switching Protocols" not in response:
            raise RuntimeError(response)

        accept = hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")).digest()
        expected = base64.b64encode(accept).decode("ascii")
        if expected not in response:
            raise RuntimeError("bad websocket accept header")

        send_frame(sock, json.dumps({"op": "advertise", "topic": TOPIC, "type": "std_msgs/String"}))
        send_frame(sock, json.dumps({"op": "subscribe", "topic": TOPIC, "type": "std_msgs/String"}))
        time.sleep(0.2)
        send_frame(sock, json.dumps({"op": "publish", "topic": TOPIC, "msg": {"data": PAYLOAD}}))

        deadline = time.time() + 5
        while time.time() < deadline:
            frame = recv_frame(sock)
            if not frame:
                continue
            message = json.loads(frame)
            if message.get("op") == "publish" and message.get("topic") == TOPIC:
                data = message.get("msg", {}).get("data")
                if data == PAYLOAD:
                    print(f"rosbridge websocket smoke received: {data}")
                    return

        raise TimeoutError("timed out waiting for rosbridge echo")


if __name__ == "__main__":
    main()
