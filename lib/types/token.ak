use cardano/assets.{AssetName, PolicyId, Value}

pub type Token {
  pid: PolicyId,
  tkn: AssetName,
  amt: Int,
}

pub fn is_contained(self: Value, token: Token) -> Bool {
  if and {
    token.pid == assets.ada_policy_id,
    token.tkn == assets.ada_asset_name,
  } {
    // if ada then the value can only be ada
    expect [(_, _, amt)]: List<(PolicyId, AssetName, Int)> =
      assets.flatten(self)
    token.amt == amt
  } else {
    // else it can be ada and the token
    expect [(_, _, _),
      (pid, tkn, amt)]: List<(PolicyId, AssetName, Int)> = assets.flatten(self)
    // check the token and let ada scale naturally
    and {
      token.pid == pid,
      token.tkn == tkn,
      token.amt == amt,
    }
  }
}
