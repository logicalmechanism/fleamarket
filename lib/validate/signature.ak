use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address, VerificationKey}

pub fn is_valid(
  extra_signatories: List<VerificationKeyHash>,
  owner: Address,
) -> Bool {
  when owner.payment_credential is {
    VerificationKey(pkh) -> list.has(extra_signatories, pkh)
    // scripts can not sign so let it be spendable
    _ -> True
  }
}
