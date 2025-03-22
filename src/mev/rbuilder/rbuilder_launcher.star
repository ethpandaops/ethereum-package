input_parser = import_module("../../package_io/input_parser.star")
static_files = import_module("../../static_files/static_files.star")
shared_utils = import_module("../../shared_utils/shared_utils.star")
constants = import_module("../../package_io/constants.star")
reth = import_module("../../el/reth/reth_launcher.star")
el_cl_genesis_data = import_module(
    "../../prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)
lighthouse = import_module("../../cl/lighthouse/lighthouse_launcher.star")
# MEV Builder flags

EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/reth/execution-data"
RBUILDER_CONFIG_FILENAME = "rbuilder-config.toml"
RBUILDER_BLOCKLIST_FILENAME = "blocklist.json"

RBUILDER_MIN_MEMORY = 128
RBUILDER_MAX_MEMORY = 1024
def launch_rbuilder(
    plan,
    rbuilder_params,
    config_template,
    helix_relay_url,
    network_params,
    el_cl_data_files_artifact_uuid,
    genesis_validator_root,
    jwt_file,
    all_el_contexts,
    all_cl_contexts,
    node_selectors,
    port_publisher,
    global_tolerations,
):

    prague_time = plan.run_sh(
        name="read-rbuilder-prague-time",
        description="Reading prague time from genesis",
        run="jq .config.pragueTime /data/genesis.json | tr -d '\n'",
        image="badouralix/curl-jq",
        files={"/data": el_cl_data_files_artifact_uuid},
    )
    plan.print("Rbuilder Prague time: {0}".format(prague_time))
    service_name = "rbuilder-el-reth-lighthouse"
    particitpant_p = input_parser.default_participant()
    particitpant_p.update(
        {
        "el_type": "reth", 
        "el_image": rbuilder_params.rbuilder_image,
        "cl_image": "ethpandaops/lighthouse:stable",
        "use_separate_vc": False,
        "el_extra_params": [
            "--rbuilder.config=/app/config/rbuilder-config.toml", 
            "--engine.legacy",
        ],
        "el_extra_env_vars": {"RUST_LOG":"rbuilder=debug,reth=info"},
        "cl_extra_params": ["--always-prepare-payload", "--prepare-payload-lookahead=8000"]
        })
    participant = participant_struct(particitpant_p)
    

    plan.print("Starting rbuilder with helix relay url: {0}".format(helix_relay_url))
    template_data = {
        "Chain": "{}/{}".format(constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,"genesis.json"),
        "RethDatadir": EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "ClNodes": all_cl_contexts,
        "HelixRelayUrl": helix_relay_url,
    }
    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    blocklist = read_file(
        static_files.RBUILDER_BLOCKLIST_FILEPATH
    )
    blocklist_data = shared_utils.new_template_and_data(
        blocklist, {}
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        RBUILDER_CONFIG_FILENAME
    ] = template_and_data
    template_and_data_by_rel_dest_filepath[
        RBUILDER_BLOCKLIST_FILENAME
    ] =  blocklist_data


    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "rbuilder-config"
    )


    additional_files = {
        "/app/config/": config_files_artifact_name,
    }

    el_context = launch_rbuilder_reth(
        plan, 
        service_name,
        participant, 
        prague_time,
        network_params, 
        el_cl_data_files_artifact_uuid, 
        jwt_file, 
        additional_files,
        genesis_validator_root, 
        all_el_contexts,
        node_selectors, 
        port_publisher, 
        global_tolerations
    )
    cl_context = launch_rbuilder_lighthouse(
        plan, 
        participant, 
        prague_time,
        network_params, 
        el_cl_data_files_artifact_uuid, 
        jwt_file, 
        genesis_validator_root, 
        all_cl_contexts, 
        el_context, 
        node_selectors, 
        port_publisher, 
        global_tolerations
    )

    return 

def launch_rbuilder_lighthouse(
    plan,
    participant,
    prague_time,
    network_params,
    el_cl_data,
    jwt_file,
    genesis_validator_root,
    all_cl_contexts,
    el_context,
    node_selectors,
    port_publisher,
    global_tolerations,
):
    el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
        el_cl_data,
        genesis_validator_root,
        prague_time,
    )
    launcher = lighthouse.new_lighthouse_launcher(
        el_cl_data, jwt_file, network_params
    )

    global_log_level = "info"
    full_name = "rbuilder-lighthouse"
    node_keystore_files = None
    snooper_engine_context = None   
    persistent = False
    checkpoint_sync_enabled = False
    checkpoint_sync_url = ""
    index = 1
    cl_context = lighthouse.launch(
        plan,
        launcher,
        "rbuilder-lighthouse",
        participant,
        global_log_level,
        all_cl_contexts,
        el_context,
        full_name,
        node_keystore_files,
        snooper_engine_context,
        persistent,
        global_tolerations,
        node_selectors,
        checkpoint_sync_enabled,
        checkpoint_sync_url,
        port_publisher,
        index
    )
    return cl_context
    
