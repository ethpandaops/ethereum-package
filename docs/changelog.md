# TBD

### Fixes
- Fix bug with input parsing of participants

### Changes
- Updated `run(input_args)` to `run(args)`
- Removed `print(output)` at the end as it is now printed by the framework
- Updates nimbus default docker image
- Updates `genesis-generator` image to include a fix for nimbus post-merge genesis
- Use the `args` argument instead of flags

# 0.0.4
### Changes
- Removed 'module' key in the 'kurtosis.yml' file

# 0.0.3
### Changes
- Replaced 'module' with 'package' where relevant
- Removed protobuf types as they are now unsupported in Kurtosis.
- Renamed `kurtotis.mod` to `kurtosis.yml`

### Fixes
- Fixed a bug in `run` of `main.star` where we'd refer to `module_io` instead of `package_io`

# 0.0.2

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

# 0.0.1

### Features
- Changed the .circlei/config.yml to apply to Startosis
- Added genesis_constants
- Added a lot of participant_network/pre_launch_data_generator
- Added a lot of simple objects that just keep data
- Added monitoring on top of the repo
- Almost perfect parity with the eth2-merge-kurtosis-module

### Fixes
- Fixes some bugs with the initial implementation of the monitors

# 0.0.0
* Initial commit
