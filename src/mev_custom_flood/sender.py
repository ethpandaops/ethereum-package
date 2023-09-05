from web3 import Web3
from web3.middleware import construct_sign_and_send_raw_middleware
import os
import time
import logging

logging.basicConfig(filename="/tmp/sender.log",
                    filemode='a',
                    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                    datefmt='%H:%M:%S',
                    level=logging.DEBUG)


def flood():
    # Note: Never commit your key in your code! Use env variables instead:
    sender = os.getenv("SENDER_PRIVATE_KEY", "17fdf89989597e8bcac6cdfcc001b6241c64cece2c358ffc818b72ca70f5e1ce")
    receiver = os.getenv("RECEIVER_PUBLIC_KEY", "0x878705ba3f8Bc32FCf7F4CAa1A35E72AF65CF766")
    el_uri = os.getenv("EL_RPC_URI", 'http://0.0.0.0:53913')

    logging.info(f"Using sender {sender} receiver {receiver} and el_uri {el_uri}")

    w3 = Web3(Web3.HTTPProvider(el_uri))

    # Instantiate an Account object from your key:
    sender_account = w3.eth.account.from_key(sender)

    while True:
        time.sleep(3)
        
        # Add sender_account as auto-signer:
        w3.middleware_onion.add(construct_sign_and_send_raw_middleware(sender_account))
        # sender also works: w3.middleware_onion.add(construct_sign_and_send_raw_middleware(sender))

        # Transactions from `sender_account` will then be signed, under the hood, in the middleware:
        tx_hash = w3.eth.send_transaction({
            "from": sender_account.address,
            "value": 0x9184e72a,
            "to": receiver,
            "data": "0xabcd",
            "gasPrice": "0x9184e72a000",
            "gas": "0x76c0"
        })

        tx = w3.eth.get_transaction(tx_hash)
        logging.info(tx_hash.hex())
        assert tx["from"] == sender_account.address


if __name__ == "__main__":
    flood()