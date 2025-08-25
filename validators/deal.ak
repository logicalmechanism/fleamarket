//// A hyperstructure UTxO deal without fees or royalty payouts. UTxOs 
//// may be traded for ADA or other tokens. A deal is between the seller
//// and the buyer only.
////

use aiken/option
use cardano/assets.{Value}
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use types/deal.{DealBuy, DealDatum, DealRedeemer, DealRemoveOrUpdate}
use types/token
use validate/output
use validate/signature
use validate/value

validator contract {
  spend(
    maybe_datum: Option<Data>,
    redeemer: DealRedeemer,
    utxo: OutputReference,
    transaction: Transaction,
  ) {
    // do a data structure check
    when maybe_datum is {
      // there is a datum on it so check if its in the correct form
      Some(market_datum) ->
        if market_datum is DealDatum {
          let Transaction { inputs, outputs, extra_signatories, .. } =
            transaction
          //
          // it is the Datum type so check the redeemer
          when redeemer is {
            //
            // user may remove or update
            DealRemoveOrUpdate ->
              signature.is_valid(extra_signatories, market_datum.seller)?
            //
            // user may buy this
            DealBuy { output_offset } -> {
              // we need to get this value
              expect Some(this_input): Option<Input> =
                inputs
                  |> transaction.find_input(utxo)
              let this_value: Value = this_input.output.value
              //
              // find the seller output for this input and check all the fields
              let Output {
                address: seller_address,
                value: seller_value,
                datum: seller_datum,
                reference_script: seller_reference_script,
              } = output.find_payment(outputs, output_offset)
              // find the buyer output for this input and check all the fields
              let Output {
                address: buyer_address,
                value: buyer_value,
                datum: buyer_datum,
                reference_script: buyer_reference_script,
              } = output.find_payment(outputs, output_offset + 1)
              //
              //
              //
              and {
                // buyer must sign this tx
                signature.is_valid(extra_signatories, market_datum.buyer)?,
                // check the seller stuff
                (seller_address == market_datum.seller)?,
                (seller_datum == output.seller_output_is_unique(utxo))?,
                (seller_reference_script |> option.is_none)?,
                token.is_contained(seller_value, market_datum.token)?,
                (market_datum.token.amt > 0)?,
                // check the buyer stuff
                (buyer_address == market_datum.buyer)?,
                (buyer_datum == output.buyer_output_is_unique(utxo))?,
                (buyer_reference_script |> option.is_none)?,
                value.is_contained(buyer_value, this_value)?,
              }
            }
          }
        } else {
          //
          // its not the Datum type so let be spendable
          True
        }
      //
      // there is no datum on it so let be spendable
      None -> True
    }
  }

  else(_) {
    fail
  }
}
