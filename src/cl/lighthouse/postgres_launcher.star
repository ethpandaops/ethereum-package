core = import_module("@kurtosis:core.star")
ServiceConfig = core.ServiceConfig

def launch_postgres(plan):
    plan.print("🚀 Launching Postgres service for Lighthouse...")

    postgres_service = plan.add_service(
        name="postgres",
        config=ServiceConfig(
            image="postgres:16",
            ports={"postgres": 5432},
            env_vars={
                "POSTGRES_USER": "postgres",
                "POSTGRES_PASSWORD": "admin",
                "POSTGRES_DB": "store",
            },
            cmd=["postgres", "-c", "fsync=off", "-c", "full_page_writes=off"],
        ),
    )
    plan.print("✅ Postgres ready on port 5432")
    return postgres_service