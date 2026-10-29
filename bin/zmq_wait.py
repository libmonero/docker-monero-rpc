#!/usr/bin/env python3

# usage: zmq_wait.py <endpoint> <topic> <timeout in seconds>
# prints the first message of a zmq pub for the topic, fails without one
import sys

import zmq

endpoint, topic, timeout = sys.argv[1], sys.argv[2], float(sys.argv[3])

sock = zmq.Context().socket(zmq.SUB)
sock.setsockopt_string(zmq.SUBSCRIBE, topic)
sock.connect(endpoint)

if sock.poll(int(timeout * 1000)) == 0:
    sys.exit(f"no {topic} message from {endpoint} in {timeout:g} seconds")
print(sock.recv().decode(errors="replace"))
