# this is a dictionary as this will get serialized to JSON
def new_node_metrics_info(
    name,
    path,
    url,
    config=None,
):
    return {
        "name": name,
        "path": path,
        "url": url,
        "config": config,
    }
