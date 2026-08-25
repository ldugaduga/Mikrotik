# MikroTik RB750Gr3 / RouterOS 7
# Dual-WAN automatic failover
#
# Assumptions:
#   ether1 = WAN1 / Primary ISP (DHCP)
#   ether2 = WAN2 / Backup ISP (DHCP)
#   ether3-ether5 = LAN
#   LAN = 192.168.88.0/24
#   Router = 192.168.88.1
#
# Recommended: import on a clean "no-defaults" RouterOS configuration.
#
# WAN health checks:
#   WAN1 -> 1.1.1.1
#   WAN2 -> 8.8.8.8
#
# WAN1 has route distance 1.
# WAN2 has route distance 2.

# -----------------------------
# SYSTEM
# -----------------------------
/system identity set name="RB750Gr3-DualWAN"

# -----------------------------
# INTERFACE LISTS
# -----------------------------
/interface list
add name=WAN comment="Internet interfaces"
add name=LAN comment="LAN interfaces"

/interface list member
add list=WAN interface=ether1
add list=WAN interface=ether2

# -----------------------------
# LAN BRIDGE
# -----------------------------
/interface bridge
add name=bridge-lan protocol-mode=rstp comment="LAN bridge"

/interface bridge port
add bridge=bridge-lan interface=ether3
add bridge=bridge-lan interface=ether4
add bridge=bridge-lan interface=ether5

/interface list member
add list=LAN interface=bridge-lan

# -----------------------------
# LAN IP + DNS
# -----------------------------
/ip address
add address=192.168.88.1/24 interface=bridge-lan comment="LAN gateway"

/ip dns
set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8

# -----------------------------
# DHCP SERVER FOR LAN
# -----------------------------
/ip pool
add name=lan-pool ranges=192.168.88.100-192.168.88.250

/ip dhcp-server
add name=lan-dhcp interface=bridge-lan address-pool=lan-pool lease-time=12h disabled=no

/ip dhcp-server network
add address=192.168.88.0/24 gateway=192.168.88.1 dns-server=192.168.88.1

# -----------------------------
# ROUTING HEALTH CHECK SETTINGS
# Approximately 9 seconds with 3 failed checks at 3s intervals.
# -----------------------------
/routing settings
set check-gateway-ping-count=3 check-gateway-ping-interval=3s

# -----------------------------
# WAN DHCP CLIENTS
#
# Each DHCP lease script creates:
# 1) A /32 probe route through that ISP gateway.
# 2) A recursive default route using the probe address.
#
# This detects upstream Internet failure, not merely Ethernet link failure.
# -----------------------------
/ip dhcp-client
add interface=ether1 add-default-route=no use-peer-dns=no disabled=no comment="WAN1 Primary DHCP" script=":if (\$bound=1) do={ /ip route remove [find where comment=\"WAN1-PROBE\"]; /ip route remove [find where comment=\"WAN1-DEFAULT\"]; /ip route add dst-address=1.1.1.1/32 gateway=\$\"gateway-address\" scope=10 comment=\"WAN1-PROBE\"; /ip route add dst-address=0.0.0.0/0 gateway=1.1.1.1 distance=1 check-gateway=ping target-scope=11 comment=\"WAN1-DEFAULT\"; } else={ /ip route remove [find where comment=\"WAN1-PROBE\"]; /ip route remove [find where comment=\"WAN1-DEFAULT\"]; }"

add interface=ether2 add-default-route=no use-peer-dns=no disabled=no comment="WAN2 Backup DHCP" script=":if (\$bound=1) do={ /ip route remove [find where comment=\"WAN2-PROBE\"]; /ip route remove [find where comment=\"WAN2-DEFAULT\"]; /ip route add dst-address=8.8.8.8/32 gateway=\$\"gateway-address\" scope=10 comment=\"WAN2-PROBE\"; /ip route add dst-address=0.0.0.0/0 gateway=8.8.8.8 distance=2 check-gateway=ping target-scope=11 comment=\"WAN2-DEFAULT\"; } else={ /ip route remove [find where comment=\"WAN2-PROBE\"]; /ip route remove [find where comment=\"WAN2-DEFAULT\"]; }"

# -----------------------------
# NAT
# -----------------------------
/ip firewall nat
add chain=srcnat out-interface-list=WAN action=masquerade comment="NAT LAN to Internet"

# -----------------------------
# FIREWALL - INPUT
# Protect the router itself.
# -----------------------------
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="INPUT: established/related"
add chain=input action=drop connection-state=invalid comment="INPUT: drop invalid"
add chain=input action=accept protocol=icmp comment="INPUT: allow ICMP"
add chain=input action=accept in-interface-list=LAN comment="INPUT: allow LAN management"
add chain=input action=drop in-interface-list=WAN comment="INPUT: drop WAN access"
add chain=input action=drop comment="INPUT: drop everything else"

# -----------------------------
# FIREWALL - FORWARD
# Protect LAN while allowing Internet access.
# -----------------------------
/ip firewall filter
# FastTrack intentionally omitted so the ether3 Simple Queue can enforce the 20 Mbps limit.
add chain=forward action=accept connection-state=established,related,untracked comment="FORWARD: established/related"
add chain=forward action=drop connection-state=invalid comment="FORWARD: drop invalid"
add chain=forward action=accept in-interface-list=LAN out-interface-list=WAN comment="FORWARD: LAN to WAN"
add chain=forward action=drop in-interface-list=WAN connection-nat-state=!dstnat connection-state=new comment="FORWARD: block unsolicited WAN"
add chain=forward action=drop comment="FORWARD: drop everything else"


# -----------------------------
# ETHER3 BANDWIDTH LIMIT
# Limits the total traffic through ether3 to 20 Mbps upload/download.
# Simple Queue requires FastTrack to remain disabled/omitted.
# -----------------------------
/queue simple
add name="ether3-20Mbps-Limit" target=ether3 max-limit=20M/20M comment="Limit ether3 upload/download to 20 Mbps"

# -----------------------------
# BASIC SERVICES HARDENING
# -----------------------------
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
set ssh address=192.168.88.0/24
set winbox address=192.168.88.0/24

# -----------------------------
# END
# Verification commands:
#   /ip dhcp-client print detail
#   /ip route print detail
#   /ip firewall nat print
#   /ping 1.1.1.1
#
# Test failover:
# 1. Confirm Internet works through WAN1.
# 2. Disconnect WAN1 or block its upstream Internet.
# 3. WAN1 default route should become inactive.
# 4. WAN2 default route (distance 2) becomes active.
# 5. Restore WAN1; it should become preferred again automatically.