def launch_rbuilder_reth(
    plan,
    service_name,
    participant,
    prague_time,
    network_params,
    el_cl_data,
    jwt_file,
    additional_files,
    genesis_validator_root,
    all_el_contexts,
    node_selectors,
    port_publisher,
    global_tolerations,
):
    index = 1
    el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
        el_cl_data,
        genesis_validator_root,
        prague_time,
    )
    launcher = reth.new_reth_launcher(
        el_cl_data,
        jwt_file,
        network_params.network,
    )
            
    el_context = reth.launch(
        plan,
        launcher,
        "rbuilder-el-reth-lighthouse",
        participant,
        "info",
        all_el_contexts,
        False,
        global_tolerations, #tolerations,
        node_selectors,
        port_publisher,
        index,
    )
    return el_context


def participant_struct(participant):
    return struct(
        el_type=participant["el_type"],
        el_image=participant["el_image"],
        el_log_level=participant["el_log_level"],
        el_volume_size=participant["el_volume_size"],
        el_extra_params=participant["el_extra_params"],
        el_extra_env_vars=participant["el_extra_env_vars"],
        el_extra_labels=participant["el_extra_labels"],
        el_tolerations=participant["el_tolerations"],
        cl_type=participant["cl_type"],
        cl_image=participant["cl_image"],
        cl_log_level=participant["cl_log_level"],
        cl_volume_size=participant["cl_volume_size"],
        cl_extra_env_vars=participant["cl_extra_env_vars"],
        cl_tolerations=participant["cl_tolerations"],
        use_separate_vc=participant["use_separate_vc"],
        vc_type=participant["vc_type"],
        vc_image=participant["vc_image"],
        vc_log_level=participant["vc_log_level"],
        vc_count=participant["vc_count"],
        vc_tolerations=participant["vc_tolerations"],
        cl_extra_params=participant["cl_extra_params"],
        cl_extra_labels=participant["cl_extra_labels"],
        vc_extra_params=participant["vc_extra_params"],
        vc_extra_env_vars=participant["vc_extra_env_vars"],
        vc_extra_labels=participant["vc_extra_labels"],
        use_remote_signer=participant["use_remote_signer"],
        remote_signer_type=participant["remote_signer_type"],
        remote_signer_image=participant["remote_signer_image"],
        remote_signer_tolerations=participant["remote_signer_tolerations"],
        remote_signer_extra_env_vars=participant[
            "remote_signer_extra_env_vars"
        ],
        remote_signer_extra_params=participant["remote_signer_extra_params"],
        remote_signer_extra_labels=participant["remote_signer_extra_labels"],
        builder_network_params=participant["builder_network_params"],
        supernode=participant["supernode"],
        el_min_cpu=participant["el_min_cpu"],
        el_max_cpu=participant["el_max_cpu"],
        el_min_mem=participant["el_min_mem"],
        el_max_mem=participant["el_max_mem"],
        cl_min_cpu=participant["cl_min_cpu"],
        cl_max_cpu=participant["cl_max_cpu"],
        cl_min_mem=participant["cl_min_mem"],
        cl_max_mem=participant["cl_max_mem"],
        vc_min_cpu=participant["vc_min_cpu"],
        vc_max_cpu=participant["vc_max_cpu"],
        vc_min_mem=participant["vc_min_mem"],
        vc_max_mem=participant["vc_max_mem"],
        remote_signer_min_cpu=participant["remote_signer_min_cpu"],
        remote_signer_max_cpu=participant["remote_signer_max_cpu"],
        remote_signer_min_mem=participant["remote_signer_min_mem"],
        remote_signer_max_mem=participant["remote_signer_max_mem"],
        validator_count=participant["validator_count"],
        tolerations=participant["tolerations"],
        node_selectors=participant["node_selectors"],
        snooper_enabled=participant["snooper_enabled"],
        count=participant["count"],
        ethereum_metrics_exporter_enabled=participant[
            "ethereum_metrics_exporter_enabled"
        ],
        xatu_sentry_enabled=participant["xatu_sentry_enabled"],
        prometheus_config=struct(
            scrape_interval=participant["prometheus_config"]["scrape_interval"],
            labels=participant["prometheus_config"]["labels"],
        ),
        blobber_enabled=participant["blobber_enabled"],
        blobber_extra_params=participant["blobber_extra_params"],
        keymanager_enabled=participant["keymanager_enabled"],
    )
