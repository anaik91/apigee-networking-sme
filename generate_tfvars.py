#!/usr/bin/env python3
import toml
import os
import re
import json
import subprocess

def to_hcl(data):
    """Converts a Python object to an HCL string."""
    if isinstance(data, dict):
        lines = []
        for key, value in data.items():
            lines.append(f"  {key} = {to_hcl(value)}")
        return "{{\n{}\n}}".format('\n'.join(lines))
    elif isinstance(data, list):
        if not data:
            return "[]"
        items = ',\n'.join([f"  {to_hcl(v)}" for v in data])
        return f"[\n{items}\n]"
    elif isinstance(data, bool):
        return str(data).lower()
    elif isinstance(data, (int, float)):
        return str(data)
    elif data is None:
        return "null"
    else:
        return f'"{data}"'

def get_defined_variables(variables_file_path):
    """Parses a variables.tf file and returns a set of defined variable names."""
    defined_vars = set()
    if not os.path.exists(variables_file_path):
        return defined_vars
    
    var_regex = re.compile(r'^\s*variable\s*"([^"]+)"')
    
    with open(variables_file_path, 'r') as f:
        for line in f:
            match = var_regex.match(line)
            if match:
                defined_vars.add(match.group(1))
    return defined_vars

def run_terraform_fmt(directory):
    """Runs terraform fmt in the specified directory."""
    try:
        print(f"Running terraform fmt in {directory}...")
        subprocess.run(['terraform', 'fmt'], cwd=directory, check=True, capture_output=True, text=True)
    except FileNotFoundError:
        print("Error: terraform command not found. Please ensure Terraform is installed and in your PATH.")
    except subprocess.CalledProcessError as e:
        print(f"Error running terraform fmt in {directory}:")
        print(e.stderr)

def generate_tfvars():
    """
    Reads the defaults.toml file and generates terraform.tfvars
    for each specified subdirectory, injecting common variables only if they
    are defined in the subfolder's variables.tf.
    """
    try:
        with open('defaults.toml', 'r') as f:
            config = toml.load(f)
    except FileNotFoundError:
        print("Error: defaults.toml not found in the root directory.")
        return
    except toml.TomlDecodeError as e:
        print(f"Error decoding TOML file: {e}")
        return

    common_vars = config.get('common', {})

    for section, values in config.items():
        if section == 'common':
            continue

        # directory = section
        directory = section.replace('.', '/')

        if not os.path.isdir(directory):
            print(f"Warning: Directory '{directory}' not found. Skipping.")
            continue

        variables_tf_path = os.path.join(directory, 'variables.tf')
        subfolder_defined_vars = get_defined_variables(variables_tf_path)

        tfvars_path = os.path.join(directory, 'terraform.tfvars')
        
        print(f"Generating {tfvars_path}...")

        with open(tfvars_path, 'w') as f:
            f.write("# Auto-generated from defaults.toml. Do not edit manually.\n\n")
            
            # Write common variables if they are defined in the subfolder's variables.tf
            injected_common = False
            if common_vars:
                for key, value in common_vars.items():
                    if key in subfolder_defined_vars:
                        f.write(f"{key} = {to_hcl(value)}\n")
                        injected_common = True
                if injected_common:
                    f.write("\n")

            # Write section-specific variables
            for key, value in values.items():
                if key not in common_vars:
                    if key in 'exposure_subnets' or key in 'psc_subnets':
                        if isinstance(value, list):
                            value[0]['secondary_ip_range'] = None
                    f.write(f"{key} = {to_hcl(value)}\n")
        
        run_terraform_fmt(directory)

    print("\nFinished generating tfvars files.")

if __name__ == "__main__":
    generate_tfvars()
