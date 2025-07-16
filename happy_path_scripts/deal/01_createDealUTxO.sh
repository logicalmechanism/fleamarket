#!/usr/bin/env bash
set -e

# SET UP VARS HERE
source ../.env

mkdir -p ../tmp
${cli} conway query protocol-parameters ${network} --out-file ../tmp/protocol.json

seller="seller"
seller_address=$(cat ../wallets/${seller}-wallet/payment.addr)
seller_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/${seller}-wallet/payment.vkey)

buyer="buyer"
buyer_address=$(cat ../wallets/${buyer}-wallet/payment.addr)
buyer_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/${buyer}-wallet/payment.vkey)

stake_key="86c769419aaa673c963da04e4b5bae448d490e2ceac902cb82e4da76"
seller_output_address=$(${cli} address build --payment-verification-key-file ../wallets/${seller}-wallet/payment.vkey --stake-key-hash ${stake_key} ${network})
buyer_output_address=$(${cli} address build --payment-verification-key-file ../wallets/${buyer}-wallet/payment.vkey --stake-key-hash ${stake_key} ${network})

# deal script
deal_script_path="../../contracts/deal_contract.plutus"
deal_script_address=$(${cli} conway address build --payment-script-file ${deal_script_path} ${network})

# get user utxo
echo -e "\033[0;36m Gathering Seller UTxO Information  \033[0m"
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

deal_datum_file_path="../data/deal/deal-datum.json"
seller_output_datum_file_path="../data/deal/seller-output-datum.json"
buyer_output_datum_file_path="../data/deal/buyer-output-datum.json"

# change this to whatever you want to sell
tokens="1 b0cbd7cde289d6aa694214fcd95a39e7f3ef52fc94d1171664210677.acab"

# blank is lovelace
payment_pid="be8d48879d7f9088d682fa5118d9468eadcdba28caa720b7afdcc617"
payment_tkn="74494147"
payment_amt=123456789
payment_token="${payment_amt} ${payment_pid}.${payment_tkn}"

required_lovelace=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ${deal_datum_file_path} \
    --tx-out="${deal_script_address} + 5000000 + ${tokens}" | tr -dc '0-9')

deal_script_output="${deal_script_address} + ${required_lovelace} + ${tokens}"
echo "Output: "${deal_script_output}

# update the datums here

jq -r \
--arg seller_pkh "$seller_pkh" \
--arg buyer_pkh "$buyer_pkh" \
--arg payment_pid "$payment_pid" \
--arg payment_tkn "$payment_tkn" \
--argjson payment_amt "$payment_amt" \
'.fields[0].fields[0].fields[0].bytes=$seller_pkh |
.fields[1].fields[0].fields[0].bytes=$buyer_pkh |
.fields[2].fields[0].bytes=$payment_pid |
.fields[2].fields[1].bytes=$payment_tkn |
.fields[2].fields[2].int=$payment_amt' \
../data/deal/deal-datum.json | sponge ../data/deal/deal-datum.json

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${seller_address} \
    --tx-in ${seller_tx_in} \
    --tx-out="${deal_script_output}" \
    --tx-out-inline-datum-file ../data/deal/deal-datum.json \
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
