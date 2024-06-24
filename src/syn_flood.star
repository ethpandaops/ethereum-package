SERVICE_NAME = "syn-flood"

# The min/max CPU/memory that syn_flood can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 20
MAX_MEMORY = 1000

ENTRYPOINT_ARGS = [
    "sleep",
    "99999",
]


# def launch_syn_flood(
#     plan,
#     vitcim_ip,
#     syn_flood_extra_args,
#     node_selectors,
# ):
#     config = get_config(
#         vitcim_ip,
#         syn_flood_extra_args,
#         node_selectors,
#     )

#     plan.add_service(SERVICE_NAME, config)

# def get_config(
#     vitcim_ip,
#     syn_flood_extra_args,
#     node_selectors,
# ):
#     syn_flood_image = "utkudarilmaz/hping3:latest"

#     cmd = [
#         "hping3",
#         vitcim_ip,
#     ]

#     if len(syn_flood_extra_args) > 0:
#         cmd.extend([param for param in syn_flood_extra_args])

#     return ServiceConfig(
#         image=syn_flood_image,
#         cmd=cmd,
#         min_cpu=MIN_CPU,
#         max_cpu=MAX_CPU,
#         min_memory=MIN_MEMORY,
#         max_memory=MAX_MEMORY,
#         node_selectors=node_selectors,
#     )

def add_syn_flood(
    plan,
    node_selectors,
):
    syn_flood_image = "mik9/hping3:arm64"

    plan.add_service(
        SERVICE_NAME,
        ServiceConfig(
            image=syn_flood_image,
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=node_selectors,
            entrypoint=ENTRYPOINT_ARGS,
        ),
    )

    # run the command
    command_result = plan.exec(
        service_name=SERVICE_NAME,
        description="Show hping3 version",
        recipe=ExecRecipe(command=["hping3", "--version"]),
    )

    return command_result
