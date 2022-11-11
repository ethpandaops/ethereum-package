ETH2-MERGE-STARTOSIS-MODULE
===========================

This is the Startosis version of the popular [eth2-merge-kurtosis-module](https://github.com/kurtosis-tech/eth2-merge-kurtosis-module/)


### Parity Missing Tasks

- [x] main.star
  - [x] launch forkmon, prometheus, grafana, testnet_verifier, transaction_spammer
  - [x] do a wait for epoch finalization
  - [ ] assert that finalization epoch > 0
- [x] Module IO (this is blocked on Startosis Args working)
- [x] forkmon (this is blocked on CL clients running)
- [x] prometheus (this is blocked on CL clients running)
- [x] grafana (this is blocked on prometheus running)
- [x] grafana needs an upload files endpoint in Startosis
- [x] static_files package
- [x] testnet_verifier (this is blocked on CL/EL clients running)
- [x] transaction_spammer (this is blocked on EL clients running)
- [x] participant_network/participant_network DEMO
  - [x] has most data generation things, needs to start EL/CL clients
  - [x] needs upload files to be implemented
  - [x] need to fill in the dictionary with all el / cl types
- [x] participant_network/participant
  - [x] pure POJO should be quick to implement NO BLOCKERS
- [x] mev_boost participant_network/mev_boost NO BLOCKERS - removed some attributes that aren't used
  - [x] mev_boost_context pure POJO NO BLOCKERS
  - [x] mev_boost_launcher NO BLOCKERS
- [x] participant_network/pre_launch_data_generator (the only missing piece here is remove_service)
  - [x] data generation
  - [x] remove services post generation
- [x] participant_network/el (requires facts and waits)
  - [x] besu
    - [x] facts and waits + private_ip_address_placeholder
    - [x] framework
    - [x] facts could use more waiting
  - [x] erigon
    - [x] facts and waits + private_ip_address_placeholder
    - [x] framework
  - [x] geth DEMO
    - [x] facts and waits + private_ip_address_placeholder
    - [x] framework TESTED
  - [x] nethermind
    - [x] facts and waits + private_ip_address_placeholder
    - [x] framework
    - [x] facts could use more waiting
  - [x] el_client_context pure POJO NO BLOCKERS
  - [x] el_client_launcher interface not necessary
  - [x] el_availability_waiter - facts and waits - DESCOPED facts and waits will do this
  - [x] el_rest_client/api_response_objects.go DESCOPED as facts will do this
  - [x] el_rest_client/el_rest_client - facts and waits  DESCOPED as facts will do this
- [x] participant_network/cl (requires facts and waits)
  - [x] lighthouse DEMO
    - [x] facts and waits
    - [x] framework TESTED
  - [x] lodestar
    - [x] facts and waits
    - [x] framework
    - [x] needs longer fact & wait
  - [x] nimbus - eth2-merge-kurtosis-module is broken and so is this
    - [x] facts and waits
    - [x] framework
  - [x] prysm
    - [x] facts and waits
    - [x] framework
  - [x] teku
    - [x] facts and waits
    - [x] framework
    - [x] needs longer facts and waits
  - [x] cl_client_context pure POJO NO BLOCKERS
  - [x] cl_client_launcher interface not necessary
  - [x] cl_availability_waiter - facts and waits - DESCOPED facts and waits will do this
  - [x] cl_rest_client/api_response_objects.go DESCOPED as facts will do this
  - [x] cl_rest_client/el_rest_client - DESCOPED as facts will do this
  - [x] cl_node_metrics_info - pure POJO NO BLOCKERS
  - [ ] get render templates to have the magic strings subsituted with real values
  - [ ] confirm that the 0x30000038 value in `static_files/genesis-generation-config/cl/config.yaml.tmpl` is correct - this makes prysm work