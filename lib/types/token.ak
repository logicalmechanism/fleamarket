use cardano/assets.{AssetName, PolicyId, Value}

/// Generic Token type for payments.
pub type Token {
  pid: PolicyId,
  tkn: AssetName,
  amt: Int,
}

/// Check that a token is contained inside of a value. If the token is ADA then
/// only ada can be contained in the value else ADA and the token must be contained
/// inside the value. In the case of non-ADA tokens, the minimum required Lovelace
/// is not validated as it will scale naturally.
///
pub fn is_contained(self: Value, token: Token) -> Bool {
  if and {
    token.pid == assets.ada_policy_id,
    token.tkn == assets.ada_asset_name,
  } {
    //
    // if ada then the value can only be ada
    expect [(_, _, amt)]: List<(PolicyId, AssetName, Int)> =
      assets.flatten(self)
    token.amt == amt
  } else {
    //
    // else it can be ada and the token
    expect [(_, _, _),
      (pid, tkn, amt)]: List<(PolicyId, AssetName, Int)> = assets.flatten(self)
    //
    // check the token and let ada scale naturally
    and {
      token.pid == pid,
      token.tkn == tkn,
      token.amt == amt,
    }
  }
}
