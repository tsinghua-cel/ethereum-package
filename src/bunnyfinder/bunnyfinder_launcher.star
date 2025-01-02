shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "bunnyfinder"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 19000

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
    if bunnyfinder_params.dbconnect is None or bunnyfinder_params.dbconnect == "":
        fail(
            "dbconnect is required in bunnyfinder_params"
        )

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
    template_data = new_config_template_data(
        HTTP_PORT_NUMBER,
        cl_client.beacon_http_url,
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

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        files={
            BUNNYFINDER_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=["--config", config_file_path,
             "--strategy", bunnyfinder_params.strategy,
             "--duration-per-strategy-run", bunnyfinder_params.duration_per_strategy,
             "--max-hack-idx", bunnyfinder_params.max_malicious_idx,
             "--min-hack-idx", bunnyfinder_params.min_malicious_idx,],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_config_template_data(
    listen_port_num,
    beacon_http_url,
    execution_http_url,
    bunnyfinder_params,
):
    return {
        "DBConnect": bunnyfinder_params.dbconnect,
        "ListenPortNum": listen_port_num,
        "CL_HTTP_URL": beacon_http_url,
        "EL_HTTP_URL": execution_http_url,
    }
