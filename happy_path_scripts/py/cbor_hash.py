import cbor2
import binascii
import hashlib

def parse(txid_idx: str) -> tuple[str, int]:
    data = txid_idx.split('#')
    return data[0], int(data[1])

def generate(txid: str, txidx: int) -> str:
    """
    Create a CBOR hex string from a transaction ID and transaction index.

    Args:
        txid (str): The transaction ID as a hex string.
        txidx (int): The transaction index.

    Returns:
        str: CBOR-encoded data as a hex string.
    """
    # Ensure txid is properly formatted as a bytes object
    txid_bytes = bytes.fromhex(txid)

    # Construct the indefinite-length array manually
    indefinite_array = b'\x9f'  # Start indefinite-length array marker
    indefinite_array += cbor2.dumps(txid_bytes)  # Add the transaction ID
    indefinite_array += cbor2.dumps(txidx)  # Add the transaction index
    indefinite_array += b'\xff'  # End of indefinite-length array marker

    # Wrap the CBOR structure in Tag 121
    tagged_cbor = b'\xd8\x79' + indefinite_array

    # Return the hex representation of the CBOR
    return hashlib.blake2b(tagged_cbor, digest_size=32).hexdigest()

def double_hash_generate(txid: str, txidx: int) -> str:
    # Ensure txid is properly formatted as a bytes object
    txid_bytes = bytes.fromhex(txid)

    # Construct the indefinite-length array manually
    indefinite_array = b'\x9f'  # Start indefinite-length array marker
    indefinite_array += cbor2.dumps(txid_bytes)  # Add the transaction ID
    indefinite_array += cbor2.dumps(txidx)  # Add the transaction index
    indefinite_array += b'\xff'  # End of indefinite-length array marker

    # Wrap the CBOR structure in Tag 121
    tagged_cbor = b'\xd8\x79' + indefinite_array

    # Return the hex representation of the CBOR
    the_hash = hashlib.blake2b(tagged_cbor, digest_size=32).hexdigest()
    return hashlib.blake2b(binascii.unhexlify(the_hash), digest_size=32).hexdigest()

# Example usage
if __name__ == "__main__":
    txid_idx = "5038AAE27F15421282DC71B28E0253E7168E8E60E8352131191E1704413D913A#0"
    txid, txidx = parse(txid_idx)
    cbor_hex = generate(txid, txidx)
    double_cbor_hex = double_hash_generate(txid, txidx)
    print(cbor_hex)
    print(double_cbor_hex)
