# Changelog

## [0.3.0](https://github.com/kurtosis-tech/eth2-package/compare/0.2.0...0.3.0) (2023-09-03)


### ⚠ BREAKING CHANGES

* Uses the `plan` object. Users will have to update their Kurtosis CLI to >= 0.63.0 and restart the engine

### Features

* add beacon-metrics-gazer + beacon-metrics-gazer grafana dashboard ([#114](https://github.com/kurtosis-tech/eth2-package/issues/114)) ([5540587](https://github.com/kurtosis-tech/eth2-package/commit/55405874ee50826b65dc2a5664e2b8bf9d7f668b))
* add deneb support ([#96](https://github.com/kurtosis-tech/eth2-package/issues/96)) ([07ed500](https://github.com/kurtosis-tech/eth2-package/commit/07ed500890ab01b6bed04cdacc19b9373e6a4b6a))
* add ethereumjs to nightly runners ([b86d886](https://github.com/kurtosis-tech/eth2-package/commit/b86d886197ddad2d0ea78efac7e11109838b5dd9))
* add ethereumjs to nightly runners ([#154](https://github.com/kurtosis-tech/eth2-package/issues/154)) ([b86d886](https://github.com/kurtosis-tech/eth2-package/commit/b86d886197ddad2d0ea78efac7e11109838b5dd9))
* add forkmon ([#107](https://github.com/kurtosis-tech/eth2-package/issues/107)) ([2a8ad19](https://github.com/kurtosis-tech/eth2-package/commit/2a8ad19e8ad9c4202bd6dc9dff28eb3ea2cf08f2))
* add light-beaconchain-explorer ([83e01a1](https://github.com/kurtosis-tech/eth2-package/commit/83e01a114a3bad970ebecc2ae10bc863e14cdb3a))
* add light-beaconchain-explorer ([#125](https://github.com/kurtosis-tech/eth2-package/issues/125)) ([83e01a1](https://github.com/kurtosis-tech/eth2-package/commit/83e01a114a3bad970ebecc2ae10bc863e14cdb3a))
* add multiple endpoint support for lightbeaconchain expolorer ([#151](https://github.com/kurtosis-tech/eth2-package/issues/151)) ([68572cd](https://github.com/kurtosis-tech/eth2-package/commit/68572cdddb1e2074892f148b69e603a2ee06edb8))
* counting by summing each participant ([f9b638b](https://github.com/kurtosis-tech/eth2-package/commit/f9b638bc1c26be34fd3dd0ad6e4d59ee4ecd66c3))
* counting by summing each participant ([#112](https://github.com/kurtosis-tech/eth2-package/issues/112)) ([f9b638b](https://github.com/kurtosis-tech/eth2-package/commit/f9b638bc1c26be34fd3dd0ad6e4d59ee4ecd66c3))
* disable login for grafana ([4d7df4b](https://github.com/kurtosis-tech/eth2-package/commit/4d7df4be895b950119d1e5fabe0e4ae3cc0c822e))
* disable login for grafana ([#122](https://github.com/kurtosis-tech/eth2-package/issues/122)) ([4d7df4b](https://github.com/kurtosis-tech/eth2-package/commit/4d7df4be895b950119d1e5fabe0e4ae3cc0c822e))
* **formatting:** Add editorconfig, move everything to using tabs (4) ([#106](https://github.com/kurtosis-tech/eth2-package/issues/106)) ([cb0fc69](https://github.com/kurtosis-tech/eth2-package/commit/cb0fc695cce7a64386349193ef3cd3ebf692f18d))
* launch the mock mev builder ([#94](https://github.com/kurtosis-tech/eth2-package/issues/94)) ([7fcd3e2](https://github.com/kurtosis-tech/eth2-package/commit/7fcd3e24aa1d1c23afa0c37ba3c939c204720d31))
* make it possible to have capella on epoch 0 or non 0 ([#108](https://github.com/kurtosis-tech/eth2-package/issues/108)) ([1133497](https://github.com/kurtosis-tech/eth2-package/commit/1133497b18c6fa46f2b6483c9b2eea27bc272868))
* make mev more configurable ([#164](https://github.com/kurtosis-tech/eth2-package/issues/164)) ([0165ef1](https://github.com/kurtosis-tech/eth2-package/commit/0165ef1a67a77dfca2030c1b36ed12d00ae48d18))
* parameterize mev_boost and  mev_builder images ([#171](https://github.com/kurtosis-tech/eth2-package/issues/171)) ([28adec1](https://github.com/kurtosis-tech/eth2-package/commit/28adec114779e0b5946705038cb19c859c430242))
* snooper support ([#121](https://github.com/kurtosis-tech/eth2-package/issues/121)) ([d2cccf4](https://github.com/kurtosis-tech/eth2-package/commit/d2cccf4af8873a912cc4389f8db75ce4e11e2e44))
* support full MEV ([#115](https://github.com/kurtosis-tech/eth2-package/issues/115)) ([e9e8c41](https://github.com/kurtosis-tech/eth2-package/commit/e9e8c418c4a7a9ff099b4514430f8235f4ad1331))
* use eth-network-package to spin up participant network ([#90](https://github.com/kurtosis-tech/eth2-package/issues/90)) ([91029ac](https://github.com/kurtosis-tech/eth2-package/commit/91029acfb7867c134baac3aaf758eb06f67fe997))


### Bug Fixes

* a bug around participants ([#129](https://github.com/kurtosis-tech/eth2-package/issues/129)) ([9382767](https://github.com/kurtosis-tech/eth2-package/commit/9382767f88690817de189a3551c37325389faf98))
* delay deneb to 500 epoch ([#102](https://github.com/kurtosis-tech/eth2-package/issues/102)) ([d07270b](https://github.com/kurtosis-tech/eth2-package/commit/d07270bc9802fe2adc44d70e6e8e9c274958eacb))
* dont spin up extra el/cl client for mock-mev ([#158](https://github.com/kurtosis-tech/eth2-package/issues/158)) ([46d67fc](https://github.com/kurtosis-tech/eth2-package/commit/46d67fc5878a01984623c8f3ac9f667d1fb891f2))
* fix an arg parsing bug ([#135](https://github.com/kurtosis-tech/eth2-package/issues/135)) ([f084e7c](https://github.com/kurtosis-tech/eth2-package/commit/f084e7c72738b7afd71d9a1a05f6fba4c388a5de))
* fix passed argument parsing ([#85](https://github.com/kurtosis-tech/eth2-package/issues/85)) ([a5d40e9](https://github.com/kurtosis-tech/eth2-package/commit/a5d40e9bd178ff7ade06f22818475d01546f861a))
* fixed teku validator params for MEV ([#149](https://github.com/kurtosis-tech/eth2-package/issues/149)) ([b0079cf](https://github.com/kurtosis-tech/eth2-package/commit/b0079cff08b7c5812e97151ba56a0929593516ba))
* fixing nimbus payload url ([#155](https://github.com/kurtosis-tech/eth2-package/issues/155)) ([55c1f59](https://github.com/kurtosis-tech/eth2-package/commit/55c1f59404872c26315844995cbea6a4286b1cb2))
* geth failing after ethash package removal ([#93](https://github.com/kurtosis-tech/eth2-package/issues/93)) ([41e3d2c](https://github.com/kurtosis-tech/eth2-package/commit/41e3d2cd292dd19b805e5c93f3d65ec0ba063104)), closes [#91](https://github.com/kurtosis-tech/eth2-package/issues/91)
* make besu a bootnode ([29296cd](https://github.com/kurtosis-tech/eth2-package/commit/29296cd1c78615743d32f68ca50fb51121c5921c))
* make besu a bootnode ([#146](https://github.com/kurtosis-tech/eth2-package/issues/146)) ([29296cd](https://github.com/kurtosis-tech/eth2-package/commit/29296cd1c78615743d32f68ca50fb51121c5921c))
* make this work with kurtosis 0.65.0 ([#73](https://github.com/kurtosis-tech/eth2-package/issues/73)) ([13c72ec](https://github.com/kurtosis-tech/eth2-package/commit/13c72ec56e4da79c6a9bd6802a0995c6b00d0a0a))
* mention reth in package readme ([#133](https://github.com/kurtosis-tech/eth2-package/issues/133)) ([d11a689](https://github.com/kurtosis-tech/eth2-package/commit/d11a6898b9f7377a5e8c50ccd3859ec5eed0e556))
* move parallel keystore generation to global config ([0789eed](https://github.com/kurtosis-tech/eth2-package/commit/0789eedb1f77c418944a2cc7047edd95256d983d))
* move parallel keystore generation to global config ([#130](https://github.com/kurtosis-tech/eth2-package/issues/130)) ([0789eed](https://github.com/kurtosis-tech/eth2-package/commit/0789eedb1f77c418944a2cc7047edd95256d983d))
* nightly tests that rely on etherejums get the right image ([#159](https://github.com/kurtosis-tech/eth2-package/issues/159)) ([97b4d33](https://github.com/kurtosis-tech/eth2-package/commit/97b4d33aa4c236e9615df7f3c62e6221a056385f))
* Nimbus can't run when slot time is below 12s ([#100](https://github.com/kurtosis-tech/eth2-package/issues/100)) ([c38bff9](https://github.com/kurtosis-tech/eth2-package/commit/c38bff9f5d6d49f57c1a66c84828f8bad9c550cc))
* pass right mev-boost url to teku ([#147](https://github.com/kurtosis-tech/eth2-package/issues/147)) ([8bb75d9](https://github.com/kurtosis-tech/eth2-package/commit/8bb75d91b9a45a5a2fc7e64118d5913ffef138f4))
* pin postgres package ([#174](https://github.com/kurtosis-tech/eth2-package/issues/174)) ([6b8d9d3](https://github.com/kurtosis-tech/eth2-package/commit/6b8d9d39fd06d1dc01d4f3cbbc6c20f9f962bb6a))
* Remove nethermind restriction ([#126](https://github.com/kurtosis-tech/eth2-package/issues/126)) ([373c6c9](https://github.com/kurtosis-tech/eth2-package/commit/373c6c9b45ac4fc9bee930bc5430921cd3a16a1f))
* Switch default images to latest ([#99](https://github.com/kurtosis-tech/eth2-package/issues/99)) ([4a85c9d](https://github.com/kurtosis-tech/eth2-package/commit/4a85c9dccb0e5cbd809ed7047b78e7190d466a91))
* Update enclave name flag ([#87](https://github.com/kurtosis-tech/eth2-package/issues/87)) ([6531a7a](https://github.com/kurtosis-tech/eth2-package/commit/6531a7af37faa2d227a2a53739ca7ae0cd4aed9e))
* update genesis generator to support netherminds new format ([#68](https://github.com/kurtosis-tech/eth2-package/issues/68)) ([094352d](https://github.com/kurtosis-tech/eth2-package/commit/094352d6666755da5de6ed3f4b78fd5f37c01f7f))
* update nightly runner ([#163](https://github.com/kurtosis-tech/eth2-package/issues/163)) ([4eba65d](https://github.com/kurtosis-tech/eth2-package/commit/4eba65df4fd29ece8a89ac77066e68d330fc2297))
* use eth maintained tx-fuzz ([#110](https://github.com/kurtosis-tech/eth2-package/issues/110)) ([b0903bd](https://github.com/kurtosis-tech/eth2-package/commit/b0903bdae490ffa30251ddede9edca21105fba48))
* use flashbots builder ([#162](https://github.com/kurtosis-tech/eth2-package/issues/162)) ([7a0c2d0](https://github.com/kurtosis-tech/eth2-package/commit/7a0c2d03dff1dd0ee5c92b5c2f9478f4e56f6920))
* use mev-boost-relay by flashbots ([#141](https://github.com/kurtosis-tech/eth2-package/issues/141)) ([fca62fc](https://github.com/kurtosis-tech/eth2-package/commit/fca62fcee23525cc891eaf2494a2b1cb694f5bf4))
* use named artifacts ([#69](https://github.com/kurtosis-tech/eth2-package/issues/69)) ([968f073](https://github.com/kurtosis-tech/eth2-package/commit/968f0734a0ee834c75e184b758989ce1dc9d58be)), closes [#70](https://github.com/kurtosis-tech/eth2-package/issues/70)
* Use plan object ([#65](https://github.com/kurtosis-tech/eth2-package/issues/65)) ([8e5d185](https://github.com/kurtosis-tech/eth2-package/commit/8e5d18558f92a9fc71ae9a70f1ca139df406d7b7))
* use v2 endoint to get the head block ([#153](https://github.com/kurtosis-tech/eth2-package/issues/153)) ([f084711](https://github.com/kurtosis-tech/eth2-package/commit/f084711061c777c78ef8f002a4f7e597c27e8eb5))
* work with latest eth-network-package ([14dc957](https://github.com/kurtosis-tech/eth2-package/commit/14dc95776e16f8cdf8ac83a03c53abad489cb8f7))
* work with latest eth-network-package ([#116](https://github.com/kurtosis-tech/eth2-package/issues/116)) ([14dc957](https://github.com/kurtosis-tech/eth2-package/commit/14dc95776e16f8cdf8ac83a03c53abad489cb8f7))

## 0.2.0

- Adds config variables for `genesis_delay` and `capella_fork_epoch`
- Updates genesis generator version
- Fixes genesis timestamp such that the shanghai fork can happen based on timestamps
- Update `--enclave-id` flag to `--enclave` in README

### Breaking Change

- Introduced optional application protocol and renamed protocol to transport_protocol

## 0.1.0

### Breaking changes

- Updated `struct` to `PortSpec` for declaring port definitions

### Changes

- Change `exec` syntax

## 0.0.5

### Fixes

- Fix bug with input parsing of participants
- Fix bug with `get_enode_for_node` being assigned to two parameters

### Changes

- Updated `run(input_args)` to `run(args)`
- Refactor code to use `wait` and `request` commands
- Removed `print(output)` at the end as it is now printed by the framework
- Updates nimbus default docker image
- Updates `genesis-generator` image to include a fix for nimbus post-merge genesis
- Use the `args` argument instead of flags

## 0.0.4

### Changes

- Removed 'module' key in the 'kurtosis.yml' file

## 0.0.3

### Changes

- Replaced 'module' with 'package' where relevant
- Removed protobuf types as they are now unsupported in Kurtosis.
- Renamed `kurtotis.mod` to `kurtosis.yml`

### Fixes

- Fixed a bug in `run` of `main.star` where we'd refer to `module_io` instead of `package_io`

## 0.0.2

### Features

- Added the docs

### Fixes

- Renamed `num_validators_per_keynode` to `num_validator_keys_per_node`
- Moved away from `load` infavor of `import_module`
- Moved away from `store_files_from_service` to `store_service_files`
- Removed empty `ports` from a few service configs as passing it is now optional
- Adjusted to the new render templates config
- Moved away from passing json string to struct/dict for render templates

### Changes

- Move from `main` to `run` in `main.star`

## 0.0.1

### Features

- Changed the .circlei/config.yml to apply to Startosis
- Added genesis_constants
- Added a lot of participant_network/pre_launch_data_generator
- Added a lot of simple objects that just keep data
- Added monitoring on top of the repo
- Almost perfect parity with the eth2-merge-kurtosis-module

### Fixes

- Fixes some bugs with the initial implementation of the monitors

## 0.0.0

- Initial commit
