# MikroTik RB750Gr3 Dual-WAN Failover Configuration

This package configures a **MikroTik RB750Gr3 (hEX)** running **RouterOS 7** with automatic Dual-WAN failover and a 20 Mbps bandwidth limit on `ether3`.

## Configuration Overview

| Interface | Purpose | Configuration |
|---|---|---|
| `ether1` | WAN1 / Primary ISP | DHCP, priority 1 |
| `ether2` | WAN2 / Backup ISP | DHCP, priority 2 |
| `ether3` | LAN | 20 Mbps upload / 20 Mbps download |
| `ether4` | LAN | Unrestricted |
| `ether5` | LAN | Unrestricted |
| `bridge-lan` | LAN bridge | `192.168.88.1/24` |

### LAN Settings

- Router/Gateway: `192.168.88.1`
- Network: `192.168.88.0/24`
- DHCP range: `192.168.88.100-192.168.88.250`
- DNS: `1.1.1.1` and `8.8.8.8`
- DHCP lease time: 12 hours

### WAN Failover

WAN1 is the preferred Internet connection.

- WAN1 route distance: `1`
- WAN2 route distance: `2`
- WAN1 health probe: `1.1.1.1`
- WAN2 health probe: `8.8.8.8`
- Gateway check interval: approximately every 3 seconds
- Failed checks before declaring failure: 3

The configuration uses recursive routing so that failover can occur when upstream Internet connectivity fails even if the physical Ethernet connection to the modem/ONT remains active.

When WAN1 becomes unavailable, RouterOS automatically uses WAN2. When WAN1 connectivity returns, RouterOS automatically prefers WAN1 again.

## ether3 Bandwidth Limit

`ether3` is limited to:

- Download: **20 Mbps**
- Upload: **20 Mbps**

The limit is implemented using a RouterOS Simple Queue:

```routeros
/queue simple
add name="ether3-20Mbps-Limit" target=ether3 max-limit=20M/20M
```

FastTrack is intentionally not enabled because FastTrack traffic can bypass Simple Queue processing.

The 20 Mbps limit applies to the **combined traffic passing through ether3**, not 20 Mbps independently for every device connected through that port.

## Requirements

Before importing:

1. MikroTik model should be **RB750Gr3**.
2. Router should be running **RouterOS 7**.
3. Both Internet connections should use **DHCP**.
4. Connect the primary ISP/modem to `ether1`.
5. Connect the backup ISP/modem to `ether2`.
6. Connect LAN devices/switches to `ether3`, `ether4`, or `ether5`.
7. Download the supplied `.rsc` configuration file to your computer.

Configuration file:

```text
RB750Gr3_RouterOS7_Dual_WAN_Failover_ether3_20Mbps.rsc
```

> **Warning:** The recommended clean installation procedure resets the existing router configuration. Back up the router before proceeding.

---

# Installation

## 1. Back Up the Existing Router

Connect to the router using WinBox.

Open:

**Files → Backup**

Alternatively, use Terminal:

```routeros
/system backup save name=before-dual-wan
```

You can also create a readable configuration export:

```routeros
/export file=before-dual-wan
```

Download the backup/export files to your computer before resetting the router.

## 2. Reset to a Clean Configuration

The supplied script is designed for a clean RouterOS configuration.

Run:

```routeros
/system reset-configuration no-defaults=yes
```

Confirm the reset when prompted.

The router will reboot.

> After using `no-defaults=yes`, the normal factory LAN configuration may no longer exist. Connect using **WinBox MAC address discovery** rather than relying on `192.168.88.1`.

## 3. Reconnect Using WinBox

After the reboot:

1. Open WinBox.
2. Open the **Neighbors** tab.
3. Locate the RB750Gr3.
4. Select its **MAC address**.
5. Log in to the router.

For the initial configuration, connecting your computer directly to one of the LAN ports is recommended.

## 4. Upload the RSC File

In WinBox:

1. Open **Files**.
2. Drag and drop:

```text
RB750Gr3_RouterOS7_Dual_WAN_Failover_ether3_20Mbps.rsc
```

into the Files window.

Confirm that the file appears in the router's file list.

## 5. Optional: Validate the Script

On RouterOS versions supporting import dry-run, you can check the file for syntax errors before executing it:

```routeros
/import file-name=RB750Gr3_RouterOS7_Dual_WAN_Failover_ether3_20Mbps.rsc verbose=yes dry-run
```

If no errors are reported, continue with the actual import.

## 6. Import the Configuration

Open **New Terminal** and execute:

```routeros
/import file-name=RB750Gr3_RouterOS7_Dual_WAN_Failover_ether3_20Mbps.rsc
```

Wait for the import to finish.

A successful import should complete without a script error.

## 7. Reconnect to the Router

After configuration, the LAN gateway is:

```text
192.168.88.1
```

Set your computer to obtain an IP address automatically through DHCP.

Your computer should receive an address similar to:

```text
IP:      192.168.88.100
Gateway: 192.168.88.1
DNS:     192.168.88.1
```

Reconnect to WinBox using:

```text
192.168.88.1
```

---

# Verification

## Check WAN DHCP

Run:

```routeros
/ip dhcp-client print detail
```

Both WAN interfaces should receive valid DHCP leases.

Expected interfaces:

