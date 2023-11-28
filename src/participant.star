def new_participant(
    el_client_type,
    cl_client_type,
    el_client_context,
    cl_client_context,
    snooper_engine_context,
    ethereum_metrics_exporter_context,
    cl_disabled,
):
    return struct(
        el_client_type=el_client_type,
        cl_client_type=cl_client_type,
        el_client_context=el_client_context,
        cl_client_context=cl_client_context,
        snooper_engine_context=snooper_engine_context,
        ethereum_metrics_exporter_context=ethereum_metrics_exporter_context,
        cl_disabled=cl_disabled,
    )
    