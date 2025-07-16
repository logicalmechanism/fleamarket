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

# collat wallet
collat_wallet_path="../wallets/collat-wallet"
collat_address=$(cat ${collat_wallet_path}/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ${collat_wallet_path}/payment.vkey)

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
    --address ${deal_script_address} \
    --out-file ../tmp/deal_utxo.json
TXNS=$(jq length ../tmp/deal_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${deal_script_address} \033[0m \n";
   exit;
fi

deal_datum_file_path="../data/deal/deal-datum.json"
seller_output_datum_file_path="../data/deal/seller-output-datum.json"
buyer_output_datum_file_path="../data/deal/buyer-output-datum.json"

TXIN=$(jq -r --arg alltxin "" --arg seller_pkh "$seller_pkh" 'to_entries[] | select(.value.inlineDatum.fields[0].fields[0].fields[0].bytes == $seller_pkh) | .key | . + $alltxin + " --tx-in"' ../tmp/deal_utxo.json)
script_tx_in=${TXIN::-8}
echo Script UTxO: ${script_tx_in}

# assume lovelace for now
payment_pid=$(jq -r --arg script_tx_in "$script_tx_in" '.[$script_tx_in].inlineDatum.fields[2].fields[0].bytes' ../tmp/deal_utxo.json)
payment_tkn=$(jq -r --arg script_tx_in "$script_tx_in" '.[$script_tx_in].inlineDatum.fields[2].fields[1].bytes' ../tmp/deal_utxo.json)
payment_amt=$(jq -r --arg script_tx_in "$script_tx_in" '.[$script_tx_in].inlineDatum.fields[2].fields[2].int' ../tmp/deal_utxo.json)

if [ -z "$payment_pid" ]; then
    seller_output="${seller_output_address} + ${payment_amt}"
else
    payment_token="${payment_amt} ${payment_pid}.${payment_tkn}"
    payment_lovelace=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ${seller_output_datum_file_path} \
    --tx-out="${seller_output_address} + 5000000 + ${payment_token}" | tr -dc '0-9')
    seller_output="${seller_output_address} + ${payment_lovelace} + ${payment_token}"
fi
echo "Seller Output: "${seller_output}

# change this to whatever you want to sell
tokens="1 b0cbd7cde289d6aa694214fcd95a39e7f3ef52fc94d1171664210677.acab"
required_lovelace=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ${deal_datum_file_path} \
    --tx-out="${buyer_output_address} + 5000000 + ${tokens}" | tr -dc '0-9')

buyer_output="${buyer_output_address} + ${required_lovelace} + ${tokens}"
echo "Buyer Output: "${buyer_output}

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

script_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/utxo-deal_contract.plutus.signed )

seller_output_hash=$(python3 -c "import sys; sys.path.insert(0, '../py');from cbor_hash import generate, parse; txid, idx = parse('${script_tx_in}'); output = generate(txid, idx); print(output)")
buyer_output_hash=$(python3 -c "import sys; sys.path.insert(0, '../py');from cbor_hash import double_hash_generate, parse; txid, idx = parse('${script_tx_in}'); output = double_hash_generate(txid, idx); print(output)")

jq -r \
--arg out_ref_hash "$seller_output_hash" \
'.bytes=$out_ref_hash' \
../data/deal/seller-output-datum.json | sponge ../data/deal/seller-output-datum.json

jq -r \
--arg out_ref_hash "$buyer_output_hash" \
'.bytes=$out_ref_hash' \
../data/deal/buyer-output-datum.json | sponge ../data/deal/buyer-output-datum.json

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
    --spending-reference-tx-in-redeemer-file ../data/deal/buy-redeemer.json \
    --tx-out="${seller_output}" \
    --tx-out-inline-datum-file ${seller_output_datum_file_path} \
    --tx-out="${buyer_output}" \
    --tx-out-inline-datum-file ${buyer_output_datum_file_path} \
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
