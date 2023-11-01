# this is a dictionary as this will get serialzed to JSON
def new_node_metrics_info(
    name,
    path,
    url,
    additional_labels={},
):
    return {
        "name": name,
        "path": path,
        "url": url,
        "additional_labels": dict(additional_labels),
    }
