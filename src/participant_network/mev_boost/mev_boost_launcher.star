load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/mev_boost/mev_boost_context.star", "new_mev_boost_context")

FLASHBOTS_MEV_BOOST_IMAGE = "flashbots/mev-boost"
FLASHBOTS_MEV_BOOST_PORT = 18550
FLASHBOTS_MEV_BOOST_PROTOCOL = "TCP"

USED_PORTS = {
	"api": new_port_spec(FLASHBOTS_MEV_BOOST_PORT, FLASHBOTS_MEV_BOOST_PORT)
}

NETWORK_ID_TO_NAME = {
	"5":        "goerli",
	"11155111": "sepolia",
	"3":        "ropsten",
}

def launch(mev_boost_launcher, service_id, network_id):
	service_config = get_service_config(mev_boost_launcher, network_id)

	mev_boost_service = add_service(service_id, service_config)

	return new_mev_boost_context(mev_boost_service.ip_address, FLASHBOTS_MEV_BOOST_PORT)


def get_service_config(mev_boost_launcher, network_id):
	command = ["mev-boost"]
	network_name = NETWORK_ID_TO_NAME.get(network_id, "network-{0}".format(network_id))

	command.append("-{0}".format(network_name))

	if mev_boost_launcher.should_check_relay:
		command.append("-relay-check")

	if len(mev_boost_launcher.relay_end_points) != 0:
		command.append("-relays")
		command.append(",".join(mev_boost_launcher.relay_end_points))

	return struct(
		container_image_name = FLASHBOTS_MEV_BOOST_IMAGE,
		used_ports = USED_PORTS,
		cmd_args = command
	)


def new_mev_boost_launcher(should_check_relay, relay_end_points):
    return struct(should_check_relay=should_check_relay, relay_end_points=relay_end_points)

