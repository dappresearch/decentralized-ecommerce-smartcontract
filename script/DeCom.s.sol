// SPDX-License-Identifier: No License
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DeCom.sol";
import "../src/mocks/MockAggregratorV3Interface.sol";

import "forge-std/console.sol";

contract Anvil is Script {
    DeCom public decom;

    MockAggregratorV3Interface public mockAgg;

    address owner = vm.envAddress("OWNER");

    uint16 constant PRICE = 15;
    uint16 constant SHIPPINGCOST = 0;
    uint32 constant STOCK = 50; 

    string publicKey = vm.envString("PUBLIC_KEY");
    string nftLink = vm.envString("NFT_LINK");
    
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);
        console.log(owner);
        mockAgg = new MockAggregratorV3Interface();

        decom = new DeCom(owner, address(mockAgg), PRICE, SHIPPINGCOST, STOCK, publicKey, nftLink);
        console.log("Mock Aggregator deployed at:", address(mockAgg));
        console.log("DeCom deployed at:", address(decom));
    }
}

contract Sepolia is Script {
    DeCom public decom;

    address ethUsdPair = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    address owner = vm.envAddress("OWNER");

    uint16 constant PRICE = 15;
    uint16 constant SHIPPINGCOST = 0;
    uint32 constant STOCK = 30;

    string publicKey = vm.envString("PUBLIC_KEY");
    string nftLink = vm.envString("NFT_LINK");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        console.log(owner);
        decom = new DeCom(owner, ethUsdPair, PRICE, SHIPPINGCOST, STOCK, publicKey, nftLink);
        console.log("DeCom deployed at:", address(decom));
        console.log("PriceFeedV3 Address:",address(decom.priceFeed()));
        console.log("Get totalCost", decom.totalCost(1));
    }
}

contract ArbitrumSepolia is Script {
    DeCom public decom;

    address ethUsdPair = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    address owner = vm.envAddress("OWNER");

    uint16 constant PRICE = 15;
    uint16 constant SHIPPINGCOST = 0;
    uint32 constant STOCK = 100;

    string publicKey = vm.envString("PUBLIC_KEY");
    string nftLink = vm.envString("NFT_LINK");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        console.log(owner);
        decom = new DeCom(owner, ethUsdPair, PRICE, SHIPPINGCOST, STOCK, publicKey, nftLink);
        console.log("DeCom deployed at:", address(decom));
        console.log("Get totalCost", decom.totalCost(1));
        console.log("PriceFeedV3 Address:",address(decom.priceFeed()));
    }
}

contract Arbitrum is Script {
    DeCom public decom;

    address ethUsdPair = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    
    address owner = vm.envAddress("OWNER");

    uint16 constant PRICE = 15;
    uint16 constant SHIPPINGCOST = 0;
    uint32 constant STOCK = 105;

    string publicKey = vm.envString("PUBLIC_KEY");
    string nftLink = vm.envString("NFT_LINK");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        console.log(owner);
        decom = new DeCom(owner, ethUsdPair, PRICE, SHIPPINGCOST, STOCK, publicKey, nftLink);
        console.log("DeCom deployed at:", address(decom));
        console.log("Get totalCost", decom.totalCost(1));
        console.log("PriceFeedV3 Address:",address(decom.priceFeed()));
    }
}






