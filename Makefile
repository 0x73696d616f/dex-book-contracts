-include .env

all: clean update build

# Clean the repo
clean :;
	@forge clean

# Install dependencies
install :;
	@forge install 

# Update dependencies
update :;
	@forge update

# Build the project
build :;
	@forge build

# Format code
format:
	@forge fmt

# Lint code
lint:
	@forge fmt --check

# Run tests
tests :;
	@forge test -vvv

# Run tests with coverage
coverage :;
	@forge coverage

# Run tests with coverage and generate lcov.info
coverage-report :;
	@forge coverage --report lcov

# Run slither static analysis
slither :;
	@slither ./src

documentation :;
	@forge doc --build

# Deploy a local blockchain
anvil :;
	@anvil -m 'test test test test test test test test test test test junk'

# This is the private key of account from the mnemonic from the "make anvil" command
deploy-anvil :;
	@forge script script/01_Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# Deploy the contract to remote network and verify the code
deploy-apothem :;
	forge script script/01_Deploy.s.sol:Deploy --broadcast --rpc-url ${RPC_URL_APOTHEM} --private-key ${PRIVATE_KEY} --etherscan-api-key abc --verifier-url https://explorer.apothem.network/api --verify --delay 20 --retries 10 --legacy -vvvv 

run-script :;
	@export FOUNDRY_PROFILE=deploy && \
	./utils/run_script.sh && \
	export FOUNDRY_PROFILE=default

run-script-local :;
	@./utils/run_script_local.sh