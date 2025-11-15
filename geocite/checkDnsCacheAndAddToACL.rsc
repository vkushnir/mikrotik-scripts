# Script: checkDnsCacheAndAddToACL
# RouterOS: 7.20+
# Description: Scan DNS cache and add matching IPs to Access List with auto-renewal

:global domainRules

# --- CONFIG ---
:local accessListName "dnsDomains"
:local leaseTime "7d"
:local renewThresholdSec 86400

# --- helper: convert timeout string to seconds ---
:local toSeconds do={
    :local t $1
    :local s 0
    :if ([:find $t "d"] != nil) do={ :set s ($s + [:tonum [:pick $t 0 [:find $t "d"]]] * 86400) }
    :if ([:find $t "h"] != nil) do={ :set s ($s + [:tonum [:pick $t 0 [:find $t "h"]]] * 3600) }
    :if ([:find $t "m"] != nil) do={ :set s ($s + [:tonum [:pick $t 0 [:find $t "m"]]] * 60) }
    :return $s
}

# --- function: update acl ---
:local aclUpdate do={
    :log error "Add to ACL $fileName, $rule=$value ($[:len $dnsMatches])"
    :foreach d in=$dnsMatches do={
        :local addr [/ip dns cache get $d address]
        :log debug "$addr:$value"
    }
}

# --- MAIN ---
:foreach fileName,rules in=$domainRules do={
    :foreach k,v in=$rules do={
        :local rule [:pick $v 0 [:find $v "="]]
        :local value [:pick $v ([:find $v "="]+1) [:find $v "::"]]
        :local match [:pick $v ([:find $v "::"]+2) [:len $v]]
        :local comment "geocite::$fileName::$rule::$value"

        :if ([:find {"domain";"keyword";"regexp"} $rule] >= 0) do={
            :local dnsMatches [/ip dns cache all find where (name~$match) && ((type="A") || (type="AAAA"))]
            :if ([:len $dnsMatches] > 0) do={
                :log debug "Add to ACL $fileName, $rule=$value ($[:len $dnsMatches])"
                $aclUpdate dnsMatches=$dnsMatches comment=$comment fileName=$fileName rule=$rule value=$value
            }
        }
        :if ($rule = "full") do={
            :local dnsMatches [/ip dns cache all find where (name=$match) && ((type="A") || (type="AAAA"))]
            :if ([:len $dnsMatches] > 0) do={
                :log debug "Add to ACL $fileName, $rule=$value ($[:len $dnsMatches])"
                $aclUpdate matches=$dnsMatches comment=$comment name=$fileName rule=$rule value=$value
            }
        }
    }
}