use cardano/address.{Address}
use types/token.{Token}

pub type Datum {
  address: Address,
  token: Token,
}

pub type Redeemer {
  Buy { output_offset: Int }
  RemoveOrUpdate
}

test trace_address() {
  let addr: Address =
    address.from_verification_key(
      #"99fc1a514a232b29a18db7635e6650b8cf65b65da83491532cb928dd",
    )
      |> address.with_delegation_key(
          #"5b7e1c5c4098962aca148e279363cc09e681268a5995d9d226e93b5d",
        )
  trace addr
  addr == addr
}
