
#!/bin/bash

# Run the Python script and capture its output
output=$(python3 /var/scripts/wildcard_check.py domain1 domain2 domain3)

# Print the output for visibility
#echo "$output"

# Check the output for any 'WARN' messages and output them to stderr
echo "$output" | while IFS= read -r line; do
    if [[ $line == *"WARN"* ]]; then
        echo "$line" >&2
    fi
done





https://github.com/codebox/https-certificate-expiry-checker