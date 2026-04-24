shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME_PREFIX = "zkboost"

HTTP_PORT_NUMBER = 3000

ZKBOOST_CONFIG_FILENAME = "config.toml"

ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 256
MAX_MEMORY = 2048

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

ERE_SERVER_HTTP_PORT_ID = "http"
ERE_SERVER_PORT = 3000
ERE_SERVER_READY_TIMEOUT = "600s"
ERE_SERVER_READY_INTERVAL = "10s"

# Templates for auto-resolving ere-server image and ere-guests ELF URL from the
# Cargo.toml in zkboost repo, that pins ere and ere-guests version.
ZKBOOST_CARGO_TOML_FILEPATH = "github.com/eth-act/zkboost/Cargo.toml@{ref}"
ERE_SERVER_IMAGE_TEMPLATE = (
    "ghcr.io/eth-act/ere/ere-server-{zkvm_kind}:{version}{suffix}"
)
ERE_GUESTS_ELF_URL_TEMPLATE = "https://github.com/eth-act/ere-guests/releases/download/v{version}/stateless-validator-{proof_type}.elf"
ERE_DEP_NAME = "ere-server-client"
ERE_GUESTS_DEP_NAME = "ere-guests-stateless-validator-common"

# Default env applied to every `kind: ere` entry.
ERE_SERVER_DEFAULT_ENV = {"RUST_LOG": "info"}

# ZisK-specific Ere server defaults.
ZISK_DEFAULT_SHM_SIZE_MIB = 32768
ZISK_DEFAULT_ULIMITS = {"memlock": -1}
ZISK_DEFAULT_ENV = {
    "RUST_LOG": "info,asm_runner=warn,executor=warn,mem_planner_cpp=warn,proofman=warn,rom_setup=warn,sm_rom=warn,zisk=warn",
    "ERE_ZISK_SETUP_ON_INIT": "1",
}


