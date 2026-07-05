-include .env

.PHONY: all test clean build deploy-anvil deploy-sepolia \
        create-subscription-anvil fund-subscription-anvil add-consumer-anvil \
        create-subscription-sepolia fund-subscription-sepolia add-consumer-sepolia \
        perform-upkeep-anvil perform-upkeep-sepolia \
        anvil help

# Override any of these in .env
ANVIL_RPC_URL    ?= http://127.0.0.1:8545
ANVIL_ACCOUNT     ?= shariq-foundry-dev
SEPOLIA_ACCOUNT  ?= metamask_acct_1

help:
	@echo "Usage:"
	@echo ""
	@echo "  Local Anvil:"
	@echo "    make deploy-anvil"
	@echo "    make create-subscription-anvil"
	@echo "    make fund-subscription-anvil"
	@echo "    make add-consumer-anvil"
	@echo ""
	@echo "  Sepolia:"
	@echo "    make deploy-sepolia"
	@echo "    make create-subscription-sepolia"
	@echo "    make fund-subscription-sepolia"
	@echo "    make add-consumer-sepolia"
	@echo ""
	@echo "  Utilities:"
	@echo "    make anvil      - start local chain"
	@echo "    make test       - run tests"
	@echo "    make build      - compile"
	@echo "    make clean      - forge clean"
	@echo "    make format     - forge fmt"

all: clean remove install update build

clean  :; forge clean
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"
install:; forge install cyfrin/foundry-devops@0.2.2 && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install foundry-rs/forge-std@v1.8.2 && forge install transmissions11/solmate@v6
update :; forge update
build  :; forge build
test   :; forge test
snapshot:; forge snapshot
format :; forge fmt

anvil:
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# ── Anvil ──────────────────────────────────────────────────────────────────────
deploy-anvil:
	forge script script/DeployRaffle.s.sol:DeployRaffle \
		--rpc-url $(ANVIL_RPC_URL) --account $(ANVIL_ACCOUNT) --broadcast -vvvv

create-subscription-anvil:
	forge script script/Interactions.s.sol:SubscriptionCreator \
		--rpc-url $(ANVIL_RPC_URL) --account $(ANVIL_ACCOUNT) --broadcast -vvvv

fund-subscription-anvil:
	forge script script/Interactions.s.sol:SubscriptionFunder \
		--rpc-url $(ANVIL_RPC_URL) --account $(ANVIL_ACCOUNT) --broadcast -vvvv

add-consumer-anvil:
	forge script script/Interactions.s.sol:ConsumerAdder \
		--rpc-url $(ANVIL_RPC_URL) --account $(ANVIL_ACCOUNT) --broadcast -vvvv

# ── Sepolia ─────────────────────────────────────────────────────────────────
deploy-sepolia:
	forge script script/DeployRaffle.s.sol:DeployRaffle \
		--rpc-url $(ALCHEMY_SEPOLIA_RPC_URL) \
		--account $(SEPOLIA_ACCOUNT) \
		--broadcast --verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

create-subscription-sepolia:
	forge script script/Interactions.s.sol:SubscriptionCreator \
		--rpc-url $(ALCHEMY_SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast -vvvv

fund-subscription-sepolia:
	forge script script/Interactions.s.sol:SubscriptionFunder \
		--rpc-url $(ALCHEMY_SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast -vvvv

add-consumer-sepolia:
	forge script script/Interactions.s.sol:ConsumerAdder \
		--rpc-url $(ALCHEMY_SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast -vvvv

# ── Manual draw trigger (replaces Chainlink Automation) ─────────────────────
# Set ANVIL_RAFFLE_ADDRESS and SEPOLIA_RAFFLE_ADDRESS in .env after deploying.
perform-upkeep-anvil:
	cast send $(ANVIL_RAFFLE_ADDRESS) "performUpkeep(bytes)" 0x \
		--rpc-url $(ANVIL_RPC_URL) --account $(ANVIL_ACCOUNT)

perform-upkeep-sepolia:
	cast send $(SEPOLIA_RAFFLE_ADDRESS) "performUpkeep(bytes)" 0x \
		--rpc-url $(ALCHEMY_SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT)
