#Mikotik #DHCP #DNS

# Mikrotik: Updating DNS Static Records from DHCP

Technical Guide

This document describes how to automatically create and remove static DNS records in MikroTik RouterOS based on DHCP lease events.
The solution uses a DHCP lease script and a global variable containing predefined hostname mappings.

---

## Overview

When a DHCP client receives or releases an IP address, the DHCP server runs a script that:
  • Determines the hostname:
  • Either from a predefined MAC → hostname mapping
  • Or from the lease-hostname option (sanitized)
  • Creates or removes a static DNS A record in /ip/dns/static
  • Logs all operations

All code blocks are provided in native MikroTik RouterOS Script language.

```mermaid
flowchart TD
    Start([DHCP Lease Event]) --> CheckBound{Lease Bound?}
    
    CheckBound -->|Yes| GetMAC[Get MAC Address]
    CheckBound -->|No| Unbind[DHCP Unbind Event]
    
    GetMAC --> CheckStatic{MAC in Static Hosts Array?}
    
    CheckStatic -->|Yes| UseStatic[Use Static Hostname]
    CheckStatic -->|No| UseDHCP[Use DHCP Hostname]
    
    UseDHCP --> ReplaceSpaces[Replace Spaces with Underscores]
    
    UseStatic --> CheckEmpty{Hostname Empty?}
    ReplaceSpaces --> CheckEmpty
    
    CheckEmpty -->|No| AddDNS[Add DNS Static Record]
    CheckEmpty -->|Yes| End
    
    AddDNS --> End
    
    Unbind --> RemoveDNS[Remove DNS Static Record]
    RemoveDNS --> End([End])
    
    style Start fill:#e1f5e1
    style End fill:#ffe1e1
    style AddDNS fill:#e1e5ff
    style RemoveDNS fill:#ffe5e1
```

---

## Main Script

This script performs the DNS update logic.

```mikrotik
# Add static DNS record when DHCP addres leased

# --- CONFIG ---
:global hosts; # array {"mac"="hostname";"mac"="hostname"}
:local ttl "1h"


# --- function: replace " " character ---
:local replace do={
    :local result ""

    :for i from=0 to=([:len $value] - 1) do={
        :local ch [:pick $value $i ($i + 1)]
        :if ($ch = " ") do={
            :set result ($result . "_")
        } else={
            :set result ($result . $ch)
        }
    }
    :return $result
}

# --- MAIN ---
:local hostname ($hosts->"$leaseActMAC")
if ([:len $hostname] <= 0) do={
  :set hostname [$replace value=$"lease-hostname"]
}
:if ($leaseBound=1) do={
  if ([:len $hostname] > 0) do={
    :log info ("DHCP Bound: $leaseActIP [$leaseActMAC] (" . $hostname . ")")
    ip/dns/static/add address=$leaseActIP name=($hostname . ".home.arpa") type=A ttl=$ttl comment=("DHCP Server:$leaseServerName, MAC: $leaseActMAC, Client: " . $hostname)
  } else {
    :log debug ("DHCP Bound: $leaseActIP [$leaseActMAC] (unknown)")
  }
} else {
  :log info ("DHCP UnBound: $leaseActIP [$leaseActMAC] (" . $hostname . ")")
  /ip/dns/static/remove [find address=$leaseActIP]
}
```

---

## DHCP Server Configuration

Add a DHCP server and attach the DNS update script using the lease-script property.

```mikrotik
/ip dhcp-server
add add-arp=yes address-pool=dhcp bootp-support=none interface=bridge-lan lease-script="\
      # Add static DNS record when DHCP addres leased\
    \n\
    \n# --- CONFIG ---\
    \n:global hosts; # array {\"mac\"=\"hostname\";\"mac\"=\"hostname\"}\
    \n:local ttl \"1h\"\
    \n\
    \n\
    \n# --- function: replace \" \" character ---\
    \n:local replace do={\
    \n    :local result \"\"\
    \n\
    \n    :for i from=0 to=([:len \$value] - 1) do={\
    \n        :local ch [:pick \$value \$i (\$i + 1)]\
    \n        :if (\$ch = \" \") do={\
    \n            :set result (\$result . \"_\")\
    \n        } else={\
    \n            :set result (\$result . \$ch)\
    \n        }\
    \n    }\
    \n    :return \$result\
    \n}\
    \n\
    \n# --- MAIN ---\
    \n:local hostname (\$hosts->\"\$leaseActMAC\")\
    \nif ([:len \$hostname] <= 0) do={\
    \n  :set hostname [\$replace value=\$\"lease-hostname\"]\
    \n}\
    \n:if (\$leaseBound=1) do={\
    \n  if ([:len \$hostname] > 0) do={\
    \n    :log info (\"DHCP Bound: \$leaseActIP [\$leaseActMAC] (\" . \$hostname . \")\")\
    \n    ip/dns/static/add address=\$leaseActIP name=(\$hostname . \".home.arpa\") type=A ttl=\$ttl comment=(\"DHCP Server:\$leaseServerName, MAC: \$leaseActMAC, \
    Client: \" . \$hostname)\
    \n  } else {\
    \n    :log debug (\"DHCP Bound: \$leaseActIP [\$leaseActMAC] (unknown)\")\
    \n  }\
    \n} else {\
    \n  :log info (\"DHCP UnBound: \$leaseActIP [\$leaseActMAC] (\" . \$hostname . \")\")\
    \n  /ip/dns/static/remove [find address=\$leaseActIP]\
    \n}" lease-time=1h name=local
```

---

## Global Variables

A global variable hosts stores a mapping of **MAC addresses** to **custom static hostnames**.

```mikrotik
# DHCP to DNS
:global hosts {
  "C8:D7:78:73:11:11"="dishwasher";
  "70:C9:32:39:11:11"="dreame";
  "00:15:5D:0A:11:11"="winsrv-2022"}
```

This mapping has priority over the `lease-hostname` provided by the DHCP client.

### Global variables script

initGlobalVars script template here:

```mikrotik
/system script
  add ame=initGlobalVars \
  comment="Initialese global variables" \
  dont-require-permissions=no \
  policy=read,write,policy,test \
  source="# Put global variable here"
```

## Initialization Scheduler

Add a scheduler task that loads global variables during system startup.

```mikrotik
/system scheduler
	add name=loadGlobals \
	start-time=startup \
	policy=read,write,policy,test \
	comment="Initialese global variables on startup" \
	on-event="\
	/system/script/run initGlobalVars;"
```

---
https://github.com/vkushnir/mikrotik-scripts/tree/main/ip/dhcp

