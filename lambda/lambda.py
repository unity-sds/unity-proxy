import boto3
import os

def insert_new_host_line(file_path, new_line):
    # Marker to find the position where the new line will be inserted
    marker = "### ADD MORE HOSTS BELOW THIS LINE"

    # Read the original file content
    with open(file_path, 'r') as file:
        lines = file.readlines()

    # Find the marker and insert the new line after it
    for i, line in enumerate(lines):
        if marker in line:
            # Insert new line after the marker line
            lines.insert(i + 1, new_line + "\n")
            break  # Exit the loop once the marker is found and the line is inserted

    # Write the modified content back to the file
    with open(file_path, 'w') as file:
        file.writelines(lines)


def lambda_handler(event, context):

    filename = event.get('filename')
    text_blob = event.get('template')

    efs_mount_path = '/mnt/efs'
    file_path = os.path.join(efs_mount_path, filename+".conf")
    with open(file_path, 'w') as file:
        file.write(text_blob)


    # Update main file
    file_path = "/etc/apache2/sites-enabled/main.conf"
    new_line = "Include /etc/apache2/sites-enabled/"+filename+".conf"
    insert_new_host_line(file_path, new_line)

    # Restart an ECS task
    ecs_client = boto3.client('ecs')
    service_name = os.environ.get('SERVICE_NAME')
    cluster_name = os.environ.get('CLUSTER_NAME')

    # List the tasks for a given cluster and service
    tasks_response = ecs_client.list_tasks(
        cluster=cluster_name,
        serviceName=service_name,  # Use this if tasks are part of a service
        desiredStatus='RUNNING'  # Optional: Adjust this based on the task status you're interested in
    )

    task_arns = tasks_response.get('taskArns')
    if task_arns:
        # Assuming you want to restart the first task in the list
        task_id = task_arns[0]

        # Stop the task (it should be restarted automatically if it's part of a service)
        ecs_client.stop_task(cluster=cluster_name, task=task_id)

        return_message = 'File written and ECS task restarted'
    else:
        return_message = 'No running tasks found for the specified service in the cluster'

    return {
        'statusCode': 200,
        'body': return_message
    }