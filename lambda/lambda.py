import boto3
import os

def lambda_handler(event, context):

    filename = event.get('filename')
    text_blob = event.get('template')

    efs_mount_path = '/mnt/efs'
    file_path = os.path.join(efs_mount_path, filename+".conf")
    with open(file_path, 'w') as file:
        file.write(text_blob)

    # Restart an ECS task
    ecs_client = boto3.client('ecs')
    cluster_name = os.environ.get('CLUSTER_NAME')
    task_id = os.environ.get('TASK_ID')

    # Stop the task (it should be restarted automatically if it's part of a service)
    ecs_client.stop_task(cluster=cluster_name, task=task_id)

    return {
        'statusCode': 200,
        'body': 'File written and ECS task restarted'
    }