shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
mev_boost_context_module = import_module("github.com/kurtosis-tech/eth2-package/src/mev_boost/mev_boost_context.star")
parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")

FLASHBOTS_MEV_BOOST_PROTOCOL = "TCP"

USED_PORTS = {
	"api": shared_utils.new_port_spec(parse_input.FLASHBOTS_MEV_BOOST_PORT, FLASHBOTS_MEV_BOOST_PROTOCOL, wait="5s")
}

NETWORK_ID_TO_NAME = {
	"5":		"goerli",
	"11155111": "sepolia",
	"3":		"ropsten",
}

def launch(plan, mev_boost_launcher, service_name, network_id, mev_boost_image):
	config = get_config(mev_boost_launcher, network_id, mev_boost_image)

	mev_boost_service = plan.add_service(service_name, config)

	return mev_boost_context_module.new_mev_boost_context(mev_boost_service.ip_address, parse_input.FLASHBOTS_MEV_BOOST_PORT)


def get_config(mev_boost_launcher, network_id, mev_boost_image):
	command = ["mev-boost"]

	if mev_boost_launcher.should_check_relay:
		command.append("-relay-check")

	return ServiceConfig(
		image = mev_boost_image,
		ports = USED_PORTS,
		cmd = command,
		env_vars = {
			# TODO(maybe) remove the hardcoding
			# This is set to match this file https://github.com/kurtosis-tech/eth-network-package/blob/main/static_files/genesis-generation-config/cl/config.yaml.tmpl#L11
			# latest-notes
			# does this need genesis time to be set as well
			"GENESIS_FORK_VERSION": "0x10000038",
			"BOOST_LISTEN_ADDR": "0.0.0.0:{0}".format(parse_input.FLASHBOTS_MEV_BOOST_PORT),
			# maybe this is breaking; this isn't verifyign the bid and not sending it to the validator
			"SKIP_RELAY_SIGNATURE_CHECK": "1",
			"RELAYS": mev_boost_launcher.relay_end_points[0]
		}
	)


def new_mev_boost_launcher(should_check_relay, relay_end_points):
	return struct(should_check_relay=should_check_relay, relay_end_points=relay_end_points)

