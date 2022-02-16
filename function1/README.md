# Azure Function in Python

This page describes how this function was created.

## Create Python function app using [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local) version 4.x

```bash
func init --python
```

## Create anonymous HTTP trigger function http1

```bash
func new --name http1 --template "HTTP trigger" --authlevel "anonymous"
```

## Run the function locally to make sure it works

```bash
func start

curl http://localhost:7071/api/http1?name=Arsen
```

## Create Python virtual environment .venv

```bash
python -m venv .venv
.venv/scripts/activate
```

## Edit the function code to include simple CosmosDB read and write calls

* Add azure-cosmos to requirements.txt
* Run `pip install -r requirements.txt`
* Modify `http1/__init__.py` file to include CosmosDB SDK example calls
* Run function locally to test
