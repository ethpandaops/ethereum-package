"""
this is s a really dumb script that sends tokens to the receiver from the sender every 3 seconds
this is being used as of 2023-09-06 to guarantee that payloads are delivered
"""

from web3 import Web3
from web3.middleware import construct_sign_and_send_raw_middleware
import os
import time
import logging

VALUE_TO_SEND = 0x9184

logging.basicConfig(filename="/tmp/sender.log",
                    filemode='a',
                    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                    datefmt='%H:%M:%S',
                    level=logging.DEBUG)


def flood():
    # this is the last prefunded address
    sender = os.getenv("SENDER_PRIVATE_KEY", "17fdf89989597e8bcac6cdfcc001b6241c64cece2c358ffc818b72ca70f5e1ce")
    # this is the first prefunded address
    receiver = os.getenv("RECEIVER_PUBLIC_KEY", "0x878705ba3f8Bc32FCf7F4CAa1A35E72AF65CF766")
    el_uri = os.getenv("EL_RPC_URI", 'http://0.0.0.0:53913')

    logging.info(f"Using sender {sender} receiver {receiver} and el_uri {el_uri}")

    w3 = Web3(Web3.HTTPProvider(el_uri))

    sender_account = w3.eth.account.from_key(sender)

    while True:
        time.sleep(3)

        w3.middleware_onion.add(construct_sign_and_send_raw_middleware(sender_account))

        transaction = {
            "from": sender_account.address,
            "value": VALUE_TO_SEND,
            "to": receiver,
            "data": "0xabcd",
            "gasPrice": w3.eth.gas_price,
        }

        estimated_gas = w3.eth.estimate_gas(transaction)

        transaction["gas"] = estimated_gas

        tx_hash = w3.eth.send_transaction(transaction)

        tx = w3.eth.get_transaction(tx_hash)
        logging.info(tx_hash.hex())
        assert tx["from"] == sender_account.address


def run_infinitely():
    while True:
        try:
            flood()
        except Exception as e:
            print("e")
            print("restarting flood as previous one failed")


if __name__ == "__main__":
    run_infinitely()
