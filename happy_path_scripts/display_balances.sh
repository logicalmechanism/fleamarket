#!/usr/bin/env bash
set -e

# SET UP VARS HERE
source .env

# market contract
market_script_path="../contracts/market_contract.plutus"
market_script_address=$(${cli} address build --payment-script-file ${market_script_path} ${network})

# # always false to hold script utxo
always_false_script_path="../contracts/always_false_contract.plutus"
script_reference_address=$(${cli} conway address build --payment-script-file ${always_false_script_path} ${network})

# get current parameters
mkdir -p ./tmp
${cli} conway query protocol-parameters ${network} --out-file ./tmp/protocol.json
${cli} conway query tip ${network} | jq

# market
echo -e "\033[1;35m Market Contract Address: \033[0m" 
echo -e "\n \033[1;35m ${market_script_address} \033[0m \n";
${cli} conway query utxo --address ${market_script_address} ${network}
${cli} conway query utxo --address ${market_script_address} ${network} --out-file ./tmp/current_market_utxos.json

echo -e "\033[1;35m Script Reference UTxOs: \033[0m" 
echo -e "\n \033[1;35m ${script_reference_address} \033[0m \n";
${cli} conway query utxo --address ${script_reference_address} ${network}

# Loop through each -market folder
for wallet_folder in wallets/*-wallet; do
    # Check if payment.addr file exists in the folder
    if [ -f "${wallet_folder}/payment.addr" ]; then
        addr=$(cat ${wallet_folder}/payment.addr)
        echo
        
        echo -e "\033[1;37m --------------------------------------------------------------------------------\033[0m"
        echo -e "\033[1;34m $wallet_folder\033[0m\n\n\033[1;32m $addr\033[0m"
        

        echo -e "\033[1;33m"
        # Run the cardano-cli command with the reference address and testnet magic
        ${cli} conway query utxo --address ${addr} ${network}
        ${cli} conway query utxo --address ${addr} ${network} --out-file ./tmp/"${addr}.json"

        baseLovelace=$(jq '[.. | objects | .lovelace] | add' ./tmp/"${addr}.json")
        echo -e "\033[0m"

        echo -e "\033[1;36m"
        ada=$(echo "scale = 6;${baseLovelace} / 1000000" | bc -l)
        echo -e "TOTAL ADA:" ${ada}
        echo -e "\033[0m"
    fi
done
