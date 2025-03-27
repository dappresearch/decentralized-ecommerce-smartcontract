// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockAggregratorV3Interface} from "../src/mocks/MockAggregratorV3Interface.sol";

import "../src/DeCom.sol";

contract PenguStoreTest is Test {
    DeCom public decom;

    MockAggregratorV3Interface public mockOracle;

    PriceFeedV3 public priceFeed;

    IDeCom idecom;

    uint32 orderQty;
    uint256 purchaseAmount;

    address ownerAddr;
    address buyer1;
    address buyer2;
    address buyer3;

    address randomGuy;

    uint32 constant STOCK = 300;
    
    // Single item price./
    uint16 constant PRICE = 15;

    uint16 constant SHIPPINGCOST = 11;

    // (Price + Shipping cost) for quanity 1, convert into wei
    // $15 + $11 = $26, calculated at the eth price of $3200
    // see method `totalStock` and contract `MockAggregratorV3Interface`.
    uint256 totalPrice = 8125000000000000;

    string PUBLICKEY = "7758f333f9aab706bab6c147620f6b83b55a72c4206d40463bf8d3d92ae9f30df97987f3e96c397cad726ba5177e3600d8167101cf2d02e075e7402297be538c";
    string NFTLINK = "https://ipfs.filebase.io/ipfs/bafybeid2ppqsnfahup7lr2lutxbw3dcfbimzkuj6gzyj2ha5tyovv6dsm4/";

    event StockUpdated(uint32 indexed newTotalStock);
    event PriceUpdated(uint256 indexed newPrice);
    event PublicKeyUpdated(string indexed publicKey);
    event ShippingCostUpdated(uint256 indexed newShippingCost);
    event PriceFeedV3Updated(address indexed priceFeed);
    event PurchaseOrder(
        uint32 indexed orderNo,
        address indexed buyer,
        uint32 indexed quantity,
        uint256 amount,
        string destination
    );
    event OrderShipped(uint32 indexed orderNo, address indexed buyer);
    event Withdraw(uint256 indexed amount, address indexed owner);
    event OrderCancelled(uint32 indexed orderNo, address indexed buyer);
    event RefundCollected(
        uint32 indexed orderNo,
        address indexed buyer,
        uint256 indexed amount
    );
    event AdminUpdated(address indexed newAdmin, bool indexed isAdmin);
    event TolarenceValueUpdated(uint8 indexed newToleranceValue);

    
    enum Status {
        none,
        pending,
        shipped,
        cancelled,
        refund
    }

    function setUp() public {
        ownerAddr = address(3);
        buyer1 = address(2);
        buyer2 = address(4);
        buyer3 = address(5);

        vm.prank(buyer1);

        mockOracle = new MockAggregratorV3Interface();

        priceFeed = new PriceFeedV3(address(mockOracle));

        decom = new DeCom(
            ownerAddr,
            address(mockOracle),
            PRICE,
            SHIPPINGCOST,
            STOCK,
            PUBLICKEY,
            NFTLINK
        );

        vm.label(ownerAddr, "Owner Address");

        vm.deal(buyer1, 5 ether);
        vm.deal(buyer2, 5 ether);
        vm.deal(buyer3, 5 ether);
    }

    function testTotalCost() public view {
        uint256 totalCostInWei = 8125000000000000;
        uint256 totalCost = decom.totalCost(1);
        assertEq(totalCost, totalCostInWei);

        totalCostInWei = 26875000000000000;
        totalCost = decom.totalCost(5);
        assertEq(totalCost, totalCostInWei);
    }

    function testPriceFeedV3_getLatestDataFeedStartedAt() public view {
        uint mockStartedAt = 1736221945;
        uint256 startedAt = priceFeed.getChainlinkDataFeedStartedAt();
        assertEq(mockStartedAt, startedAt);
    }
    
    function testSetStock() public {
        uint32 qty = 300;

        vm.prank(ownerAddr);

        vm.expectEmit(true, false, false, false);
        emit StockUpdated(qty);
        decom.setStock(qty);

        assertEq(decom.totalStock(), qty, "Incorrect total stock");
    }

    function testSetStock_Fail_onlyOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer1
            )
        );
        vm.prank(buyer1);
        decom.setStock(300);
    }

    function testSetPrice() public {
        uint16 newPrice = 300;

        vm.prank(ownerAddr);

        vm.expectEmit(true, false, false, false);
        emit PriceUpdated(newPrice);
        decom.setPrice(newPrice);

        assertEq(decom.price(), newPrice, "Incorrect price");
    }

    function testSetAdmin() public {
        vm.prank(ownerAddr);

        vm.expectEmit(true, true, false, false);
        emit AdminUpdated(buyer1, true);
        decom.setAdmin(buyer1, true);

        assertEq(decom.admins(buyer1), true, "Incorrect admin status");
    }

    function testSetAdmin_Fail_onlyOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer1
            )
        );
        vm.prank(buyer1);
        decom.setAdmin(buyer1, true);
    }

    function testSetToleranceValue() public {
        uint8 newTolarence = 3;
        vm.prank(ownerAddr);

        vm.expectEmit(true, false, false, false);
        emit TolarenceValueUpdated(newTolarence);
        decom.setToleranceValue(newTolarence);

        assertEq(decom.tolerance_value(), newTolarence, "Incorrect tolarence value");
    }

    function testSetPriceFeedContract_Emit() public {
        // Deploy a new mock oracle.
        MockAggregratorV3Interface newMockOracle = new MockAggregratorV3Interface();

        // Act as the contract owner and update the price feed contract.
        vm.prank(ownerAddr);

        vm.expectEmit(true, false, false, false);
        emit PriceFeedV3Updated(address(newMockOracle));
        decom.setPriceFeedContract(address(newMockOracle));
    }

    function testSetPublicKey_Fail_onlyOwner() public {
        // Ownable contract is from openzeppelin
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer1
            )
        );
        
        vm.prank(buyer1);
        decom.setPublicKey(PUBLICKEY);
    }

    function testSetPublicKey() public {
        vm.prank(ownerAddr);
        
        vm.expectEmit(true, false, false, false);
        emit PublicKeyUpdated(PUBLICKEY);
        decom.setPublicKey(PUBLICKEY);

        assertEq(decom.publicKey(), PUBLICKEY, "Incorrect public key");
    }
    
    function testSetPrice_Fail_onlyOwner() public {
        // Ownable contract is from openzeppelin
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer1
            )
        );
        vm.prank(buyer1);
        decom.setStock(300);
    }

    function testSetPause_Fail_onlyOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer1
            )
        );
        vm.prank(buyer1);
        decom.setPause(true);
    }

    function testSetPause() public {
        vm.prank(ownerAddr);
        decom.setPause(true);

        assertEq(decom.paused(), true);
    }

    function testSetShippingCost() public {
        uint8 newShippingCost = 15;
        vm.prank(ownerAddr);

        vm.expectEmit(true, false, false, false);
        emit ShippingCostUpdated(newShippingCost);
        decom.setShippingCost(newShippingCost);

        assertEq(
            decom.shippingCost(),
            newShippingCost,
            "Incorrect shipping cost"
        );
    }

    function testShippingCost_Fail_onlyOwner() public {
        // Ownable contract is from openzeppelin
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer1
            )
        );
        vm.prank(buyer1);
        decom.setShippingCost(300);
    }

    function testPriceFeedV3_amountToWei() public view {
        uint256 expectedWeiValue1 = 10937500000000000;
        uint256 expectedWeiValue2 = 3437500000000000;

        assertEq(expectedWeiValue1, priceFeed.amountToWei(35));
        assertEq(expectedWeiValue2, priceFeed.amountToWei(11));
    }

    function testPurchase() public {
        orderQty = 1;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);

        // event ShippingCostUpdated test.
        vm.expectEmit(true, true, true, true);
        emit PurchaseOrder(
            0,
            buyer1,
            orderQty,
            purchaseAmount,
            "randomAddress"
        );
        decom.purchase{value: totalPrice}(orderQty, "randomAddress");

        DeCom.Order memory order = decom.getOrderDetails(decom.orderNo() - 1);

        assertEq(
            order.shippingAddr,
            "randomAddress",
            "Incorrect shipping address"
        );
        assertEq(order.quantity, orderQty, "Incorrect order quantity");
        assertEq(order.amount, purchaseAmount, "Incorrect order amount");
        assertEq(order.buyerAddr, buyer1, "Incorrect buyer address");
        assertEq(
            order.shippingAddr,
            "randomAddress",
            "Incorrect shipping address"
        );
        assertEq(
            uint256(order.status),
            uint256(Status.pending),
            "Incorrect order status"
        );
        assertEq(decom.payments(buyer1), purchaseAmount, "Incorrect payment");

        uint32[] memory getOrders = decom.getOrder(buyer1);
        assertEq(getOrders.length, 1, "Incorrect order length");

        assertEq(
            decom.totalPayment(),
            purchaseAmount,
            "Incorrect total payment"
        );
        assertEq(decom.totalStock(), STOCK - orderQty, "Incorrect total stock");
        assertEq(decom.orderNo(), 1, "Incorret order No");

        //Mint NFT test
        assertEq(decom.balanceOf(buyer1), 1, "Incorrect NFT buyer balance");
        assertEq(decom.ownerOf(0), buyer1, "Incorrect NFT address");
    }

    function testPurchase_Tolerance() public {
        orderQty = 1;
        // Get the purchase amount in Wei.
        
        uint256 getTotalCost = decom.totalCost(orderQty);

        // adjust 0.9 percentage tolerance
        uint256 adjustTolerance = (getTotalCost * 9) / 1000;

        purchaseAmount = getTotalCost - adjustTolerance;

        vm.prank(buyer1);

        // event ShippingCostUpdated test.
        vm.expectEmit(true, true, true, true);
        emit PurchaseOrder(
            0,
            buyer1,
            orderQty,
            purchaseAmount,
            "randomAddress"
        );
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        DeCom.Order memory order = decom.getOrderDetails(decom.orderNo() - 1);
        
        assertEq(
            order.shippingAddr,
            "randomAddress",
            "Incorrect shipping address"
        );
        assertEq(order.quantity, orderQty, "Incorrect order quantity");
        assertEq(order.amount, purchaseAmount, "Incorrect order amount");
        assertEq(order.buyerAddr, buyer1, "Incorrect buyer address");
        assertEq(
            order.shippingAddr,
            "randomAddress",
            "Incorrect shipping address"
        );
        assertEq(
            uint256(order.status),
            uint256(Status.pending),
            "Incorrect order status"
        );
        assertEq(decom.payments(buyer1), purchaseAmount, "Incorrect payment");

        uint32[] memory getOrders = decom.getOrder(buyer1);
        assertEq(getOrders.length, 1, "Incorrect order length");

        assertEq(
            decom.totalPayment(),
            purchaseAmount,
            "Incorrect total payment"
        );
        assertEq(decom.totalStock(), STOCK - orderQty, "Incorrect total stock");
        assertEq(decom.orderNo(), 1, "Incorret order No");

        //Mint NFT test
        assertEq(decom.balanceOf(buyer1), 1, "Incorrect NFT buyer balance");
        assertEq(decom.ownerOf(0), buyer1, "Incorrect NFT address");
    }

    function testPurchase_Tolerance_InValidAmount() public {
        orderQty = 1;
        // Get the purchase amount in Wei.
        
        uint256 getTotalCost = decom.totalCost(orderQty);

        // adjust 0.9 percentage tolerance
        uint256 adjustTolerance = (getTotalCost * 9) / 100;

        purchaseAmount = getTotalCost - adjustTolerance;

        vm.expectRevert(
            abi.encodeWithSelector(IError.InValidAmount.selector, purchaseAmount)
        );
        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");
    }

    function testPurchase_InValidQuantity() public {
        uint16 orderStock = 301;
        vm.expectRevert(
            abi.encodeWithSelector(IError.InValidQuantity.selector, orderStock)
        );
        vm.prank(buyer1);
        decom.purchase(orderStock, "randomAddress");
    }

    function testPurchase_Return_Change() public {
          // Get the purchase amount in Wei.
        orderQty = 1;

        uint256 getTotalCost = decom.totalCost(orderQty);

        uint256 overCost = 1e9 wei;

        uint256 buyer1BalanceBefore = address(buyer1).balance;

        purchaseAmount = getTotalCost + overCost;

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress"); 

        uint256 expectedBuyer1Balance = buyer1BalanceBefore - getTotalCost;

        // Buyer1 balance after refund.
        assertEq(address(buyer1).balance, expectedBuyer1Balance);
    }

    function testPurchase_InvalidAmount() public {
        uint8 orderPrice = 1 wei;
        vm.expectRevert(
            abi.encodeWithSelector(IError.InValidAmount.selector, orderPrice)
        );

        decom.purchase{value: orderPrice}(2, "randomAddress");
    }

    function testPurchase_ContractPaused() public {
        vm.prank(ownerAddr);
        decom.setPause(true);

        orderQty = 1;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.expectRevert(
            abi.encodeWithSelector(IError.ContractPaused.selector)
        );
        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");
    }

    function testProcessShipment() public {
        orderQty = 199;

        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        // Process shipment after receiving the order.
        vm.prank(ownerAddr);

        vm.expectEmit(true, true, false, false);
        emit OrderShipped(0, buyer1);
        decom.processShipment(0);

        // Check order status.
        DeCom.Order memory order = decom.getOrderDetails(0);
        assertEq(
            uint256(order.status),
            uint256(Status.shipped),
            "Invalid order status"
        );

        assertEq(
            decom.amountAfterShipping(),
            purchaseAmount,
            "Invalid amount after shipping"
        );

        assertEq(decom.payments(buyer1), 0, "Invalid buyer payments");
    }

    function testProcessShipmentFail_AlreadyShipped() public {
        orderQty = 52;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        vm.prank(ownerAddr);
        decom.processShipment(0);

        vm.expectRevert(
            abi.encodeWithSelector(IError.AlreadyShipped.selector, 0)
        );
        vm.prank(ownerAddr);
        decom.processShipment(0);
    }

    function testProcessShipmentFail_NotAuthorized() public {
        orderQty = 63;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        vm.expectRevert(
            abi.encodeWithSelector(
                IError.NotAuthorized.selector,
                buyer1
            )
        );
        vm.prank(buyer1);
        decom.processShipment(0);
    }

    function testWithdraw() public {
        orderQty = 163;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer2);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        vm.prank(ownerAddr);
        decom.processShipment(0);

        vm.prank(ownerAddr);

        vm.expectEmit(true, true, false, false);
        emit Withdraw(purchaseAmount, ownerAddr);
        decom.withdraw();

        assertEq(decom.amountAfterShipping(), 0);
    }

    function testWithdraw_OnlyOwner() public {
        address mockOwner = address(4);

        vm.prank(buyer2);
        decom.purchase{value: totalPrice}(1, "randomAddress");

        vm.prank(ownerAddr);
        decom.processShipment(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                mockOwner
            )
        );
        vm.prank(mockOwner);
        decom.withdraw();
    }

    function testWithdraw_WithdrawAmountUnavailable() public {
        vm.prank(address(2));
        decom.purchase{value: totalPrice}(1, "randomAddress");

        vm.expectRevert(
            abi.encodeWithSelector(IError.WithdrawAmountUnavailable.selector, 0)
        );
        vm.prank(ownerAddr);
        decom.withdraw();

        assertEq(decom.amountAfterShipping(), 0);
    }

    function testSetCancelAndRefund() public {
        orderQty = 206;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.prank(ownerAddr);
        decom.setCancelAndRefund(orderNo);

        // vm.expectEmit(true, true, false, false);
        // emit OrderCancelled(orderNo, buyer1);

        DeCom.Order memory order = decom.getOrderDetails(0);

        assertEq(
            uint256(order.status),
            uint256(Status.cancelled),
            "InValid Status"
        );

        // If order is cancelled, the ordered stock should again
        // add back to total stock available for sale.
        assertEq(decom.totalStock(), STOCK, "InValid Stock");
    }

    function testSetCancelAndRefundFail_AlreadyCancelled() public {
        orderQty = 103;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.prank(ownerAddr);
        decom.setCancelAndRefund(orderNo);

        vm.expectRevert(
            abi.encodeWithSelector(IError.AlreadyCancelled.selector, orderNo)
        );
        vm.prank(ownerAddr);
        decom.setCancelAndRefund(orderNo);
    }

    function testSetCancelAndRefundFail_AlreadyShipped() public {
        orderQty = 111;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.prank(ownerAddr);
        decom.processShipment(orderNo);

        vm.expectRevert(
            abi.encodeWithSelector(IError.AlreadyShipped.selector, orderNo)
        );
        vm.prank(ownerAddr);
        decom.setCancelAndRefund(orderNo);
    }

    function testSetCancelAndRefund_Loop() public {
        orderQty = 112;
        purchaseAmount = decom.totalCost(orderQty);
        vm.prank(buyer2);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        orderQty = 1;
        purchaseAmount = decom.totalCost(orderQty);
        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        orderQty = 99;
        purchaseAmount = decom.totalCost(orderQty);
        vm.prank(buyer3);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32[] memory orders = new uint32[](3);
        orders[0] = 0;
        orders[1] = 1;
        orders[2] = 2;

        for (uint8 i = 0; i < 3; i++) {
            vm.prank(ownerAddr);
            decom.setCancelAndRefund(i);
            DeCom.Order memory order = decom.getOrderDetails(i);
            assertEq(uint256(order.status), uint256(Status.cancelled));
        }
        // If order is cancelled, the ordered stock should again
        // add back to total stock available for sale.
        assertEq(decom.totalStock(), STOCK, "InValid Stock");
    }

    function testeditOrderCancelToPending() public {
        orderQty = 206;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.startPrank(ownerAddr);
        decom.setCancelAndRefund(orderNo);
        decom.editOrderCancelToPending(orderNo);
        vm.stopPrank();

        DeCom.Order memory order = decom.getOrderDetails(0);
        assertEq(uint256(order.status), uint256(Status.pending));
    }

    function testeditOrderCancelToPending_NotAuthorized() public {
        orderQty = 206;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.prank(ownerAddr);
        decom.setCancelAndRefund(orderNo);
        
        vm.expectRevert(
            abi.encodeWithSelector(IError.NotAuthorized.selector, buyer1)
        );
        vm.prank(buyer1);
        decom.editOrderCancelToPending(orderNo);
    }

    function testeditOrderCancelToPending_InValidStatus() public {
        orderQty = 206;
        // Get the purchase amount in Wei.
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.expectRevert(
            abi.encodeWithSelector(IError.InValidStatus.selector, orderNo)
        );
        vm.prank(ownerAddr);
        decom.editOrderCancelToPending(orderNo);
    }

    function testCollectRefund() public {
        orderQty = 112;
        purchaseAmount = decom.totalCost(orderQty);
        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.prank(ownerAddr);
        decom.setCancelAndRefund(orderNo);

        vm.prank(buyer1);

        vm.expectEmit(true, true, true, false);
        emit RefundCollected(orderNo, buyer1, purchaseAmount);
        decom.collectRefund(orderNo);

        DeCom.Order memory order = decom.getOrderDetails(orderNo);

        assertEq(decom.payments(buyer1), 0);
        assertEq(order.amount, 0);
        assertEq(decom.totalPayment(), 0);
        assertEq(uint256(order.status), uint256(Status.refund));
    }

    function testCollectRefund_invalidCollector() public {
        orderQty = 213;
        purchaseAmount = decom.totalCost(orderQty);
        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.prank(ownerAddr);
        decom.setCancelAndRefund(orderNo);

        vm.expectRevert(
            abi.encodeWithSelector(IError.InValidCollector.selector, buyer3)
        );
        vm.prank(buyer3);
        decom.collectRefund(orderNo);
    }

    function testCollectRefund_AlreadyShipped() public {
        orderQty = 100;
        purchaseAmount = decom.totalCost(orderQty);
        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.prank(ownerAddr);
        decom.processShipment(orderNo);

        vm.expectRevert(
            abi.encodeWithSelector(IError.AlreadyShipped.selector, orderNo)
        );
        vm.prank(buyer1);
        decom.collectRefund(orderNo);
    }

    function testCollectRefund_OrderedNotCancelled() public {
        orderQty = 114;
        purchaseAmount = decom.totalCost(orderQty);
        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        uint32 orderNo = decom.buyersOrder(buyer1, 0);

        vm.expectRevert(
            abi.encodeWithSelector(IError.OrderNotCancelled.selector, orderNo)
        );
        vm.prank(buyer1);
        decom.collectRefund(orderNo);
    }

    function testCollectRefund_ContractPaused() public {
        orderQty = 114;
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(ownerAddr);
        decom.setPause(true);
       
        vm.expectRevert(
            abi.encodeWithSelector(IError.ContractPaused.selector)
        );
        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");
    }

    function testEmergencyWithdraw() public {
        orderQty = 11;
        purchaseAmount = decom.totalCost(orderQty);

        vm.prank(buyer1);
        decom.purchase{value: purchaseAmount}(orderQty, "randomAddress");

        assertEq(decom.payments(buyer1), purchaseAmount);

        vm.prank(ownerAddr);
        decom.setPause(true);

        vm.prank(buyer1);
        decom.emergency_withdraw();
        
        assertEq(decom.payments(buyer1), 0);
    }
}
