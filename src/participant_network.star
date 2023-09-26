cl_validator_keystores = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/cl_validator_keystores/cl_validator_keystore_generator.star"
)
el_genesis_data_generator = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/el_genesis/el_genesis_data_generator.star"
)
cl_genesis_data_generator = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/cl_genesis/cl_genesis_data_generator.star"
)

static_files = import_module(
    "github.com/kurtosis-tech/eth-network-package/static_files/static_files.star"
)

geth = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/geth/geth_launcher.star"
)
besu = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/besu/besu_launcher.star"
)
erigon = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/erigon/erigon_launcher.star"
)
nethermind = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/nethermind/nethermind_launcher.star"
)
reth = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/reth/reth_launcher.star"
)
ethereumjs = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/ethereumjs/ethereumjs_launcher.star"
)

lighthouse = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/cl/lighthouse/lighthouse_launcher.star"
)
lodestar = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/cl/lodestar/lodestar_launcher.star"
)
nimbus = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/cl/nimbus/nimbus_launcher.star"
)
prysm = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/cl/prysm/prysm_launcher.star"
)
teku = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/cl/teku/teku_launcher.star"
)

snooper = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/snooper/snooper_engine_launcher.star"
)

genesis_constants = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/genesis_constants/genesis_constants.star"
)
participant_module = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/participant.star"
)

package_io = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/constants.star"
)

BOOT_PARTICIPANT_INDEX = 0

# The time that the CL genesis generation step takes to complete, based off what we've seen
# This is in seconds
CL_GENESIS_DATA_GENERATION_TIME = 5

# Each CL node takes about this time to start up and start processing blocks, so when we create the CL
#  genesis data we need to set the genesis timestamp in the future so that nodes don't miss important slots
# (e.g. Altair fork)
# TODO(old) Make this client-specific (currently this is Nimbus)
# This is in seconds
CL_NODE_STARTUP_TIME = 5

CL_CLIENT_CONTEXT_BOOTNODE = None

GLOBAL_INDEX_ZFILL = {
    "zfill_values": [(1, 1), (2, 10), (3, 100), (4, 1000), (5, 10000)]
}


