IMAGE_NAME = "kurtosistech/tx-fuzz:0.2.0"
SERVICE_ID = "transaction-spammer"

def launch_transaction_spammer(prefunded_addresses, el_client_context):
	config = get_config(prefunded_addresses, el_client_context)
	add_service(SERVICE_ID, config)


def get_config(prefunded_addresses, el_client_context):
	private_keys_strs = []
	address_strs = []

	for prefunded_address in prefunded_addresses:
		private_keys_strs.append(prefunded_address.private_key)
		address_strs.append(prefunded_address.address)

	comma_separated_private_keys = ",".join(private_keys_strs)
	comma_separated_addresses = ",".join(address_strs)
	return struct(
		image = IMAGE_NAME,
		cmd = [
			"http://{0}:{1}".format(el_client_context.ip_addr, el_client_context.rpc_port_num),
			"spam",
			comma_separated_private_keys,
			comma_separated_addresses
		]
	)

