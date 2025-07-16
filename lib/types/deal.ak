use cardano/address.{Address}
use types/token.{Token}

/// The Datum holds the seller, buyer address, and the token payment required for the sale.
pub type DealDatum {
  seller: Address,
  buyer: Address,
  // This is the cost of the sale
  token: Token,
}

/// UTxos may be purchased via Buy or be removed or updated via RemoveOrUpdate.
pub type DealRedeemer {
  DealBuy
  DealRemoveOrUpdate
}
