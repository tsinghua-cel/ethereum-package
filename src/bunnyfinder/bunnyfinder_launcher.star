shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "bunnyfinder"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 19000
SWAG_PORT_ID = "http"
SWAG_PORT_NUMBER = 19001

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
    network_params,
    bunnyfinder_params,
    global_node_selectors,
):
    template_data = new_config_template_data(
        HTTP_PORT_NUMBER,
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
            BUNNYFINDER_TESTS_MOUNT_DIRPATH_ON_SERVICE: tests_config_artifacts_name,
            VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
        },
        cmd=["--config", config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_config_template_data(
    listen_port_num,
    bunnyfinder_params,
):
    strategy = bunnyfinder_params.strategy
    return {
        "ListenPortNum": listen_port_num,
        "Strategy": strategy,
    }
