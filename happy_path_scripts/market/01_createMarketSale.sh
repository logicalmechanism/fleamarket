#!/usr/bin/env bash
set -e

# SET UP VARS HERE
source ../.env

mkdir -p ../tmp
${cli} conway query protocol-parameters ${network} --out-file ../tmp/protocol.json

seller="buyer"
seller_address=$(cat ../wallets/${seller}-wallet/payment.addr)
seller_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/${seller}-wallet/payment.vkey)

stake_key="86c769419aaa673c963da04e4b5bae448d490e2ceac902cb82e4da76"
output_address=$(${cli} address build --payment-verification-key-file ../wallets/${seller}-wallet/payment.vkey --stake-key-hash ${stake_key} ${network})

# market script
market_script_path="../../contracts/market_contract.plutus"
market_script_address=$(${cli} conway address build --payment-script-file ${market_script_path} ${network})

# get user utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${seller_address} \
    --out-file ../tmp/seller_utxo.json

TXNS=$(jq length ../tmp/seller_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${seller_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/seller_utxo.json)
seller_tx_in=${TXIN::-8}

market_datum_file_path="../data/market-datum.json"
output_datum_file_path="../data/output-datum.json"

# change this to whatever you want to sell
tokens="1 b0cbd7cde289d6aa694214fcd95a39e7f3ef52fc94d1171664210677.acab"

# leave blank for lovelace payment
payment_pid="b3ad6187273d174b586b1c86d4c6c7eeefa7bdca6dd819f125d4dd06"
payment_tkn="74494147"
payment_amt=12345678
payment_token="${payment_amt} ${payment_pid}.${payment_tkn}"

required_lovelace=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ${market_datum_file_path} \
    --tx-out="${market_script_address} + 5000000 + ${tokens}" | tr -dc '0-9')

if [ -z "$payment_token" ]; then
    payment_lovelace=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ${output_datum_file_path} \
    --tx-out="${output_address} + 5000000" | tr -dc '0-9')
else
    payment_lovelace=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ${output_datum_file_path} \
    --tx-out="${output_address} + 5000000 + ${payment_token}" | tr -dc '0-9')
fi

if [ "$required_lovelace" -ge "$payment_lovelace" ]; then
    minimum_lovelace=${required_lovelace}
else
    minimum_lovelace=${payment_lovelace}
fi

market_script_output="${market_script_address} + ${minimum_lovelace} + ${tokens}"
echo "Output: "${market_script_output}

# update the datums here

jq -r \
--arg seller_pkh "$seller_pkh" \
--arg payment_pid "$payment_pid" \
--arg payment_tkn "$payment_tkn" \
--argjson payment_amt "$payment_amt" \
'.fields[0].fields[0].fields[0].bytes=$seller_pkh |
.fields[1].fields[0].bytes=$payment_pid |
.fields[1].fields[1].bytes=$payment_tkn |
.fields[1].fields[2].int=$payment_amt' \
../data/market-datum.json | sponge ../data/market-datum.json

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${seller_address} \
    --tx-in ${seller_tx_in} \
    --tx-out="${market_script_output}" \
    --tx-out-inline-datum-file ../data/market-datum.json \
    ${network})

echo -e "\033[0;35m${FEE} \033[0m"
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/${seller}-wallet/payment.skey \
    --tx-body-file ../tmp/tx.draft \
    --out-file ../tmp/tx.signed \
    ${network}
#
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} conway transaction submit \
    ${network} \
    --tx-file ../tmp/tx.signed

tx=$(${cli} conway transaction txid --tx-file ../tmp/tx.signed)
echo "Tx Hash:" $tx