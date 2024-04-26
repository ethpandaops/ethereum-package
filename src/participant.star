def new_participant(
    el_type,
    cl_type,
    vc_type,
    el_context,
    cl_context,
    vc_context,
    snooper_engine_context,
    snooper_beacon_context,
    ethereum_metrics_exporter_context,
    xatu_sentry_context,
):
    return struct(
        el_type=el_type,
        cl_type=cl_type,
        vc_type=vc_type,
        el_context=el_context,
        cl_context=cl_context,
        vc_context=vc_context,
        snooper_engine_context=snooper_engine_context,
        snooper_beacon_context=snooper_beacon_context,
        ethereum_metrics_exporter_context=ethereum_metrics_exporter_context,
        xatu_sentry_context=xatu_sentry_context,
    )
