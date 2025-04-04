shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "bunnyfinder"


RPC_PORT_ID = "rpc"
RPC_PORT_NUMBER = 19000

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 19100


BUNNYFINDER_CONFIG_FILENAME = "bunnyfinder-config.yaml"

BUNNYFINDER_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"
BUNNYFINDER_TESTS_MOUNT_DIRPATH_ON_SERVICE = "/tests"

# The min/max CPU/memory that bunnyfinder can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 2048

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    RPC_PORT_ID: shared_utils.new_port_spec(
        RPC_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

def launch_bunnyfinder(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    network_params,
    bunnyfinder_params,
    global_node_selectors,
):
    # check bunnyfinder_params.dbconnect is set an valid value
    if bunnyfinder_params.dbconnect == "":
        fail(
            "dbconnect is required in bunnyfinder_params"
        )
    honest_cl_http_url = ""
    if len(participant_contexts) >= 2:
        participant = participant_contexts[1]
        _, cl_client, _, _ = shared_utils.get_client_names(
            participant, 0, participant_contexts, participant_configs
        )
	honest_cl_http_url = cl_client.beacon_http_url

    participant = participant_contexts[0]
    (
        full_name,
        cl_client,
        el_client,
        participant_config,
    ) = shared_utils.get_client_names(
        participant, 0, participant_contexts, participant_configs
    )
    el_http_url = "http://{0}:{1}".format(
        el_client.ip_addr,
        el_client.rpc_port_num,
    )

    if honest_cl_http_url == "":
        honest_cl_http_url = cl_client.beacon_http_url

    plan.print(
        "Launching bunnyfinder with CL HTTP URL: {0}, Honest CL HTTP URL: {1}, EL HTTP URL: {2}".format(
            cl_client.beacon_http_url, honest_cl_http_url, el_http_url
        )
    )

    template_data = new_config_template_data(
        RPC_PORT_NUMBER,
        HTTP_PORT_NUMBER,
        cl_client.beacon_http_url,
        honest_cl_http_url,
        el_http_url,
        bunnyfinder_params,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        BUNNYFINDER_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "bunnyfinder-config"
    )

    config = get_config(
        config_files_artifact_name,
        network_params,
        bunnyfinder_params,
        global_node_selectors,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    network_params,
    bunnyfinder_params,
    node_selectors,
):
    config_file_path = shared_utils.path_join(
        BUNNYFINDER_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        BUNNYFINDER_CONFIG_FILENAME,
    )

    IMAGE_NAME = bunnyfinder_params.image

    cmd=["--config", config_file_path,
         "--strategy", bunnyfinder_params.strategy,
         "--duration-per-strategy-run", bunnyfinder_params.duration_per_strategy,
         "--max-hack-idx", bunnyfinder_params.max_malicious_idx,
         "--min-hack-idx", bunnyfinder_params.min_malicious_idx]
    # check bunnyfinder_params.replay_project is set an value, if so, add it to the cmd
    if bunnyfinder_params.replay_project != "":
        cmd.append("--replay")
        cmd.append(bunnyfinder_params.replay_project)

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        files={
            BUNNYFINDER_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        env_vars={"OPENAI_API_KEY": bunnyfinder_params.openai_key, "OPENAI_BASE_URL": bunnyfinder_params.openai_base_url, "LLM_MODEL": bunnyfinder_params.llm_model},
        cmd = cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_config_template_data(
    listen_rpc_port_num,
    listen_port_num,
    beacon_http_url,
    honest_beacon_http_url,
    execution_http_url,
    bunnyfinder_params,
):
    return {
        "DBConnect": bunnyfinder_params.dbconnect,
        "ListenRPCPortNum": listen_rpc_port_num,
        "ListenPortNum": listen_port_num,
        "CL_HTTP_URL": beacon_http_url,
        "HONEST_CL_HTTP_URL": honest_beacon_http_url,
        "EL_HTTP_URL": execution_http_url,
    }

