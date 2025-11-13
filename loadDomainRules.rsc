# Script: loadDomainRules
# RouterOS: 7.20+
# Description: Parse domain rule files and store them into global variable "domainRules"

:global domainRules

# --- CONFIG ---
:local dirPath "geosite/"; # folder with rules
:local fileList [:toarray "x,youtube"]; # list rule files to load

# initialize
:set domainRules [:toarray ""]

# --- function: process file (recursive) ---
:local processFile do={
    :local fileName $1
    :local dirPath $2
    :local processFile $3

    :global domainRules
    :local filePath ($dirPath . $fileName)

    :local f [/file find where name=$filePath]
    :if ([:len $f] = 0) do={
        :log error ("File not found: " . $filePath)
        :return $filePath
    }

    :log info "Read $filePath ..."
    :local content [/file get $filePath contents]

    :foreach line in=[ :deserialize [:tolf $content] from=dsv delimiter="\n" options=dsv.plain ] do={
        :set line [:tostr $line]
        :if ([:len $line] > 1 && [:pick $line 0 1] != "#") do={
            # split rule line
            :local rule
            :local value
            if ([:find $line ":"] > 1) do={
                :set rule [:pick $line 0 [:find $line ":"]];
                :set value [:pick $line ([:find $line ":"]+1) [:len $line]];
            } else={
                :set rule "domain";
                :set value $line;
            }

            # handle include
            :if ($rule = "include") do={
                :log debug "Import file: $value ..."
                $processFile $value $dirPath $processFile
                :set $rule "continue"
            }

            # add rule to array
            :if ([:find {"domain";"keyword";"regexp";"full"} $rule] >= 0) do={
                # remove attributes
                :if ([:find $value " "] > 1) do={
                    :set value [:pick $value 0 [:find $value " "]]
                }

                # store rule
                :local existing ($domainRules->$fileName)
                :if ([:typeof ($domainRules->$fileName)] = "nothing") do={
                    :log debug "set new '$fileName', $rule=$value"
                    :set ($domainRules->$fileName) ($rule . "=" . $value)
                } else={
                    :log debug "update '$fileName', add $rule=$value"
                    :set ($domainRules->$fileName) ($existing , ($rule . "=" . $value))
                }
                :set rule "set";
            }

            # check for unknown rule
            :if ([:find {"continue";"set"} $rule] < 0) do={
                :log warning "unknown rule: $line"
            }
        }

    }
}

# --- MAIN ---
:foreach fileName in=$fileList do={
    $processFile $fileName $dirPath $processFile
}

:log info ("Loaded domain rules from: $dirPath")
:log info ("Files loaded: " . [:len $domainRules])
