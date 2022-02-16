import logging

import azure.functions as func

import os
from azure.cosmos import CosmosClient, exceptions

# Initialize Cosmos client
cosmos_client = CosmosClient(os.environ['CosmosDbEndpoint'], os.environ['CosmosDbKey'])
database_client = cosmos_client.get_database_client('db1')
container_client = database_client.get_container_client('container1')

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            name = req_body.get('name')

    if name:
        count = 1
        try:
            counter = container_client.read_item(item=name, partition_key=name)
            counter['count'] += 1
            container_client.replace_item(item=counter['id'], body=counter)
            count = counter['count']
        except exceptions.CosmosResourceNotFoundError:
            # Create new item
            container_client.create_item({'id': name, 'count': count})
        return func.HttpResponse(f"Hello, {name}! Current count is {count}.")
    else:
        return func.HttpResponse(
             "Pass a name in the query string or in the request body.",
             status_code=200
        )
