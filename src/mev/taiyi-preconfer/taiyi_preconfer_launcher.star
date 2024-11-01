constants = import_module("../../package_io/constants.star")
shared_utils = import_module("../../shared_utils/shared_utils.star")
static_files = import_module("../../static_files/static_files.star")

DUMMY_SECRET_KEY = "0x607a11b45a7219cc61a3d9c5fd08c7eebd602a6a19a977f8d3771d5711a550f2"
DUMMY_PUB_KEY = "0xa55c1285d84ba83a5ad26420cd5ad3091e49c55a813eee651cd467db38a8c8e63192f47955e9376f6b42f6d190571cb5"

IMAGE = "lubann/taiyi:latest"

FOUNDRY_IMAGE = "ghcr.io/foundry-rs/foundry:latest"

TAIYI_CONTRACT_DEPLOY_SERVICE_NAME = "taiyi-contract-deploy"

HELIX_RELAY_ENDPOINT_PORT = 4040

# pk 0xadc0fe12e62c14a505ea1e655dbe4d36fa505ed57b634ba37912153d29edd45c5bc5a77764e68b98c53e3f6f8ce9fa3b
RELAY_KEY = "0x6b845831c99c6bf43364bee624447d39698465df5c07f2cc4dca6e0acfbe46cd"

HELIX_ENDPOINT_PORT = 9062
LAUNCH_ADMINER = True

# The min/max CPU/memory that mev-relay can use
RELAY_MIN_MEMORY = 128
RELAY_MAX_MEMORY = 1024



def launch_taiyi_preconfer(
    plan,
    config_template,
    genesis_timestamp,
    genesis_validators_root,
    cl_contexts,
    el_contexts,
    el_cl_data_files_artifact_uuid,
    persistent,
    global_node_selectors,
):
    deploy_taiyi_core_contract(plan, genesis_timestamp,el_contexts)
    # node_selectors = global_node_selectors

    # network_dir_path = "{}/config.yaml".format(constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS)

    # beacon_client_url = "http://{0}:{1}".format(
    #     cl_contexts[0].ip_addr, cl_contexts[0].http_port
    # )

    # simulator_url = "http://{0}:{1}".format(
    #     el_contexts[0].ip_addr, el_contexts[0].rpc_port_num
    # )
    # template_data = {
    #     "Hostname": "helix-postgres",
    #     "Port": postgres.port.number,
    #     "DbName": POSTGRES_DB,
    #     "User": POSTGRES_USER,
    #     "Password": POSTGRES_PASSWORD,
    #     "Region": 0,
    #     "RegionName": "",
    #     "RedisUrl": redis_url,
    #     "BeaconClientUrl": beacon_client_url,
    #     "SimulatorUrl": simulator_url,
    #     "NetworkDirPath": network_dir_path,
    #     "GenesisValidatorRoot": genesis_validators_root,
    #     "GenesisTime": genesis_timestamp,
    # }

    # template_and_data = shared_utils.new_template_and_data(
    #     config_template, template_data
    # )

    # template_and_data_by_rel_dest_filepath = {}
    # template_and_data_by_rel_dest_filepath[
    #     HELIX_CONFIG_FILENAME
    # ] = template_and_data

    # config_files_artifact_name = plan.render_templates(
    #     template_and_data_by_rel_dest_filepath, "helix-config.yml"
    # )

    # files = {
    #     "/app/config/": config_files_artifact_name,
    #     constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data_files_artifact_uuid,
    # }

    # env = {
    #     "RELAY_KEY": RELAY_KEY,
    # }
    # api = plan.add_service(
    #     name="helix-relay",
    #     config=ServiceConfig(
    #         image=IMAGE,
    #         files=files,
    #         cmd=[
    #             "--config",
    #             "/app/config/helix-config.yml",
    #         ],
    #         ports={
    #             "api": PortSpec(
    #                 number=HELIX_RELAY_ENDPOINT_PORT, transport_protocol="TCP"
    #             )
    #         },
    #         env_vars=env,
    #         min_memory=RELAY_MIN_MEMORY,
    #         max_memory=RELAY_MAX_MEMORY,
    #         node_selectors=node_selectors,
    #     ),
    # )

    return 


def deploy_taiyi_core_contract(plan, genesis_timestamp,el_contexts):
    deploy_script = plan.upload_files(src="./deploy.sh", name="taiyi-contract-deploy")
    rpc_url = "http://{0}:{1}".format(
        el_contexts[0].ip_addr, el_contexts[0].rpc_port_num
    )
    env = {
        "RPC_URL": rpc_url,
        # this is the last prefunded address
        "PRIVATE_KEY": "17fdf89989597e8bcac6cdfcc001b6241c64cece2c358ffc818b72ca70f5e1ce",
        "GENESIS_TIMESTAMP": genesis_timestamp
    }
    plan.add_service(
        name=TAIYI_CONTRACT_DEPLOY_SERVICE_NAME,
        config=ServiceConfig(
            image=FOUNDRY_IMAGE, 
            files={"/tmp": deploy_script}, 
            cmd=[ "-c", "touch /tmp/deploy.log && tail -f /tmp/deploy.log"], 
            env_vars=env
        )
    )

    plan.exec(
        service_name=TAIYI_CONTRACT_DEPLOY_SERVICE_NAME,
        description="Deploying taiyi core contract",
        recipe=ExecRecipe(["/bin/sh", "-c", "nohup /tmp/deploy.sh > /dev/null 2>&1 &"])
    )
