#!/usr/bin/env python3
"""Find Android TVs with ADB network debugging enabled, via mDNS.

adbd advertises _adb._tcp (with its port) while network debugging is on,
even when the TV is asleep. The TV's friendly name comes from the
_androidtvremote2._tcp service on the same IP.

Prints one tab-separated line per device: ip, port, friendly name.
"""
import sys
import time

from zeroconf import ServiceBrowser, ServiceListener, Zeroconf

ADB = "_adb._tcp.local."
REMOTE = "_androidtvremote2._tcp.local."
TIMEOUT = float(sys.argv[1]) if len(sys.argv) > 1 else 5


class Collector(ServiceListener):
    def __init__(self):
        self.found = set()

    def add_service(self, zc, type_, name):
        self.found.add((type_, name))

    def update_service(self, zc, type_, name):
        self.found.add((type_, name))

    def remove_service(self, zc, type_, name):
        pass


zc = Zeroconf()
collector = Collector()
ServiceBrowser(zc, [ADB, REMOTE], collector)
time.sleep(TIMEOUT)

# Resolve after browsing; blocking lookups inside the browser callbacks time out.
adb, names = {}, {}
for type_, name in sorted(collector.found):
    info = zc.get_service_info(type_, name, timeout=3000)
    if not info:
        continue
    for ip in info.parsed_addresses():
        if ":" in ip:  # IPv4 only
            continue
        if type_ == ADB:
            adb[ip] = info.port
        else:
            names[ip] = name[: -len(REMOTE) - 1]
zc.close()

for ip, port in adb.items():
    print(f"{ip}\t{port}\t{names.get(ip, '')}")
