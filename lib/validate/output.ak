//// Portions of this code are derived from [jpg-store] (https://github.com/jpg-store/contracts-v3/tree/main), licensed under the Apache License 2.0.
////
//// Changes made to the original jpg-store code:
//// - Made datum tag a function.
//// - Changed function names.
//// - Finding the payment output returns a singular output and not a list.
////

use aiken/builtin.{blake2b_256, serialise_data, tail_list}
use cardano/transaction.{Datum, InlineDatum, Output, OutputReference}

pub fn seller_output_is_unique(output_reference: OutputReference) -> Datum {
  output_reference
    |> serialise_data
    |> blake2b_256
    |> InlineDatum
}

pub fn buyer_output_is_unique(output_reference: OutputReference) -> Datum {
  output_reference
    |> serialise_data
    |> blake2b_256
    |> blake2b_256
    |> InlineDatum
}

// need to trace output reference to know its structure
test output_reference_is_unique() {
  let output_reference: OutputReference =
    OutputReference {
      transaction_id: #"5038aae27f15421282dc71b28e0253e7168e8e60e8352131191e1704413d913a",
      output_index: 0,
    }
  trace output_reference
  let data = output_reference |> serialise_data
  let datum: Datum = seller_output_is_unique(output_reference)
  trace datum |> serialise_data
  and {
    data == #"d8799f58205038aae27f15421282dc71b28e0253e7168e8e60e8352131191e1704413d913a00ff",
    ( data |> blake2b_256 ) == #"019d93c81272a175ef78fc0805690219eacc062ff46a52c9840d554552a63f12",
  }
}

test output_reference_is_unique2() {
  let output_reference: OutputReference =
    OutputReference {
      transaction_id: #"5038aae27f15421282dc71b28e0253e7168e8e60e8352131191e1704413d913a",
      output_index: 0,
    }
  trace output_reference
  let data = output_reference |> serialise_data
  let datum: Datum = buyer_output_is_unique(output_reference)
  trace datum |> serialise_data
  ( data |> blake2b_256 |> blake2b_256 ) == #"79020d1e70e4327c4154ee5f6501edc51fc0980e3b18e4b3f1dd4dbaeba33fa7"
}

pub fn find_payment(outputs: List<Output>, output_offset: Int) -> Output {
  if output_offset >= 10 {
    outputs
      |> skip_10_items
      |> find_payment(output_offset - 10)
  } else {
    do_find_payment(outputs, output_offset)
  }
}

fn do_find_payment(outputs: List<Output>, current_index: Int) -> Output {
  if current_index == 0 {
    // we just want this output only here
    expect [output, ..] = outputs
    output
  } else {
    outputs
      |> tail_list
      |> do_find_payment(current_index - 1)
  }
}

fn skip_10_items(some_list: List<a>) -> List<a> {
  some_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
}
