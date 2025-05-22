
def launch_txpoolviz(
    plan,
    network_participants,
):
    rpc_list = []
    for index, participant in enumerate(network_participants):
        plan.print("\n Participant %d" % index)
        plan.print(participant.el_context)
        plan.print(participant.cl_context)