def launch_participant_network(
    plan,
    participants,
    network_params,
    global_log_level,
    parallel_keystore_generation=False,
):
    num_participants = len(participants)

    plan.print("Generating cl validator key stores")
    cl_validator_data = None
    if not parallel_keystore_generation:
        cl_validator_data = cl_validator_keystores.generate_cl_validator_keystores(
            plan, network_params.preregistered_validator_keys_mnemonic, participants
        )
    else:
        cl_validator_data = (
            cl_validator_keystores.generate_cl_valdiator_keystores_in_parallel(
                plan, network_params.preregistered_validator_keys_mnemonic, participants
            )
        )

    plan.print(json.indent(json.encode(cl_validator_data)))

    # We need to send the same genesis time to both the EL and the CL to ensure that timestamp based forking works as expected
    final_genesis_timestamp = get_final_genesis_timestamp(
        plan, CL_GENESIS_DATA_GENERATION_TIME + num_participants * CL_NODE_STARTUP_TIME
    )
    plan.print("Generating EL data")
    el_genesis_generation_config_template = read_file(
        static_files.EL_GENESIS_GENERATION_CONFIG_TEMPLATE_FILEPATH
    )
    el_genesis_data = el_genesis_data_generator.generate_el_genesis_data(
        plan,
        el_genesis_generation_config_template,
        final_genesis_timestamp,
        network_params.network_id,
        network_params.deposit_contract_address,
        network_params.genesis_delay,
        network_params.seconds_per_slot,
        network_params.capella_fork_epoch,
        network_params.deneb_fork_epoch,
        network_params.electra_fork_epoch,
    )

    plan.print(json.indent(json.encode(el_genesis_data)))

    plan.print("Uploading GETH prefunded keys")

    geth_prefunded_keys_artifact_name = plan.upload_files(
        static_files.GETH_PREFUNDED_KEYS_DIRPATH, name="geth-prefunded-keys"
    )

    plan.print("Uploaded GETH files succesfully")

    plan.print("Generating CL data")

    genesis_generation_config_yml_template = read_file(
        static_files.CL_GENESIS_GENERATION_CONFIG_TEMPLATE_FILEPATH
    )
    genesis_generation_mnemonics_yml_template = read_file(
        static_files.CL_GENESIS_GENERATION_MNEMONICS_TEMPLATE_FILEPATH
    )
    total_number_of_validator_keys = 0
    for participant in participants:
        total_number_of_validator_keys += participant.validator_count
    cl_genesis_data = cl_genesis_data_generator.generate_cl_genesis_data(
        plan,
        genesis_generation_config_yml_template,
        genesis_generation_mnemonics_yml_template,
        el_genesis_data,
        final_genesis_timestamp,
        network_params.network_id,
        network_params.deposit_contract_address,
        network_params.seconds_per_slot,
        network_params.preregistered_validator_keys_mnemonic,
        total_number_of_validator_keys,
        network_params.genesis_delay,
        network_params.capella_fork_epoch,
        network_params.deneb_fork_epoch,
        network_params.electra_fork_epoch,
    )

    plan.print(json.indent(json.encode(cl_genesis_data)))
    plan.print("Generated CL genesis data succesfully, launching EL & CL Participants")

    genesis_validators_root = cl_genesis_data.genesis_validators_root

    el_launchers = {
        package_io.EL_CLIENT_TYPE.geth: {
            "launcher": geth.new_geth_launcher(
                network_params.network_id,
                el_genesis_data,
                geth_prefunded_keys_artifact_name,
                genesis_constants.PRE_FUNDED_ACCOUNTS,
                genesis_validators_root,
                network_params.electra_fork_epoch,
            ),
            "launch_method": geth.launch,
        },
        package_io.EL_CLIENT_TYPE.besu: {
            "launcher": besu.new_besu_launcher(
                network_params.network_id, el_genesis_data
            ),
            "launch_method": besu.launch,
        },
        package_io.EL_CLIENT_TYPE.erigon: {
            "launcher": erigon.new_erigon_launcher(
                network_params.network_id, el_genesis_data
            ),
            "launch_method": erigon.launch,
        },
        package_io.EL_CLIENT_TYPE.nethermind: {
            "launcher": nethermind.new_nethermind_launcher(el_genesis_data),
            "launch_method": nethermind.launch,
        },
        package_io.EL_CLIENT_TYPE.reth: {
            "launcher": reth.new_reth_launcher(el_genesis_data),
            "launch_method": reth.launch,
        },
        package_io.EL_CLIENT_TYPE.ethereumjs: {
            "launcher": ethereumjs.new_ethereumjs_launcher(el_genesis_data),
            "launch_method": ethereumjs.launch,
        },
    }

    all_el_client_contexts = []

    for index, participant in enumerate(participants):
        cl_client_type = participant.cl_client_type
        el_client_type = participant.el_client_type

        if el_client_type not in el_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    el_client_type, ",".join([el.name for el in el_launchers.keys()])
                )
            )

        el_launcher, launch_method = (
            el_launchers[el_client_type]["launcher"],
            el_launchers[el_client_type]["launch_method"],
        )

        # Zero-pad the index using the calculated zfill value
        index_str = zfill_custom(index + 1, zfill_calculator(participants))

        el_service_name = "el-{0}-{1}-{2}".format(
            index_str, el_client_type, cl_client_type
        )

        el_client_context = launch_method(
            plan,
            el_launcher,
            el_service_name,
            participant.el_client_image,
            participant.el_client_log_level,
            global_log_level,
            all_el_client_contexts,
            participant.el_min_cpu,
            participant.el_max_cpu,
            participant.el_min_mem,
            participant.el_max_mem,
            participant.el_extra_params,
            participant.el_extra_env_vars,
        )

        all_el_client_contexts.append(el_client_context)

    plan.print("Succesfully added {0} EL participants".format(num_participants))

    plan.print("Launching CL network")

    cl_launchers = {
        package_io.CL_CLIENT_TYPE.lighthouse: {
            "launcher": lighthouse.new_lighthouse_launcher(cl_genesis_data),
            "launch_method": lighthouse.launch,
        },
        package_io.CL_CLIENT_TYPE.lodestar: {
            "launcher": lodestar.new_lodestar_launcher(cl_genesis_data),
            "launch_method": lodestar.launch,
        },
        package_io.CL_CLIENT_TYPE.nimbus: {
            "launcher": nimbus.new_nimbus_launcher(cl_genesis_data),
            "launch_method": nimbus.launch,
        },
        package_io.CL_CLIENT_TYPE.prysm: {
            "launcher": prysm.new_prysm_launcher(
                cl_genesis_data,
                cl_validator_data.prysm_password_relative_filepath,
                cl_validator_data.prysm_password_artifact_uuid,
            ),
            "launch_method": prysm.launch,
        },
        package_io.CL_CLIENT_TYPE.teku: {
            "launcher": teku.new_teku_launcher(cl_genesis_data),
            "launch_method": teku.launch,
        },
    }

    all_snooper_engine_contexts = []
    all_cl_client_contexts = []
    preregistered_validator_keys_for_nodes = cl_validator_data.per_node_keystores

    for index, participant in enumerate(participants):
        cl_client_type = participant.cl_client_type
        el_client_type = participant.el_client_type

        if cl_client_type not in cl_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    cl_client_type, ",".join([cl.name for cl in cl_launchers.keys()])
                )
            )

        cl_launcher, launch_method = (
            cl_launchers[cl_client_type]["launcher"],
            cl_launchers[cl_client_type]["launch_method"],
        )

        index_str = zfill_custom(index + 1, zfill_calculator(participants))

        cl_service_name = "cl-{0}-{1}-{2}".format(
            index_str, cl_client_type, el_client_type
        )
        new_cl_node_validator_keystores = None
        if participant.validator_count != 0:
            new_cl_node_validator_keystores = preregistered_validator_keys_for_nodes[
                index
            ]

        el_client_context = all_el_client_contexts[index]

        cl_client_context = None
        snooper_engine_context = None
        if participant.snooper_enabled:
            snooper_service_name = "snooper-{0}-{1}-{2}".format(
                index_str, cl_client_type, el_client_type
            )
            snooper_image = package_io.DEFAULT_SNOOPER_IMAGE
            snooper_engine_context = snooper.launch(
                plan,
                snooper_service_name,
                snooper_image,
                el_client_context,
            )
            plan.print(
                "Succesfully added {0} snooper participants".format(
                    snooper_engine_context
                )
            )

        all_snooper_engine_contexts.append(snooper_engine_context)

        if index == 0:
            cl_client_context = launch_method(
                plan,
                cl_launcher,
                cl_service_name,
                participant.cl_client_image,
                participant.cl_client_log_level,
                global_log_level,
                CL_CLIENT_CONTEXT_BOOTNODE,
                el_client_context,
                new_cl_node_validator_keystores,
                participant.bn_min_cpu,
                participant.bn_max_cpu,
                participant.bn_min_mem,
                participant.bn_max_mem,
                participant.v_min_cpu,
                participant.v_max_cpu,
                participant.v_min_mem,
                participant.v_max_mem,
                participant.snooper_enabled,
                snooper_engine_context,
                participant.beacon_extra_params,
                participant.validator_extra_params,
            )
        else:
            boot_cl_client_ctx = all_cl_client_contexts
            cl_client_context = launch_method(
                plan,
                cl_launcher,
                cl_service_name,
                participant.cl_client_image,
                participant.cl_client_log_level,
                global_log_level,
                boot_cl_client_ctx,
                el_client_context,
                new_cl_node_validator_keystores,
                participant.bn_min_cpu,
                participant.bn_max_cpu,
                participant.bn_min_mem,
                participant.bn_max_mem,
                participant.v_min_cpu,
                participant.v_max_cpu,
                participant.v_min_mem,
                participant.v_max_mem,
                participant.snooper_enabled,
                snooper_engine_context,
                participant.beacon_extra_params,
                participant.validator_extra_params,
            )

        all_cl_client_contexts.append(cl_client_context)

    plan.print("Succesfully added {0} CL participants".format(num_participants))

    all_participants = []

    for index, participant in enumerate(participants):
        el_client_type = participant.el_client_type
        cl_client_type = participant.cl_client_type

        el_client_context = all_el_client_contexts[index]
        cl_client_context = all_cl_client_contexts[index]
        if participant.snooper_enabled:
            snooper_engine_context = all_snooper_engine_contexts[index]

        participant_entry = participant_module.new_participant(
            el_client_type,
            cl_client_type,
            el_client_context,
            cl_client_context,
            snooper_engine_context,
        )

        all_participants.append(participant_entry)

    return all_participants, final_genesis_timestamp, genesis_validators_root


def zfill_calculator(participants):
    for zf, par in GLOBAL_INDEX_ZFILL["zfill_values"]:
        if len(participants) < par:
            zfill = zf - 1
            return zfill
            break


def zfill_custom(value, width):
    return ("0" * (width - len(str(value)))) + str(value)


# this is a python procedure so that Kurtosis can do idempotent runs
# time.now() runs everytime bringing non determinism
# note that the timestamp it returns is a string
def get_final_genesis_timestamp(plan, padding):
    result = plan.run_python(
        run="""
import time
import sys
padding = int(sys.argv[1])
print(int(time.time()+padding), end="")
""",
        args=[str(padding)],
    )
    return result.output
