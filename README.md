## Experimental Decentralize Ecommerce(DeCom)

This is an ongoing working in progress experimental decentralize store, which will be deployed on one of the ethereum layer2 network. This store can only list one item for simplicity, since it a demo version. 

## Contract address

website: https://apsostore.com

Arbitrum
contract=0x2beBCcBe0c1308457d382e202Cd89bccB81177e8
priceV3Contract=0xaB7B3F279927aE8F20C92569cE39050aEfdC61E7

Arbitrum Sepolia
contract=0xc5C993210F66eDDe0fe3fdc2333E69739AcE711a
priceV3Contract=0xfc4aa846db47Afb4b15361C6516FC96DB5A86166

Sepolia
contract=0x1C7595cD405Eb31437Fe682c2F603E0813d6C9eD
priceV3Contract=0xC95C9f4680489A720701f8C90830EE8656996Ec3


## Setup

```
$ forge build
$ forge test
```

-See env.example before any of the following depoloyment.

-create .env file and structure the variables according to env.example.


## Arbitrum deployment

```
$ source .env
$ forge script script/DeCom.s.sol:Arbitrum --rpc-url $ARBITRUM --broadcast 
```


## Local testnet deployment

```
$ anvil
$ source .env
$ forge script script/DeCom.s.sol:Anvil --fork-url http://localhost:8545 --broadcast
```

## Sepolia testnet deployment

```
$ source .env
$ forge script script/DeCom.s.sol:Sepolia --rpc-url $SEPOLIA_RPC_URL --broadcast
```


## Arbitrum Sepolia testnet deployment

```
$ source .env
$ forge script script/DeCom.s.sol:ArbitrumSepolia --rpc-url $ARBITRUM_SEPOLIA --broadcast 
```








