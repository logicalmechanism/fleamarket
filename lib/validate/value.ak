use cardano/assets.{AssetName, PolicyId, Value}

pub fn is_contained(total: Value, target: Value) -> Bool {
  let flat: List<(PolicyId, AssetName, Int)> = assets.flatten(target)
  do_contains(total, flat)
}

// Internal only
fn do_contains(total: Value, flat: List<(PolicyId, AssetName, Int)>) -> Bool {
  when flat is {
    [(pid, tkn, amt), ..rest] ->
      if assets.quantity_of(total, pid, tkn) >= amt {
        do_contains(total, rest)
      } else {
        // something is missing
        False
      }
    // found all of them
    [] -> True
  }
}
