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