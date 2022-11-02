ETH2-MERGE-STARTOSIS-MODULE
===========================

This is the Startosis version of the popular [eth2-merge-kurtosis-module](https://github.com/kurtosis-tech/eth2-merge-kurtosis-module/)


### CI Missing Tasks

- [ ] Setup Releaser

### Parity Missing Tasks

- [ ] Module IO (this is blocked on Startosis Args working)
- [ ] forkmon (this is blocked on CL clients running)
- [ ] prometheus (this is blocked on CL clients running)
- [ ] grafana (this is blocked on prometheus running)
- [ ] testnet_verifier (this is blocked on CL/EL clients running)
- [ ] transaction_spammer (this is blocked on EL clients running)
- [ ] participant_network/participant_network
  - [ ] has most data generation things, needs to start EL/CL clients
- [ ] participant_network/participant
  - [ ] pure POJO should be quick to implement NO BLOCKERS
- [ ] mev_boost participant_network/mev_boost NO BLOCKERS
  - [ ] mev_boost_context pure POJO NO BLOCKERS
  - [ ] mev_boost_launcher NO BLOCKERS
- [ ] participant_network/pre_launch_data_generator (the only missing piece here is remove_service)
  - [x] data generation
  - [ ] remove services post generation
- [ ] participant_network/el (requires facts and waits)
  - [ ] besu - facts and waits
  - [ ] erigon - facts and waits
  - [ ] geth - facts and waits
  - [ ] nethermind - facts and waits
  - [ ] el_client_context pure POJO NO BLOCKERS
  - [x] el_client_launcher interface not necessary
  - [ ] el_availability_waiter - facts and waits
  - [ ] el_rest_client/api_response_objects.go NO BLOCKERS
  - [ ] el_rest_client/el_rest_client - facts and waits
- [ ] participant_network/cl (requires facts and waits)
  - [ ] lighthouse - facts and waits
  - [ ] loadstar - facts and waits
  - [ ] nymbus - facts and waits
  - [ ] prysm - facts and waits
  - [ ] teku - facts and waits
  - [ ] cl_client_context pure POJO NO BLOCKERS
  - [x] cl_client_launcher interface not necessary
  - [ ] cl_availability_waiter - facts and waits
  - [ ] cl_rest_client/api_response_objects.go NO BLOCKERS
  - [ ] cl_rest_client/el_rest_client - facts and waits
  - [ ] cl_node_metrics_info - pure POJO NO BLOCKERS