IMAGE_NAME = "ethpandaops/tx-fuzz:latest"
SERVICE_NAME = "blob-spammer"

ENTRYPOINT_ARGS = ["/bin/sh", "-c"]

def launch_blob_spammer(
	plan,
	prefunded_addresses,
	el_client_context,
	deneb_fork_epoch,
	seconds_per_slot,
	slots_per_epoch,
	genesis_delay):
	config = get_config(
		prefunded_addresses,
		el_client_context,
		deneb_fork_epoch,
		seconds_per_slot,
		slots_per_epoch,
		genesis_delay)
	plan.add_service(SERVICE_NAME, config)

def get_config(
	prefunded_addresses,
	el_client_context,
	deneb_fork_epoch,
	seconds_per_slot,
	slots_per_epoch,
	genesis_delay):
	private_keys_strs = []
	address_strs = []
	dencunTime = (deneb_fork_epoch * slots_per_epoch * seconds_per_slot) + genesis_delay
	return ServiceConfig(
		image = IMAGE_NAME,
		entrypoint = ENTRYPOINT_ARGS,
		cmd = [" && ".join([
			"echo 'sleeping for {0} seconds, waiting for dencun'".format(dencunTime),
			"sleep {0}".format(dencunTime),
			"echo 'sleep is over, starting to send blob transactions'",
			"/tx-fuzz.bin blobs --rpc=http://{0}:{1} --sk={2}".format(el_client_context.ip_addr, el_client_context.rpc_port_num, prefunded_addresses[1].private_key),
		])]
	)

