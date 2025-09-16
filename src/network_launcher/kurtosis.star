shared_utils = import_module("../shared_utils/shared_utils.star")
validator_keystores = import_module(
    "../prelaunch_data_generator/validator_keystores/validator_keystore_generator.star"
)

constants = import_module("../package_io/constants.star")

# The time that the CL genesis generation step takes to complete, based off what we've seen
# This is in seconds
CL_GENESIS_DATA_GENERATION_TIME = 5

# Each CL node takes about this time to start up and start processing blocks, so when we create the CL
#  genesis data we need to set the genesis timestamp in the future so that nodes don't miss important slots
# (e.g. Altair fork)
# TODO(old) Make this client-specific (currently this is Nimbus)
# This is in seconds
CL_NODE_STARTUP_TIME = 5


def launch(
    plan, network_params, args_with_right_defaults, parallel_keystore_generation
):
    num_participants = len(args_with_right_defaults.participants)
    plan.print("Generating cl validator key stores")
    validator_data = None
    if not parallel_keystore_generation:
        validator_data = validator_keystores.generate_validator_keystores(
            plan,
            network_params.preregistered_validator_keys_mnemonic,
            args_with_right_defaults.participants,
            args_with_right_defaults.docker_cache_params,
        )
    else:
        validator_data = validator_keystores.generate_valdiator_keystores_in_parallel(
            plan,
            network_params.preregistered_validator_keys_mnemonic,
            args_with_right_defaults.participants,
            args_with_right_defaults.docker_cache_params,
        )

    plan.print(json.indent(json.encode(validator_data)))

    # We need to send the same genesis time to both the EL and the CL to ensure that timestamp based forking works as expected
    final_genesis_timestamp = shared_utils.get_final_genesis_timestamp(
        plan,
        network_params.genesis_delay
        + CL_GENESIS_DATA_GENERATION_TIME
        + num_participants * CL_NODE_STARTUP_TIME,
    )

    # if preregistered validator count is 0 (default) then calculate the total number of validators from the participants
    total_number_of_validator_keys = network_params.preregistered_validator_count

    if network_params.preregistered_validator_count == 0:
        for participant in args_with_right_defaults.participants:
            total_number_of_validator_keys += participant.validator_count

    plan.print("Generating EL CL data")

    ethereum_genesis_generator_image = shared_utils.docker_cache_image_calc(
        args_with_right_defaults.docker_cache_params,
        args_with_right_defaults.ethereum_genesis_generator_params.image,
    )

    return (
        total_number_of_validator_keys,
        ethereum_genesis_generator_image,
        final_genesis_timestamp,
        validator_data,
    )
