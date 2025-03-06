use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/primitive/bytearray
use cardano/address.{Address, VerificationKey}

///
///
pub fn is_valid(
  extra_signatories: List<VerificationKeyHash>,
  owner: Address,
) -> Bool {
  when owner.payment_credential is {
    VerificationKey(pkh) ->
      if bytearray.length(pkh) == 28 {
        //
        // proper keys can sign
        list.has(extra_signatories, pkh)
      } else {
        //
        // improper keys can't sign so let it be spendable
        True
      }
    //
    // scripts can't sign so let it be spendable
    _ -> True
  }
}
