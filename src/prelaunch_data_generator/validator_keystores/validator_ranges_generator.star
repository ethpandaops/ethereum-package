VALIDATOR_RANGES_FILE_NAME = "validator-ranges.yaml"
shared_utils = import_module("../../shared_utils/shared_utils.star")


def generate_validator_ranges(
    plan,
    config_template,
    el_contexts,
    cl_contexts,
    vc_contexts,
    participants,
):
    data = []
    running_total_validator_count = 0
    for index, client in enumerate(cl_contexts):
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(cl_contexts))))
        full_name = (
            index_str
            + "-"
            + el_contexts[index].client_name
            + "-"
            + cl_contexts[index].client_name
            + "-"
            + vc_contexts[index].client_name
        )
        participant = participants[index]
        if participant.validator_count == 0:
            continue
        start_index = running_total_validator_count
        running_total_validator_count += participant.validator_count
        end_index = start_index + participant.validator_count - 1
        data.append(
            {
                "ClientName": full_name,
                "Range": "{0}-{1}".format(start_index, end_index),
            }
        )

    template_data = {"Data": data}

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        VALIDATOR_RANGES_FILE_NAME
    ] = shared_utils.new_template_and_data(config_template, template_data)

    VALIDATOR_RANGES_ARTIFACT_NAME = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "validator-ranges"
    )
