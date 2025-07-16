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

buyer="seller"
buyer_address=$(cat ../wallets/${buyer}-wallet/payment.addr)
buyer_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/${buyer}-wallet/payment.vkey)

# collat wallet
collat_wallet_path="../wallets/collat-wallet"
collat_address=$(cat ${collat_wallet_path}/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ${collat_wallet_path}/payment.vkey)

# market script
market_script_path="../../contracts/market_contract.plutus"
market_script_address=$(${cli} conway address build --payment-script-file ${market_script_path} ${network})

# get user utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${buyer_address} \
    --out-file ../tmp/buyer_utxo.json

TXNS=$(jq length ../tmp/buyer_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${buyer_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/buyer_utxo.json)
buyer_tx_in=${TXIN::-8}

echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${market_script_address} \
    --out-file ../tmp/market_utxo.json
TXNS=$(jq length ../tmp/market_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${market_script_address} \033[0m \n";
   exit;
fi

market_datum_file_path="../data/market/market-datum.json"
output_datum_file_path="../data/market/output-datum.json"

TXIN=$(jq -r --arg alltxin "" --arg seller_pkh "$seller_pkh" 'to_entries[] | select(.value.inlineDatum.fields[0].fields[0].fields[0].bytes == $seller_pkh) | .key | . + $alltxin + " --tx-in"' ../tmp/market_utxo.json)
script_tx_in=${TXIN::-8}

# assume lovelace for now
payment_pid=$(jq -r --arg script_tx_in "$script_tx_in" '.[$script_tx_in].inlineDatum.fields[2].fields[0].bytes' ../tmp/market_utxo.json)
payment_tkn=$(jq -r --arg script_tx_in "$script_tx_in" '.[$script_tx_in].inlineDatum.fields[2].fields[1].bytes' ../tmp/market_utxo.json)
payment_amt=$(jq -r --arg script_tx_in "$script_tx_in" '.[$script_tx_in].inlineDatum.fields[2].fields[2].int' ../tmp/market_utxo.json)

if [ -z "$payment_pid" ]; then
    seller_output="${output_address} + ${payment_amt}"
else
    payment_token="${payment_amt} ${payment_pid}.${payment_tkn}"
    payment_lovelace=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ${output_datum_file_path} \
    --tx-out="${output_address} + 5000000 + ${payment_token}" | tr -dc '0-9')
    seller_output="${output_address} + ${payment_lovelace} + ${payment_token}"
fi
echo "Output: "${seller_output}

echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${collat_address} \
    --out-file ../tmp/collat_utxo.json
TXNS=$(jq length ../tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_utxo=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

script_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/utxo-market_contract.plutus.signed )

out_ref_hash=$(python3 -c "import sys; sys.path.insert(0, '../py');from cbor_hash import generate, parse; txid, idx = parse('${script_tx_in}'); output = generate(txid, idx); print(output)")

jq -r \
--arg out_ref_hash "$out_ref_hash" \
'.bytes=$out_ref_hash' \
../data/output-datum.json | sponge ../data/output-datum.json

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${buyer_address} \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${buyer_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/market/buy-redeemer.json \
    --tx-out="${seller_output}" \
    --tx-out-inline-datum-file ${output_datum_file_path} \
    --required-signer-hash ${collat_pkh} \
    --required-signer-hash ${buyer_pkh} \
    ${network})

echo -e "\033[0;35m${FEE} \033[0m"
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/${buyer}-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
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
