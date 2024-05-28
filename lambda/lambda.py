import os

import boto3


def lambda_handler(event, context):

    # Restart an ECS task
    ecs_client = boto3.client("ecs")
    service_name = os.environ.get("SERVICE_NAME")
    cluster_name = os.environ.get("CLUSTER_NAME")

    # List the tasks for a given cluster and service
    tasks_response = ecs_client.list_tasks(
        cluster=cluster_name,
        serviceName=service_name,  # Use this if tasks are part of a service
        desiredStatus="RUNNING",  # Optional: Adjust this based on the task status you're interested in
    )

    task_arns = tasks_response.get("taskArns")
    if task_arns:
        # Assuming you want to restart the first task in the list
        task_id = task_arns[0]

        # Stop the task (it should be restarted automatically if it's part of a service)
        ecs_client.stop_task(cluster=cluster_name, task=task_id)

        return_message = "ECS task restarted"
    else:
        return_message = (
            "No running tasks found for the specified service in the cluster"
        )

    return {"statusCode": 200, "body": return_message}
