def new_participant(
    el_client_type,
    cl_client_type,
    validator_client_type,
    el_client_context,
    cl_client_context,
    validator_client_context,
    snooper_engine_context,
    ethereum_metrics_exporter_context,
    xatu_sentry_context,
):
    return struct(
        el_client_type=el_client_type,
        cl_client_type=cl_client_type,
        validator_client_type=validator_client_type,
        el_client_context=el_client_context,
        cl_client_context=cl_client_context,
        validator_client_context=validator_client_context,
        snooper_engine_context=snooper_engine_context,
        ethereum_metrics_exporter_context=ethereum_metrics_exporter_context,
        xatu_sentry_context=xatu_sentry_context,
    )
