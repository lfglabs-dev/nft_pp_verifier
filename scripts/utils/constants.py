import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
load_dotenv()

NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "feeder_gateway_url": "https://alpha-mainnet.starknet.io/feeder_gateway",
        "gateway_url": "https://alpha-mainnet.starknet.io/gateway",
    },
    "testnet": {
        "name": "testnet",
        "explorer_url": "https://testnet.starkscan.co",
        "rpc_url": f"https://starknet-goerli.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "feeder_gateway_url": "https://alpha4.starknet.io/feeder_gateway",
        "gateway_url": "https://alpha4.starknet.io/gateway",
    },
    "devnet": {
        "name": "devnet",
        "explorer_url": "",
        "rpc_url": "http://0.0.0.0:5050/rpc",
        "feeder_gateway_url": "http://localhost:5050/feeder_gateway",
        "gateway_url": "http://localhost:5050/gateway",
    },
}

NETWORK = NETWORKS[os.getenv("STARKNET_NETWORK", "devnet")]
NETWORK["account_address"] = os.environ.get(
    f"{NETWORK['name'].upper()}_ACCOUNT_ADDRESS"
)
if NETWORK["account_address"] is None:
    logger.warning(
        f"⚠️ {NETWORK['name'].upper()}_ACCOUNT_ADDRESS not set, defaulting to ACCOUNT_ADDRESS"
    )
    NETWORK["account_address"] = os.getenv("ACCOUNT_ADDRESS")
NETWORK["private_key"] = os.environ.get(f"{NETWORK['name'].upper()}_PRIVATE_KEY")
if NETWORK["private_key"] is None:
    logger.warning(
        f"⚠️  {NETWORK['name'].upper()}_PRIVATE_KEY not set, defaulting to PRIVATE_KEY"
    )
    NETWORK["private_key"] = os.getenv("PRIVATE_KEY")
if NETWORK["name"] == "mainnet":
    NETWORK["chain_id"] = StarknetChainId.MAINNET
elif NETWORK["name"] == "testnet2":
    StarknetChainId.TESTNET2
else:
    NETWORK["chain_id"] = StarknetChainId.TESTNET

GATEWAY_CLIENT = GatewayClient(
    net={
        "feeder_gateway_url": NETWORK["feeder_gateway_url"],
        "gateway_url": NETWORK["gateway_url"],
    }
)

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
ETH_CLASS_HASH = 0x6a22bf63c7bc07effa39a25dfbd21523d211db0100a0afd054d172b81840eaf
SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}

BUILD_DIR = Path("target/release")
BUILD_DIR_V0 = Path("cairo0_abi")
BUILD_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR_V0.mkdir(exist_ok=True, parents=True)
DEPLOYMENTS_DIR = Path("deployments") / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "nft_pp_verifier_Identity", "is_account_contract": False},
    {"contract_name": "nft_pp_verifier_NftPpVerifier", "is_account_contract": False},
]

# Testnet
NAMING_ADDRESS = 0x3bab268e932d2cecd1946f100ae67ce3dff9fd234119ea2f6da57d16d29fce
PRICING_ADDRESS = 0x012bfb305562ff88860883f4d839d3a5f888ed1921aa1e7528dc9b8bcbd98e65
STARKNETID_ADDRESS = 0x783a9097b26eae0586373b2ce0ed3529ddc44069d1e0fbc4f66d42b69d6850d
TAX_ADDRESS = 0x016647623A3bc6Bdc7dfE6DFa9B7000E91D75EF2CA0D64EFd6ACcF803d4C0874
ADMIN_ADDRESS = 0x00a00373A00352aa367058555149b573322910D54FCDf3a926E3E56D0dCb4b0c
RENEWER_ADDRESS = 0x00B325463D0dDCa69Bb6234CD6FCA161b35035F14386b6403a9De208E5a1C71a

# Mainnet
NAMING_ADDRESS_MAINNET = 0x6ac597f8116f886fa1c97a23fa4e08299975ecaf6b598873ca6792b9bbfb678
PRICING_ADDRESS_MAINNET = 0x47043bdc61075ba93d3d6929567e90c890e0246353a804f29c5f0c70e3c3106
STARKNETID_ADDRESS_MAINNET = 0x05dbdedc203e92749e2e746e2d40a768d966bd243df04a6b712e222bc040a9af
TAX_ADDRESS_MAINNET = 0x00B325463D0dDCa69Bb6234CD6FCA161b35035F14386b6403a9De208E5a1C71a
ADMIN_ADDRESS_MAINNET = 0x00a00373A00352aa367058555149b573322910D54FCDf3a926E3E56D0dCb4b0c
RENEWER_ADDRESS_MAINNET = 0x0170F64DB35Ebf34E9167bBcb83FEd872b4E35240Eec4334342Ab6612a0D6239