# Define the .env file path
$ENV_FILE_PATH = ".env"

# Clear the contents of the .env file
Set-Content -Path $ENV_FILE_PATH -Value $null

Add-Content -Path $ENV_FILE_PATH -Value "AZURE_OPENAI_CHAT_DEPLOYMENT=$(azd env get-value AZURE_OPENAI_CHAT_DEPLOYMENT)"
Add-Content -Path $ENV_FILE_PATH -Value "AZURE_OPENAI_CHAT_MODEL=$(azd env get-value AZURE_OPENAI_CHAT_MODEL)"
Add-Content -Path $ENV_FILE_PATH -Value "AZURE_OPENAI_ENDPOINT=$(azd env get-value AZURE_OPENAI_ENDPOINT)"
Add-Content -Path $ENV_FILE_PATH -Value "AZURE_TENANT_ID=$(azd env get-value AZURE_TENANT_ID)"
Add-Content -Path $ENV_FILE_PATH -Value "AZURE_COSMOSDB_ACCOUNT=$(azd env get-value AZURE_COSMOSDB_ACCOUNT)"
Add-Content -Path $ENV_FILE_PATH -Value "AZURE_COSMOSDB_DATABASE=$(azd env get-value AZURE_COSMOSDB_DATABASE)"
Add-Content -Path $ENV_FILE_PATH -Value "AZURE_COSMOSDB_CONTAINER=$(azd env get-value AZURE_COSMOSDB_CONTAINER)"
Add-Content -Path $ENV_FILE_PATH -Value "API_HOST=azure"
