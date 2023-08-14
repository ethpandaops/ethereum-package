IMAGE_NAME = "ethpandaops/tx-fuzz:latest"
SERVICE_NAME = "transaction-spammer"

def launch_transaction_spammer(plan, prefunded_addresses, el_client_context):
	config = get_config(prefunded_addresses, el_client_context)
	plan.add_service(SERVICE_NAME, config)


def get_config(prefunded_addresses, el_client_context):
	private_keys_strs = []
	address_strs = []

	return ServiceConfig(
		image = IMAGE_NAME,
		cmd = [
			"spam",
			"--rpc=http://{0}:{1}".format(el_client_context.ip_addr, el_client_context.rpc_port_num),
			"--sk={0}".format(prefunded_addresses[0].private_key),
		]
	)

