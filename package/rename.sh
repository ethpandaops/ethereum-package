#!/bin/bash

# Helper function to perform replacements
perform_replacements() {
    local input_file="$1"
    shift
    local replacements=("$@")

    for ((i = 0; i < ${#replacements[@]}; i+=2)); do
        original="${replacements[$i]}"
        replacement="${replacements[$i+1]}"
        sed -i -- "s/$original/$replacement/g" "$input_file"
    done
}

# Check if an input file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

# Define the input YAML file
input_file="$1"

# Define the replacement pairs as a list
replacements=(
    el_client_type
    el_type
    el_client_image
    el_image
    el_client_log_level
    el_log_level
    el_client_volume_size
    el_volume_size
    cl_client_type
    cl_type
    cl_client_image
    cl_image
    cl_client_volume_size
    cl_volume_size
    cl_client_log_level
    cl_log_level
    beacon_extra_params
    cl_extra_params
    beacon_extra_labels
    cl_extra_labels
    bn_min_cpu
    cl_min_cpu
    bn_max_cpu
    cl_max_cpu
    bn_min_mem
    cl_min_mem
    bn_max_mem
    cl_max_mem
    use_separate_validator_client
    use_separate_vc
    validator_client_type
    vc_type
    validator_tolerations
    vc_tolerations
    validator_client_image
    vc_image
    validator_extra_params
    vc_extra_params
    validator_extra_labels
    vc_extra_labels
    v_min_cpu
    vc_min_cpu
    v_max_cpu
    vc_max_cpu
    v_min_mem
    vc_min_mem
    v_max_mem
    vc_max_mem
    global_client_log_level
    global_log_level
    full
    flashbots
)

# Perform replacements
perform_replacements "$input_file" "${replacements[@]}"

echo "Replacements completed."
