def new_mev_boost_context(pubkey, private_ip_address, port):
    return struct(
        pubkey=pubkey,
        private_ip_address=private_ip_address,
        port=port,
        url="http://{}@{}:{}".format(pubkey, private_ip_address, port)
    )


def mev_boost_endpoint(mev_boost_context):
    return "http://{0}:{1}".format(
        mev_boost_context.private_ip_address, mev_boost_context.port
    )
