"""
LangChain agent that connects to Keycloak-protected MCP server.

This script demonstrates:
1. Dynamic Client Registration (DCR) with Keycloak
2. Getting an OAuth token using the registered client
3. Connecting to the MCP server with Bearer token authentication
4. Using MCP tools through LangChain

Usage:
    python agents/langchainv1_keycloak.py
"""

import asyncio
import logging
import os
from datetime import datetime

import azure.identity
import httpx
from dotenv import load_dotenv
from langchain.agents import create_agent
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_openai import ChatOpenAI
from pydantic import SecretStr
from rich.logging import RichHandler

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(message)s", datefmt="[%X]", handlers=[RichHandler()])
logger = logging.getLogger("langchain_keycloak")

# Load environment variables
load_dotenv(override=True)

# MCP Server and Keycloak configuration
MCP_SERVER_URL = os.getenv("MCP_SERVER_URL")
if not MCP_SERVER_URL:
    logger.error("Environment variable MCP_SERVER_URL is not set. Please set it to the MCP server URL.")
    raise RuntimeError("Missing required environment variable: MCP_SERVER_URL")
KEYCLOAK_REALM_URL = os.getenv("KEYCLOAK_REALM_URL")
if not KEYCLOAK_REALM_URL:
    logger.error("Environment variable KEYCLOAK_REALM_URL is not set. Please set it to the Keycloak realm URL.")
    raise RuntimeError("Missing required environment variable: KEYCLOAK_REALM_URL")
# Configure language model based on API_HOST
API_HOST = os.getenv("API_HOST", "github")

if API_HOST == "azure":
    token_provider = azure.identity.get_bearer_token_provider(
        azure.identity.DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"
    )
    base_model = ChatOpenAI(
        model=os.environ.get("AZURE_OPENAI_CHAT_DEPLOYMENT"),
        base_url=os.environ["AZURE_OPENAI_ENDPOINT"] + "/openai/v1/",
        api_key=token_provider,
    )
elif API_HOST == "github":
    base_model = ChatOpenAI(
        model=os.getenv("GITHUB_MODEL", "gpt-4o"),
        base_url="https://models.inference.ai.azure.com",
        api_key=SecretStr(os.environ["GITHUB_TOKEN"]),
    )
elif API_HOST == "ollama":
    base_model = ChatOpenAI(
        model=os.environ.get("OLLAMA_MODEL", "llama3.1"),
        base_url=os.environ.get("OLLAMA_ENDPOINT", "http://localhost:11434/v1"),
        api_key=SecretStr(os.environ["OLLAMA_API_KEY"]),
    )
else:
    base_model = ChatOpenAI(model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"))


async def register_client_via_dcr() -> tuple[str, str]:
    """Register a new client dynamically using Keycloak's DCR endpoint."""
    dcr_url = f"{KEYCLOAK_REALM_URL}/clients-registrations/openid-connect"

    logger.info("📝 Registering client via DCR...")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            dcr_url,
            json={
                "client_name": f"langchain-agent-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
                "grant_types": ["client_credentials"],
                "token_endpoint_auth_method": "client_secret_basic",
            },
            headers={"Content-Type": "application/json"},
        )

        if response.status_code not in (200, 201):
            raise Exception(f"DCR failed: {response.status_code} - {response.text}")

        data = response.json()
        client_id = data["client_id"]
        client_secret = data["client_secret"]

        logger.info(f"✅ Registered client: {client_id[:20]}...")
        return client_id, client_secret


async def get_keycloak_token(client_id: str, client_secret: str) -> str:
    """Get an access token from Keycloak using client_credentials grant."""
    token_url = f"{KEYCLOAK_REALM_URL}/protocol/openid-connect/token"

    logger.info("🔑 Getting access token from Keycloak...")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            token_url,
            data={
                "grant_type": "client_credentials",
                "client_id": client_id,
                "client_secret": client_secret,
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

        if response.status_code != 200:
            raise Exception(f"Failed to get token: {response.status_code} - {response.text}")

        token_data = response.json()
        access_token = token_data["access_token"]
        expires_in = token_data.get("expires_in", "unknown")

        logger.info(f"✅ Got access token (expires in {expires_in}s)")
        return access_token


async def run_agent() -> None:
    """
    Run the agent to process expense-related queries using authenticated MCP tools.
    """
    # Register client via DCR and get token
    client_id, client_secret = await register_client_via_dcr()
    access_token = await get_keycloak_token(client_id, client_secret)

    logger.info(f"📡 Connecting to MCP server: {MCP_SERVER_URL}")

    # Initialize MCP client with Bearer token auth
    client = MultiServerMCPClient(
        {
            "expenses": {
                "url": MCP_SERVER_URL,
                "transport": "streamable_http",
                "headers": {
                    "Authorization": f"Bearer {access_token}",
                },
            }
        }
    )

    # Get tools and create agent
    logger.info("🔧 Getting available tools...")
    tools = await client.get_tools()
    logger.info(f"✅ Found {len(tools)} tools: {[t.name for t in tools]}")

    agent = create_agent(base_model, tools)

    # Prepare query with context
    today = datetime.now().strftime("%Y-%m-%d")
    user_query = "Add an expense: yesterday I bought a laptop for $1200 using my visa."

    logger.info(f"💬 User query: {user_query}")

    # Invoke agent
    response = await agent.ainvoke(
        {"messages": [SystemMessage(content=f"Today's date is {today}."), HumanMessage(content=user_query)]}
    )

    # Display result
    logger.info("=" * 60)
    logger.info("📊 Agent Response:")
    logger.info("=" * 60)

    final_message = response["messages"][-1]
    print(final_message.content)


async def main():
    print("=" * 60)
    print("LangChain Agent with Keycloak-Protected MCP Server")
    print("=" * 60)
    print("\nConfiguration:")
    print(f"  MCP Server:  {MCP_SERVER_URL}")
    print(f"  Keycloak:    {KEYCLOAK_REALM_URL}")
    print(f"  LLM Host:    {API_HOST}")
    print("  Auth:        Dynamic Client Registration (DCR)")
    print()

    await run_agent()


if __name__ == "__main__":
    asyncio.run(main())
