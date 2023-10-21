"""
this is s a really dumb script that sends tokens to the receiver from the sender every 3 seconds
this is being used as of 2023-09-06 to guarantee that payloads are delivered
"""
from functools import partial

from web3 import Web3
from web3.middleware import construct_sign_and_send_raw_middleware
import os
import time
import logging
import click


VALUE_TO_SEND = 0x9184

logging.basicConfig(filename="/tmp/sender.log",
                    filemode='a',
                    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                    datefmt='%H:%M:%S',
                    level=logging.DEBUG)

# this is the last prefunded address
SENDER = os.getenv("SENDER_PRIVATE_KEY", "17fdf89989597e8bcac6cdfcc001b6241c64cece2c358ffc818b72ca70f5e1ce")
# this is the first prefunded address
RECEIVER = os.getenv("RECEIVER_PUBLIC_KEY", "0x878705ba3f8Bc32FCf7F4CAa1A35E72AF65CF766")
EL_URI = os.getenv("EL_RPC_URI", 'http://0.0.0.0:53913')


def send_transaction():
    # Setting w3 as constant causes recursion exceeded error after ~500 transactions
    # Thus it's created everytime a transaction is sent
    w3 = Web3(Web3.HTTPProvider(EL_URI))

    sender_account = w3.eth.account.from_key(SENDER)
    w3.middleware_onion.add(construct_sign_and_send_raw_middleware(sender_account))

    transaction = {
        "from": sender_account.address,
        "value": VALUE_TO_SEND,
        "to": RECEIVER,
        "data": "0xabcd",
        "gasPrice": w3.eth.gas_price,
    }

    estimated_gas = w3.eth.estimate_gas(transaction)

    transaction["gas"] = estimated_gas

    tx_hash = w3.eth.send_transaction(transaction)

    tx = w3.eth.get_transaction(tx_hash)
    logging.info(tx_hash.hex())
    assert tx["from"] == sender_account.address


def delayed_send(interval_between_transactions):
    send_transaction()
    time.sleep(interval_between_transactions)


@click.command()
@click.option('--interval_between_transactions', default=0.5, help='Interval between successive transaction sends (in seconds). The value may be an integer or decimal')
def run_infinitely(interval_between_transactions):
    logging.info(f"Using sender {SENDER} receiver {RECEIVER} and el_uri {EL_URI}")
    spam = send_transaction if interval_between_transactions == 0 else partial(delayed_send, interval_between_transactions)
    while True:
        try:
            spam()
        except Exception as e:
            print(e)
            print("restarting flood as previous one failed")


if __name__ == "__main__":
    run_infinitely()
