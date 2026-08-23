#!/usr/bin/env bash

set -e

ENV_FILE=".env"

ANVIL_BROADCAST_FILE="broadcast/DeployRaffle.s.sol/31337/run-latest.json"
SEPOLIA_BROADCAST_FILE="broadcast/DeployRaffle.s.sol/11155111/run-latest.json"

update_env() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        # Ensure the existing file ends with a newline before appending.
        if [ -s "$ENV_FILE" ] && [ "$(tail -c 1 "$ENV_FILE" | wc -l)" -eq 0 ]; then
            printf '\n' >> "$ENV_FILE"
        fi

        printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    fi

    echo "Updated ${key}=${value}"
}

update_address() {
    local key="$1"
    local broadcast_file="$2"

    if [ ! -f "$broadcast_file" ]; then
        echo "Skipping ${key}: broadcast file not found."
        return
    fi

    local address

    address=$(
        jq -r '.transactions[]
            | select(.contractName == "Raffle")
            | .contractAddress' "$broadcast_file"
    )

    if [ -z "$address" ] || [ "$address" = "null" ]; then
        echo "Skipping ${key}: Raffle contract not found in ${broadcast_file}."
        return
    fi

    update_env "$key" "$address"
}

update_address "ANVIL_RAFFLE_ADDRESS" "$ANVIL_BROADCAST_FILE"
update_address "SEPOLIA_RAFFLE_ADDRESS" "$SEPOLIA_BROADCAST_FILE"