```text
ether1 = WAN1
ether2 = WAN2
```

If either ISP does not provide an address, verify the modem/ONT, Ethernet cable, DHCP service, and ISP configuration.

## Check Routing

Run:

```routeros
/ip route print detail
```

Under normal operation, WAN1 should be preferred because it has distance `1`.

WAN2 has distance `2` and serves as the backup route.

## Check Internet Connectivity

Run:

```routeros
/ping 1.1.1.1
```

and:

```routeros
/ping 8.8.8.8
```

Successful replies indicate Internet connectivity.

## Check NAT

Run:

```routeros
/ip firewall nat print
```

You should see the masquerade rule using the WAN interface list.

## Check Bandwidth Queue

Run:

```routeros
/queue simple print stats
```

Look for:

```text
ether3-20Mbps-Limit
```

Traffic through `ether3` should not exceed approximately 20 Mbps in either direction.

---

# Testing WAN Failover

## Normal State

With both WAN connections active:

1. Connect a computer to the LAN.
2. Verify Internet access.
3. Run:

```routeros
/ip route print
```

WAN1 should be the preferred default route.

## Simulate WAN1 Failure

Disconnect the Internet cable from `ether1`, or temporarily interrupt WAN1 upstream connectivity.

Wait for the health checks to detect the failure.

Test:

```routeros
/ping 8.8.8.8
```

Internet traffic should switch to WAN2 automatically.

You can inspect routing with:

```routeros
/ip route print detail
```

## Test Automatic Recovery

Reconnect WAN1.

After its health probe becomes reachable again, the distance `1` WAN1 route should become preferred automatically.

Internet traffic should return to WAN1.

---

# Testing the ether3 20 Mbps Limit

Connect a computer directly to `ether3`.

Perform an Internet speed test.

Expected maximum throughput should be approximately:

```text
Download: 20 Mbps
Upload:   20 Mbps
```

Small variations can occur because of protocol overhead and measurement methods.

Then connect the same test computer to `ether4` or `ether5`. Those ports do not have the 20 Mbps Simple Queue restriction.

---

# Important Notes

## Both WANs Currently Use DHCP

The configuration assumes:

```text
WAN1 = DHCP
WAN2 = DHCP
```

Do not import it unchanged if an ISP requires:

- PPPoE
- Static IP
- VLAN tagging
- ISP-specific authentication

Those WAN settings need to be customized first.

## Existing Configuration

Importing this configuration on top of an already-configured router may cause duplicate bridges, DHCP servers, firewall rules, IP addresses, or interface-list entries.

A clean `no-defaults` installation is recommended.

## Remote Installation Warning

Do not reset/import this configuration remotely unless you have another recovery method.

A configuration mistake or incompatible WAN setting can disconnect remote access to the router.

For initial deployment, local access through WinBox/MAC connection is recommended.

## Management Security

The configuration:

- Blocks unsolicited management access from WAN.
- Allows management from LAN.
- Disables Telnet.
- Disables FTP.
- Disables HTTP management.
- Disables API/API-SSL.
- Restricts SSH and WinBox management to `192.168.88.0/24`.

Set a strong administrator password after installation.

Example:

```routeros
/user set admin password="YOUR-STRONG-PASSWORD"
```

Do not store a real production password inside a shared `.rsc` file.

---

# Troubleshooting

## Import Reports an Error

Run:

```routeros
/import file-name=RB750Gr3_RouterOS7_Dual_WAN_Failover_ether3_20Mbps.rsc verbose=yes
```

RouterOS will provide more detail about the line that failed.

On supported RouterOS versions, use dry-run first:

```routeros
/import file-name=RB750Gr3_RouterOS7_Dual_WAN_Failover_ether3_20Mbps.rsc verbose=yes dry-run
```

## No Internet on WAN1

Check:

```routeros
/ip dhcp-client print detail
```

Confirm `ether1` has:

- IP address
- Gateway
- DHCP status `bound`

Then test:

```routeros
/ping 1.1.1.1
```

## WAN2 Does Not Take Over

Check:

```routeros
/ip route print detail
```

Verify the WAN2 recursive route exists and is active when WAN1 is unavailable.

Also test:

```routeros
/ping 8.8.8.8
```

## ether3 Exceeds 20 Mbps

Check:

```routeros
/queue simple print stats
```

Also verify that FastTrack has not been manually enabled:

```routeros
/ip firewall filter print
```

The supplied configuration intentionally omits the FastTrack rule.

---

# Configuration Summary

```text
Device:       MikroTik RB750Gr3
RouterOS:     Version 7

ether1:       WAN1 / Primary
ether2:       WAN2 / Backup
ether3:       LAN / 20 Mbps up + down
ether4:       LAN / Unlimited
ether5:       LAN / Unlimited

LAN Network:  192.168.88.0/24
Gateway:      192.168.88.1
DHCP Pool:    192.168.88.100-192.168.88.250

WAN1 Probe:   1.1.1.1
WAN2 Probe:   8.8.8.8

WAN1 Distance: 1
WAN2 Distance: 2

Failover:     Automatic
Failback:     Automatic
NAT:          Enabled
Firewall:     Enabled
```

## Configuration File

`RB750Gr3_RouterOS7_Dual_WAN_Failover_ether3_20Mbps.rsc`
