use aiken/option
use cardano/transaction.{Output, OutputReference, Transaction}
use types/market.{Buy, Datum, Redeemer, RemoveOrUpdate}
use types/token
use validate/output
use validate/signature

validator contract {
  spend(
    maybe_datum: Option<Data>,
    redeemer: Redeemer,
    utxo: OutputReference,
    transaction: Transaction,
  ) {
    // do a data structure check
    when maybe_datum is {
      // there is a datum on it so check if its in the correct form
      Some(market_datum) ->
        if market_datum is Datum {
          let Transaction { outputs, extra_signatories, .. } = transaction
          // it is the Datum type so check the redeemer
          when redeemer is {
            // user may remove or update
            RemoveOrUpdate ->
              signature.is_valid(extra_signatories, market_datum.address)?
            // user may buy this
            Buy(output_offset) -> {
              // find the payment output for this input and check all the fields
              let Output { address, value, datum, reference_script } =
                output.find_payment(outputs, output_offset)
              //
              // The output must go to the address defined in the datum. The output
              // will contain a datum to defeat the double satisfaction problem. The
              // output may not contain any reference scripts and the value must either
              // be just ADA or ADA and the token. The token amount must be positive.
              // The tokens on this input may go anywhere the buyer wants them to go.
              //
              and {
                (address == market_datum.address)?,
                (datum == output.is_unique(utxo))?,
                (reference_script |> option.is_none)?,
                token.is_contained(value, market_datum.token)?,
                (market_datum.token.amt > 0)?,
              }
            }
          }
        } else {
          // its not the Datum type so let be spendable
          True
        }
      // there is no datum on it so let be spendable
      None -> True
    }
  }

  else(_) {
    fail
  }
}
