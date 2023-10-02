SERVICE_NAME_PREFIX = "prelaunch-data-generator-"

# Launches a prelaunch data generator IMAGE, for use in various of the genesis generation
def launch_prelaunch_data_generator(
    plan,
	service_name_suffix,
	network_id,
	deposit_contract_address,
	preregistered_validator_keys_mnemonic,
	seconds_per_slot,
	total_num_validator_keys_to_preregister,
	capella_fork_epoch,
	deneb_fork_epoch,
	electra_fork_epoch,
	genesis_unix_timestamp,
	genesis_delay,
):
    config = get_config(
		network_id,
		deposit_contract_address,
		preregistered_validator_keys_mnemonic,
		seconds_per_slot,
		total_num_validator_keys_to_preregister,
		capella_fork_epoch,
		deneb_fork_epoch,
		electra_fork_epoch,
		genesis_unix_timestamp,
		genesis_delay,
    )

    service_name = "{0}{1}".format(
        SERVICE_NAME_PREFIX,
        service_name_suffix,
    )
    plan.add_service(service_name, config)

    return service_name


def launch_prelaunch_data_generator_parallel(
    plan,
	service_name_suffix,
	network_id,
	deposit_contract_address,
	preregistered_validator_keys_mnemonic,
	seconds_per_slot,
	total_num_validator_keys_to_preregister,
	capella_fork_epoch,
	deneb_fork_epoch,
	electra_fork_epoch,
	genesis_unix_timestamp,
	genesis_delay,
):
    config = get_config(
		network_id,
		deposit_contract_address,
		preregistered_validator_keys_mnemonic,
		seconds_per_slot,
		total_num_validator_keys_to_preregister,
		capella_fork_epoch,
		deneb_fork_epoch,
		electra_fork_epoch,
		genesis_unix_timestamp,
		genesis_delay,
    )
    service_names = [
        "{0}{1}".format(
            SERVICE_NAME_PREFIX,
            service_name_suffix,
        )
        for service_name_suffix in service_name_suffixes
    ]
    services_to_add = {service_name: config for service_name in service_names}
    plan.add_services(services_to_add)
    return service_names


def get_config(
	network_id,
	deposit_contract_address,
	preregistered_validator_keys_mnemonic,
	seconds_per_slot,
	total_num_validator_keys_to_preregister,
	capella_fork_epoch,
	deneb_fork_epoch,
	electra_fork_epoch,
	genesis_unix_timestamp,
	genesis_delay,
	):


    if capella_fork_epoch > 0 and electra_fork_epoch == None:  # we are running capella
        img = "ethpandaops/ethereum-genesis-generator:1.3.12"
    elif (capella_fork_epoch == 0 and electra_fork_epoch == None):  # we are running dencun
        img = "ethpandaops/ethereum-genesis-generator:2.0.0"
    else:  # we are running electra
        img = "ethpandaops/ethereum-genesis-generator:3.0.0-rc.2"

    return ServiceConfig(
        image=img,
        files= {"/output": el_cl_genesis_data.files_artifact_uuid},
		env_vars={
			"CHAIN_ID": network_id,
			"DEPOSIT_CONTRACT_ADDRESS": deposit_contract_address,
			"EL_AND_CL_MNEMONIC": preregistered_validator_keys_mnemonic,
			"SLOT_DURATION_IN_SECONDS": seconds_per_slot,
			"NUMBER_OF_VALIDATORS": total_num_validator_keys_to_preregister,
			"DENEB_FORK_EPOCH": deneb_fork_epoch,
			"ELECTRA_FORK_EPOCH": electra_fork_epoch,
			"GENESIS_TIMESTAMP": genesis_unix_timestamp,
			"GENESIS_DELAY": genesis_delay,
		}

    )
