"""
this script deploys the contract used by eip4788. It has been presigned and the contract uses a deterministic deployment.

"""

from web3 import Web3
from web3.middleware import construct_sign_and_send_raw_middleware
import os
import time
import logging
from decimal import Decimal

VALUE_TO_SEND = 0x9184

logging.basicConfig(filename="/tmp/sender.log",
                    filemode='a',
                    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                    datefmt='%H:%M:%S',
                    level=logging.INFO)


def eip4788_deployment():
    # this is the 5th prefunded address
    sender = os.getenv("SENDER_PRIVATE_KEY", "7da08f856b5956d40a72968f93396f6acff17193f013e8053f6fbb6c08c194d6")
    # this is the 4788 presigned contract deployer
    receiver = os.getenv("RECEIVER_PUBLIC_KEY", "0x0B799C86a49DEeb90402691F1041aa3AF2d3C875")
    signed_4788_deployment_tx = os.getenv("SIGNED_4788_DEPLOYMENT_TX", "f8838085e8d4a510008303d0908080b86a60618060095f395ff33373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff0155001b820539851b9b6eb1f0")
    # el_uri = os.getenv("EL_RPC_URI", 'http://0.0.0.0:53913')
    el_uri = os.getenv("EL_RPC_URI", 'https://rpc.dencun-devnet-9.ethpandaops.io')
    logging.info(f"Using sender {sender} receiver {receiver} and el_uri {el_uri}")

    w3 = Web3(Web3.HTTPProvider(el_uri))
    # sleep for 10s before checking again
    time.sleep(10)

    # Check if the chain has started before submitting transactions
    block = w3.eth.get_block('latest')

    logging.info(f"Latest block number: {block.number}")
    if block.number >1:
      logging.info("Chain has started, proceeding with Funding")
      # Import sender account
      sender_account = w3.eth.account.from_key(sender)
      # Prepare to Construct and sign transaction
      w3.middleware_onion.add(construct_sign_and_send_raw_middleware(sender_account))

      # Prepare funding transaction
      logging.info("Preparing funding tx")
      transaction = {
        "from": sender_account.address,
        "to": receiver,
        "value": w3.to_wei(Decimal('1000.0'), 'ether'),  # Sending 1000 Ether
        "gasPrice": w3.eth.gas_price,
        'nonce': w3.eth.get_transaction_count(sender_account.address)
      }

      # Estimate gas
      logging.info("Estimating gas")
      estimated_gas = w3.eth.estimate_gas(transaction)

      # Set gas value
      transaction["gas"] = estimated_gas

      # Send transaction
      logging.debug(f"Sending deployment tx: {transaction}")
      tx_hash = w3.eth.send_transaction(transaction)

      time.sleep(10)
      # Wait for the transaction to be mined
      funding_tx = w3.eth.get_transaction(tx_hash)
      logging.debug(f"Funding Txhash: {tx_hash.hex()}")
      logging.info(f"Genesis funder Balance: {w3.eth.get_balance(sender_account.address)}")
      logging.info(f"4788 deployer Balance: {w3.eth.get_balance(receiver)}")

      if funding_tx["from"] == sender_account.address:
        logging.info("Funding tx mined successfully")
        logging.info("Deploying signed tx")
        # Prepare deployment transaction
        deployment_tx_hash = w3.eth.send_raw_transaction(signed_4788_deployment_tx)

        # Sleep before checking
        time.sleep(10)
        deployment_tx = w3.eth.get_transaction(deployment_tx_hash)
        logging.debug(f"Deployment Txhash: {deployment_tx.hash.hex()}")

        # Sleep before checking
        time.sleep(10)

        logging.info(f"4788 deployer Balance: {w3.eth.get_balance(receiver)}")
        assert deployment_tx["from"] == receiver

        # Check if contract has been deployed
        eip4788_code = w3.eth.get_code('0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02')
        if eip4788_code != "":
          logging.info(f"Contract deployed: {eip4788_code.hex()}")
          logging.info("Deployment tx mined successfully")

          # Exit script
          return True
        else:
          logging.info("Deployment failed, restarting script")
          return False
      else:
        logging.info("Funding failed, restarting script")
        return False
    else:
      logging.info("Chain has not started, restarting script")
      return False

def run_till_deployed():
    deployment_status = False
    while deployment_status is False:
        try:
          deployment_status = eip4788_deployment()
        except Exception as e:
          logging.error(e)
          logging.error("restarting deployment as previous one failed")



if __name__ == "__main__":
    run_till_deployed()
    logging.info("Deployment complete, exiting script")