def launch_zkboost(
    plan,
    config_template,
    participant_contexts,
    zkboost_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    tempo_otlp_grpc_url=None,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Launch ere-server services once - shared across all zkboost instances.
    # Each `ere` zkvm entry results in a single long-lived service; all zkboost
    # instances reference it as an endpoint.
    # `_resolve_image_and_elf_url` fills in `image` and `elf_url` from zkboost's
    # pinned ere/ere-guests versions when the user didn't provide them.
    ere_server_endpoints = {}
    metrics_jobs = []
    for zkvm in _resolve_image_and_elf_url(zkboost_params.zkvms, zkboost_params.image):
        if zkvm["kind"] != "ere":
            continue

        proof_type = zkvm["proof_type"]
        if proof_type in ere_server_endpoints:
            continue

        endpoint = _launch_ere_server(
            plan, zkvm, global_node_selectors, tolerations, tempo_otlp_grpc_url
        )
        ere_server_endpoints[proof_type] = endpoint
        metrics_jobs.append(_get_ere_server_metrics_job(proof_type))

    for instance_index, instance in enumerate(zkboost_params.instances):
        name = instance["name"]
        el_participant_index = instance["el_participant_index"]

        if el_participant_index >= len(participant_contexts):
            fail(
                "zkboost instance '{0}' references el_participant_index {1} but only {2} participants exist".format(
                    name, el_participant_index, len(participant_contexts)
                )
            )

        el_client = participant_contexts[el_participant_index].el_context
        el_endpoint = "http://{0}:{1}".format(
            el_client.dns_name, el_client.rpc_port_num
        )

        zkvms = []
        for zkvm in zkboost_params.zkvms:
            entry = {
                "Kind": zkvm["kind"],
                "ProofType": zkvm["proof_type"],
                "ProofTimeoutSecs": zkvm.get("proof_timeout_secs", 12),
            }
            if zkvm["kind"] == "ere":
                entry["Endpoint"] = ere_server_endpoints[zkvm["proof_type"]]
            elif zkvm["kind"] == "external":
                entry[
                    "Kind"
                ] = "ere"  # zkboost config kind for any external prover connection
                entry["Endpoint"] = zkvm["endpoint"]
            elif zkvm["kind"] == "mock":
                mock_proving_time = zkvm.get(
                    "mock_proving_time", {"kind": "constant", "ms": 6000}
                )
                entry["MockProvingTimeKind"] = mock_proving_time.get("kind", "constant")
                entry["MockProvingTimeConstantMs"] = mock_proving_time.get("ms", 0)
                entry["MockProvingTimeRandomMinMs"] = mock_proving_time.get("min_ms", 0)
                entry["MockProvingTimeRandomMaxMs"] = mock_proving_time.get("max_ms", 0)
                entry["MockProvingTimeLinearMsPerMgas"] = mock_proving_time.get(
                    "ms_per_mgas", 0
                )
                entry["MockProofSize"] = zkvm.get("mock_proof_size", 128 << 10)
                entry["MockFailure"] = zkvm.get("mock_failure", False)
            zkvms.append(entry)

        template_data = {
            "Port": HTTP_PORT_NUMBER,
            "ELEndpoint": el_endpoint,
            "WitnessTimeoutSecs": 12,
            "WitnessCacheSize": 128,
            "ProofCacheSize": 128,
            "DashboardEnabled": zkboost_params.dashboard_enabled,
            "DashboardRetention": 256,
            "Zkvms": zkvms,
        }

        template_and_data = shared_utils.new_template_and_data(
            config_template, template_data
        )
        template_and_data_by_rel_dest_filepath = {}
        template_and_data_by_rel_dest_filepath[
            ZKBOOST_CONFIG_FILENAME
        ] = template_and_data

        config_files_artifact_name = plan.render_templates(
            template_and_data_by_rel_dest_filepath, name + "-config"
        )
        config = get_config(
            name,
            config_files_artifact_name,
            zkboost_params,
            global_node_selectors,
            tolerations,
            port_publisher,
            additional_service_index + instance_index,
            docker_cache_params,
            tempo_otlp_grpc_url,
        )

        plan.add_service(name, config)
        metrics_jobs.append(get_metrics_job(name))

    return metrics_jobs


def get_metrics_job(service_name):
    return {
        "Name": service_name,
        "Endpoint": "{0}:{1}".format(service_name, HTTP_PORT_NUMBER),
        "MetricsPath": "/metrics",
        "Labels": {
            "service": service_name,
            "client_type": SERVICE_NAME_PREFIX,
        },
        "ScrapeInterval": "15s",
    }


def get_config(
    service_name,
    config_files_artifact_name,
    zkboost_params,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    tempo_otlp_grpc_url,
):
    config_file_path = shared_utils.path_join(
        ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        ZKBOOST_CONFIG_FILENAME,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    env_vars = dict(zkboost_params.env)
    if tempo_otlp_grpc_url != None:
        env_vars["OTEL_EXPORTER_OTLP_ENDPOINT"] = tempo_otlp_grpc_url
        env_vars["OTEL_SERVICE_NAME"] = service_name

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            zkboost_params.image,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        entrypoint=["/usr/local/bin/zkboost"],
        cmd=["--config", config_file_path],
        env_vars=env_vars,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
        ready_conditions=ReadyCondition(
            recipe=GetHttpRequestRecipe(
                port_id=constants.HTTP_PORT_ID,
                endpoint="/health",
            ),
            field="code",
            assertion="==",
            target_value=200,
        ),
    )


def _launch_ere_server(
    plan, zkvm, global_node_selectors, tolerations, tempo_otlp_grpc_url
):
    """Launch an ere-server prover service and return its HTTP endpoint."""
    proof_type = zkvm["proof_type"]
    service_name = "ere-server-{0}".format(proof_type)
    zkvm_kind = _zkvm_kind_from_proof_type(proof_type)

    gpu = dict(zkvm.get("gpu", {}))
    has_gpu = _zkvm_has_gpu(zkvm)
    if zkvm_kind == "zisk":
        if "shm_size" not in gpu:
            gpu["shm_size"] = ZISK_DEFAULT_SHM_SIZE_MIB
        if "ulimits" not in gpu:
            gpu["ulimits"] = dict(ZISK_DEFAULT_ULIMITS)

    used_ports = {
        ERE_SERVER_HTTP_PORT_ID: shared_utils.new_port_spec(
            ERE_SERVER_PORT,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
            wait=None,
        )
    }

    env_vars = dict(ERE_SERVER_DEFAULT_ENV)
    if zkvm_kind == "zisk":
        for key, value in ZISK_DEFAULT_ENV.items():
            env_vars[key] = value
    for key, value in zkvm.get("env", {}).items():
        env_vars[key] = value
    if tempo_otlp_grpc_url != None:
        env_vars["OTEL_EXPORTER_OTLP_ENDPOINT"] = tempo_otlp_grpc_url
        env_vars["OTEL_SERVICE_NAME"] = service_name

    plan.add_service(
        name=service_name,
        config=ServiceConfig(
            image=zkvm["image"],
            ports=used_ports,
            cmd=[
                "--port",
                "{0}".format(ERE_SERVER_PORT),
                "--elf-url",
                zkvm["elf_url"],
                "gpu" if has_gpu else "cpu",
            ],
            env_vars=env_vars,
            gpu=GpuConfig(
                count=gpu.get("count", 0),
                device_ids=gpu.get("device_ids", []),
                shm_size=gpu.get("shm_size", 0),
                ulimits=gpu.get("ulimits", {}),
                driver=gpu.get("driver", "nvidia"),
            ),
            node_selectors=global_node_selectors,
            tolerations=tolerations,
            ready_conditions=ReadyCondition(
                recipe=GetHttpRequestRecipe(
                    port_id=ERE_SERVER_HTTP_PORT_ID,
                    endpoint="/health",
                ),
                field="code",
                assertion="==",
                target_value=200,
                timeout=ERE_SERVER_READY_TIMEOUT,
                interval=ERE_SERVER_READY_INTERVAL,
            ),
        ),
    )

    return "http://{0}:{1}".format(service_name, ERE_SERVER_PORT)


def _zkvm_has_gpu(zkvm):
    gpu = zkvm.get("gpu", {})
    return len(gpu.get("device_ids", [])) > 0 or gpu.get("count", 0) > 0


def _zkvm_kind_from_proof_type(proof_type):
    """Derive the zkVM backend (e.g. `zisk`, `openvm`) from `proof_type` (e.g.
    `ethrex-zisk`, `reth-openvm`).
    """
    return proof_type.split("-")[-1]


def _resolve_image_and_elf_url(zkvms, zkboost_image):
    """Return a new zkvms list where every `kind: ere` entry is guaranteed to
    have `image` and `elf_url` set. Missing fields are resolved from zkboost's
    Cargo.toml pinned ere/ere-guests versions.

    Fails when an auto-resolve is required but the corresponding dep isn't
    tag-pinned in zkboost (uses branch or rev), in which case the user must set
    the field explicitly.
    """
    if not any(
        [
            zkvm["kind"] == "ere" and ("image" not in zkvm or "elf_url" not in zkvm)
            for zkvm in zkvms
        ]
    ):
        return zkvms

    ere_version, ere_guests_version = _resolve_ere_versions(zkboost_image)

    resolved = []
    for zkvm in zkvms:
        if zkvm["kind"] != "ere":
            resolved.append(zkvm)
            continue
        zkvm = dict(zkvm)
        proof_type = zkvm["proof_type"]
        zkvm_kind = _zkvm_kind_from_proof_type(proof_type)

        if "image" not in zkvm:
            zkvm["image"] = ERE_SERVER_IMAGE_TEMPLATE.format(
                zkvm_kind=zkvm_kind,
                version=ere_version,
                suffix="-cuda" if _zkvm_has_gpu(zkvm) else "",
            )
        if "elf_url" not in zkvm:
            zkvm["elf_url"] = ERE_GUESTS_ELF_URL_TEMPLATE.format(
                version=ere_guests_version,
                proof_type=proof_type,
            )
        resolved.append(zkvm)
    return resolved


def _resolve_ere_versions(zkboost_image):
    """Resolve ere and ere-guests versions from zkboost's Cargo.toml at the git
    ref matching the zkboost image tag.

    Auto-resolution is supported for the zkboost image:
      - `ghcr.io/eth-act/zkboost/zkboost` and
        `ghcr.io/eth-act/zkboost/zkboost:latest` -> `Cargo.toml@vX.Y.Z`
          where `X.Y.Z` is resolved from `workspace.package.version` of
          `Cargo.toml@master`.
      - `ghcr.io/eth-act/zkboost/zkboost:X.Y.Z` -> `Cargo.toml@vX.Y.Z`
      - `ghcr.io/eth-act/zkboost/zkboost:<sha:7>` -> `Cargo.toml@<sha:7>`
          where `<sha:7>` is the 7 characters lowercase hex git commit SHA.

    Any other image (different registry, fork, pre-release tag, etc.) cannot
    be guaranteed to match a specific Cargo.toml revision, so the user must
    set `image` and `elf_url` explicitly on each ere zkvm entry.
    """
    image_base = constants.DEFAULT_ZKBOOST_IMAGE.split(":")[0]
    if zkboost_image == image_base:
        image_tag = "latest"
    elif zkboost_image.startswith(image_base + ":"):
        image_tag = zkboost_image[len(image_base) + 1 :]
    else:
        _fail_resolve_ere_versions(
            "zkboost_params.image '{image}' is not the official zkboost image. Auto-resolution is only supported for `{official}` with no tag, `:latest`, `:X.Y.Z`, or `:<sha:7>`".format(
                image=zkboost_image,
                official=image_base,
            )
        )

    if image_tag == "latest":
        cargo_toml = read_file(ZKBOOST_CARGO_TOML_FILEPATH.format(ref="master"))
        version = _parse_cargo_workspace_version(cargo_toml)
        if version == None:
            _fail_resolve_ere_versions(
                "cannot locate `workspace.package.version` in zkboost's master Cargo.toml to resolve `:latest`",
            )
        ref = "v" + version
    elif _is_semver(image_tag):
        ref = "v" + image_tag
    elif _is_git_sha(image_tag):
        ref = image_tag
    else:
        _fail_resolve_ere_versions(
            "zkboost_params.image tag '{image_tag}' is not `latest`, `X.Y.Z`, or a git commit SHA (7 lowercase hex chars)".format(
                image_tag=image_tag,
            ),
        )

    cargo_toml = read_file(ZKBOOST_CARGO_TOML_FILEPATH.format(ref=ref))
    ere_version = _parse_cargo_dependency_version(cargo_toml, ERE_DEP_NAME)
    if ere_version == None:
        _fail_resolve_ere_versions(
            "`{dep}` is not tag-pinned in zkboost's Cargo.toml@{ref}".format(
                dep=ERE_DEP_NAME,
                ref=ref,
            ),
        )
    ere_guests_version = _parse_cargo_dependency_version(
        cargo_toml, ERE_GUESTS_DEP_NAME
    )
    if ere_guests_version == None:
        _fail_resolve_ere_versions(
            "`{dep}` is not tag-pinned in zkboost's Cargo.toml@{ref}".format(
                dep=ERE_GUESTS_DEP_NAME,
                ref=ref,
            ),
        )
    return ere_version, ere_guests_version


def _fail_resolve_ere_versions(reason):
    fail(
        reason
        + ". Set `image` and `elf_url` explicitly on each `kind: ere` zkvm entry to skip auto-resolution."
    )


def _is_semver(image_tag):
    digits = image_tag.split(".")
    return len(digits) == 3 and all([digit.isdigit() for digit in digits])


def _is_git_sha(image_tag):
    return len(image_tag) >= 7 and all(
        [char in "0123456789abcdef" for char in image_tag.elems()]
    )


def _parse_cargo_workspace_version(cargo_toml):
    """Return the value of `version` under the `[workspace.package]` table, or
    `None` if not found. Stops at the next `[section]` header so it won't leak
    into other tables.
    """
    tokens = [token.strip(",").strip('"') for token in cargo_toml.split()]
    for i in range(len(tokens)):
        if tokens[i] != "[workspace.package]":
            continue
        for j in range(i + 1, len(tokens) - 2):
            if tokens[j].startswith("[") and tokens[j].endswith("]"):
                return None
            if tokens[j] == "version" and tokens[j + 1] == "=":
                return tokens[j + 2]
        return None
    return None


def _parse_cargo_dependency_version(cargo_toml, dependency):
    """Return the version pinned by `<dependency> = { ..., tag = "vX.Y.Z", ... }`
    in cargo_toml, with the leading `v` stripped.
    """
    tokens = [token.strip(",").strip('"') for token in cargo_toml.split()]
    for i in range(len(tokens) - 2):
        if tokens[i] != dependency or tokens[i + 1] != "=" or tokens[i + 2] != "{":
            continue
        depth = 1
        for j in range(i + 3, len(tokens)):
            if tokens[j] == "{":
                depth += 1
            elif tokens[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            elif (
                depth == 1
                and tokens[j] == "tag"
                and j + 2 < len(tokens)
                and tokens[j + 1] == "="
                and tokens[j + 2].startswith("v")
            ):
                return tokens[j + 2][1:]
        return None
    return None


def _get_ere_server_metrics_job(proof_type):
    service_name = "ere-server-{0}".format(proof_type)
    return {
        "Name": service_name,
        "Endpoint": "{0}:{1}".format(service_name, ERE_SERVER_PORT),
        "MetricsPath": "/metrics",
        "Labels": {
            "service": service_name,
            "client_type": "ere-server",
            "proof_type": proof_type,
        },
        "ScrapeInterval": "15s",
    }
