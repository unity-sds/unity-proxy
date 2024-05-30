#!/usr/bin/env python
import os
from pathlib import Path

import boto3

config_path = Path("/etc/apache2/sites-enabled")


def fetch_config_ssm(project, venue):
    client = boto3.client("ssm")
    parameters = client.get_parameters_by_path(
        Path=f"/unity/{project}/{venue}/cs/management/proxy/configurations",
        Recursive=True,
        ParameterFilters=[
            {
                "Key": "Type",
                "Values": [
                    "String",
                ],
            },
        ],
        WithDecryption=False,
    )
    return parameters["Parameters"]


def template_file(parameters, debug):
    # sort the parameters by the ssm param name, and then make a list of just
    # their values for insertion
    param_config = [
        parm["Value"] for parm in sorted(parameters, key=lambda x: x["Name"])
    ]
    if debug:  # so we can debug what SSM says it should/will be
        for ln in param_config:
            print(ln)
    else:  # otherwise, write them all to the config file
        with open(config_path / "main.conf", "w") as file:
            file.writelines(param_config)


if __name__ == "__main__":
    if os.getenv("UNITY_PROJECT") and os.getenv("UNITY_VENUE"):
        template_file(
            fetch_config_ssm(os.getenv("UNITY_PROJECT"), os.getenv("UNITY_VENUE")),
            os.getenv("DEBUG"),
        )
    else:
        print("Both UNITY_PROJECT and UNITY_VENUE must be set, quitting")
        exit(1)
