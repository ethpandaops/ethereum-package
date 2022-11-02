ETH2-MERGE-STARTOSIS-MODULE
===========================

This is the Startosis version of the popular [eth2-merge-kurtosis-module](https://github.com/kurtosis-tech/eth2-merge-kurtosis-module/)


### Parity Missing Tasks

- [ ] Module IO (this is blocked on Startosis Args working)
- [x] forkmon (this is blocked on CL clients running)
- [x] prometheus (this is blocked on CL clients running)
- [x] grafana (this is blocked on prometheus running)
- [ ] grafana needs an upload files endpoint in Startosis
- [ ] testnet_verifier (this is blocked on CL/EL clients running)
- [ ] transaction_spammer (this is blocked on EL clients running)
- [ ] participant_network/participant_network
  - [ ] has most data generation things, needs to start EL/CL clients
  - [ ] needs upload files to be implemented
- [x] participant_network/participant
  - [x] pure POJO should be quick to implement NO BLOCKERS
- [x] mev_boost participant_network/mev_boost NO BLOCKERS - removed some attributes that aren't used
  - [x] mev_boost_context pure POJO NO BLOCKERS
  - [x] mev_boost_launcher NO BLOCKERS
- [ ] participant_network/pre_launch_data_generator (the only missing piece here is remove_service)
  - [x] data generation
  - [ ] remove services post generation
- [ ] participant_network/el (requires facts and waits)
  - [ ] besu - facts and waits
  - [ ] erigon - facts and waits
  - [ ] geth - facts and waits
  - [ ] nethermind - facts and waits
  - [x] el_client_context pure POJO NO BLOCKERS
  - [x] el_client_launcher interface not necessary
  - [ ] el_availability_waiter - facts and waits
  - [x] el_rest_client/api_response_objects.go DESCOPED as facts will do this
  - [x] el_rest_client/el_rest_client - facts and waits  DESCOPED as facts will do this
- [ ] participant_network/cl (requires facts and waits)
  - [ ] lighthouse - facts and waits
  - [ ] loadstar - facts and waits
  - [ ] nymbus - facts and waits
  - [ ] prysm - facts and waits
  - [ ] teku - facts and waits
  - [x] cl_client_context pure POJO NO BLOCKERS
  - [x] cl_client_launcher interface not necessary
  - [ ] cl_availability_waiter - facts and waits
  - [x] cl_rest_client/api_response_objects.go DESCOPED as facts will do this
  - [x] cl_rest_client/el_rest_client - DESCOPED as facts will do this
  - [x] cl_node_metrics_info - pure POJO NO BLOCKERS