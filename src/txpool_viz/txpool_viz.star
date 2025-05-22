
def launch_txpoolviz(
    plan,
    network_participants,
):
    rpc_list = []
    for index, participant in enumerate(network_participants):
        plan.print(participant)
