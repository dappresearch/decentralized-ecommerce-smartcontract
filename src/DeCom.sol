// SPDX-License-Identifier: No License
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "forge-std/console.sol";

import "./PriceFeedV3.sol";
import "./IError.sol";
import "./IDeCom.sol";
import "./ItemNFT.sol";

contract DeCom is IDeCom, IError, ItemNFT, ReentrancyGuard {

    // Defualt set value. Can be set using `setToleranceValue`.
    uint8 public tolerance_value = 1;
    
    uint32 public totalStock;
    
    // Track number of orders.
    uint32 public orderNo;

    uint16 public shippingCost;

    uint16 public price;

    uint256 public totalPayment;

    uint256 public totalWithdraw;

    // Revenue generted after fulfilling shipping.
    uint256 public amountAfterShipping;

    string public publicKey;

    // Chainlink price oracle.
    PriceFeedV3 public priceFeed;

    bool public paused = false;

    // Store the buyers order
    mapping(address => uint32[]) public buyersOrder;

    // Store the order details with respective order number.
    mapping(uint32 => Order) public orders;

    // Record the buyer purchase payments.
    mapping(address => uint256) public payments;

    // Admins can process orders.
    mapping(address => bool) public admins;

    constructor(
        address owner, 
        address chainLinkOracle, 
        uint16 _price,
        uint16 _shippingCost, 
        uint32 _totalStock,
        string memory _publicKey,
        string memory nftLink
        )
        Ownable(owner)
        ItemNFT(nftLink)
    {
        if(_price == 0) revert InValidPrice(0);

        if(_totalStock == 0) revert InValidQuantity(0);

        priceFeed = new PriceFeedV3(chainLinkOracle);
        price = _price;
        shippingCost = _shippingCost;
        totalStock = _totalStock;
        publicKey = _publicKey;

        admins[owner] = true;
    }

    modifier isAdmin() {
        if(!admins[msg.sender] ) revert NotAuthorized(msg.sender);
        _;
    }

    modifier isPaused() {
        if(paused) revert ContractPaused();
        _;
    }

    /**
     * @notice Add or remove admin. They can process orders.
     * @param _admin Admin address.
     * @param _status Status of the admin.
     */
    function setAdmin(address _admin, bool _status) external onlyOwner {
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    /**
     * @notice Sets the total stock available for sale.
     * @param newTotalStock Available stock for sale.
     */
    function setStock(uint32 newTotalStock) external onlyOwner {
        totalStock = newTotalStock;
        emit StockUpdated(newTotalStock);
    }

    /**
     * @notice Sets the price of the item.
     * @dev This price will be later converted to Wei using latest ETH/USD Chainlink oracle.
     * @param newPrice Price of the item.
     */
    function setPrice(uint16 newPrice) external onlyOwner() {
        price = newPrice;
        emit PriceUpdated(newPrice);
    }

    /**
     * @notice Pause the contract in case of bugs. Everying will be disabled execept   
     * `emergency_withdraw` function.
     * @param _paused Pause the contract.
     */
    function setPause(bool _paused) external onlyOwner() {
        paused = _paused;
    }

    /**
     * @notice Set the price of the shipping cost.
     * @dev Shipping cost will be later converted to Wei using latest ETH/USD Chainlink oracle.
     * @param newShippingCost Current shipping cost.
     */
    function setShippingCost(uint16 newShippingCost) external onlyOwner {
        shippingCost = newShippingCost;
        emit ShippingCostUpdated(newShippingCost);
    }

    /**
    * @notice Set the seller ublic key for the encryption.
    * @param _publicKey Seller public key for the encrypting buyers address.
    */
    function setPublicKey(string calldata _publicKey) external onlyOwner {
        publicKey = _publicKey;
        emit PublicKeyUpdated(publicKey);
    }
    
    /**
     * @notice Set the new chainlink oracle address.
     * @param newPriceFeed new chainlink oracle address.
     */
    function setPriceFeedContract(address newPriceFeed) external onlyOwner {
        priceFeed = new PriceFeedV3(newPriceFeed);
        emit PriceFeedV3Updated(newPriceFeed);
    }

    /**
     * @notice Set the tolerance value.
     * @param _tolerance_value new tolerance value.
     */
    function setToleranceValue(uint8 _tolerance_value) external onlyOwner {
        if(_tolerance_value == 0) revert InValidAmount(_tolerance_value);
        tolerance_value = _tolerance_value;
        emit TolarenceValueUpdated(_tolerance_value);
    }

    /**
    * @notice Returns the total cost including shipping for the given quantity.
    * @dev Item price and shipping cost is converted to Wei using chainlink ETH/USD price feed.
    *      While calculating amountToWei, there is some percision loss, could be improved.
    * @param quantity The number of items to be shipped.
    * @return The total cost including the price of items and shipping cost.
    */
    function totalCost(uint32 quantity) public view returns (uint256) {
        // Convert item price into current ETH/USD market price in wei.
        uint256 priceInWei = priceFeed.amountToWei(price * quantity);

        // Convert shipping cost into current ETH/USD market price in wei.
        uint256 shippingCostInWei = priceFeed.amountToWei(shippingCost);

        // Total cost in wei.
        return (priceInWei + shippingCostInWei);
    }

    /**
    * @notice Chainlink Arbitrum ETH/USD price feed keeps adusting when the price deviates from 
    * the given threshold value of 0.5 percent. So inorder to make sure contract doesn't revert
    * seller needs to consider some bottom tolerance value. If the total cost is $100 than 
    * with 1 percent bottom tolerance the total cost will be $99. But anything above $100 will be
    * given a change back to the buyer.
    * @dev adujust `tolerance_value` accordingly.
    * @param quantity The number of items to be shipped.
    */
    function _totalCostWithTolerance(uint32 quantity) private view returns (uint256,uint256) {
        uint256 totalCostInWei = totalCost(quantity);
        uint256 tolerance = (totalCostInWei * tolerance_value) / 100; // 1% tolerance
        return (totalCostInWei - tolerance, totalCostInWei);
    }

    /**
    * @notice Purchase the given product.
    * @dev Buyer address must be encrypted.
    * @param quantity Number of product item to be purchased.
    * @param destination Encrypted destination address of the buyer.
    */
    function purchase(
        uint32 quantity,
        string calldata destination
    ) external payable nonReentrant isPaused {
        if (quantity == 0 || quantity > totalStock)
            revert InValidQuantity(quantity);

        (uint256 minCost, uint256 totalPurchaseCost) = _totalCostWithTolerance(quantity);

        // Purchase value should be greater than minCost.
        if(msg.value < minCost) revert InValidAmount(msg.value);
        
        uint256 change;

        uint256 amount;

        if(msg.value > totalPurchaseCost) {
            change = msg.value - totalPurchaseCost;
            amount = totalPurchaseCost;
        } else{
            amount = msg.value;
        }

        Order storage order = orders[orderNo];
        order.shippingAddr = destination;
        order.quantity = quantity;
        order.amount = amount;
        order.purchaseDate = block.timestamp;
        order.buyerAddr = msg.sender;
        order.status = Status.pending;
        
        // Buyer can have multiple orders.
        buyersOrder[msg.sender].push(orderNo);

        unchecked {
            // Record the payment sent by the buyers.
            payments[msg.sender] += amount;

           // Overflow not possible, totalStock > quantity, already checked.
            totalStock -= quantity;

            totalPayment += msg.value;
            orderNo++;
        }

        // Return the change.
        if (change > 0) {
            (bool success, ) = msg.sender.call{value: change}("");
            if (!success) revert TransferFailed(msg.sender, change);
        }

         // Mint NFT
        _mintItemNFT(msg.sender);

        emit PurchaseOrder(orderNo - 1, msg.sender, quantity, msg.value, destination);
    }

    /** 
    * @notice Update shipping status.
    * @param _orderNo Order number of the given buyer.
    */
    function processShipment(uint32 _orderNo) external isAdmin {
        Order storage order = orders[_orderNo];

        // Order should not be shipped.
        if (order.status == Status.shipped) revert AlreadyShipped(_orderNo);

        if (order.status == Status.cancelled) revert AlreadyCancelled(_orderNo);

        if (order.status == Status.refund) revert AlreadyRefund(_orderNo);

        address currentBuyer = order.buyerAddr;

        // Buyer should have sufficient balance in the contract.
        if(payments[currentBuyer] < order.amount) revert InsufficientBuyerPayment(_orderNo);

        // payment[order.abuyerAddr] < order.amount, already checked, underflow not possible.
        unchecked {
            amountAfterShipping += order.amount;
            payments[currentBuyer] -= order.amount;
        }

        order.status = Status.shipped;
        emit OrderShipped(_orderNo, order.buyerAddr);
    }

    /**
    * @notice Able to withdraw contract balance by the owner.
    * @dev Owner can only withdraw if shipping order has been fulfilled.
    */
    function withdraw() external onlyOwner {
        uint256 withdrawAmount = amountAfterShipping;

        if (amountAfterShipping == 0 || 
            address(this).balance < withdrawAmount
        ) revert WithdrawAmountUnavailable(0);

        unchecked {
            totalWithdraw += amountAfterShipping;
            amountAfterShipping = 0;
        }
        
        (bool success, ) = owner().call{value: withdrawAmount}("");
         if (!success) revert TransferFailed(msg.sender, withdrawAmount); 

        emit Withdraw(withdrawAmount, owner());
    }
    
    /**
     * @notice Change order status by the owner, incase of mistake.
     * @dev Need to subract totalStock, since cancellation will add the totalStock.
     */
    function editOrderCancelToPending(uint32 _orderNo) external isAdmin {
        Order storage order = orders[_orderNo];
        /**  
            Order has been cancelled.
            Change back to pending
            it's need to add total stock back
        */
        if(order.status != Status.cancelled) revert InValidStatus(_orderNo);

        order.status = Status.pending;

        // Add the order back to stock.
        unchecked {
                totalStock -= order.quantity;
            }

        emit PurchaseOrder(orderNo, msg.sender, order.quantity, order.amount, order.shippingAddr);
    }

    /**
    * @dev Internal function to check if order is shipped and buyer has sufficient balance.
    * @param order Struct Order.
    * @param _orderNo Order number of the buyer.
    */
    function _checkShippedAndBuyerPayment(Order memory order, uint32 _orderNo) internal view {
        if (order.status == Status.shipped) revert AlreadyShipped(_orderNo); 

        if(order.status == Status.refund) revert AlreadyRefund(_orderNo);

        if (order.amount == 0 || payments[order.buyerAddr] < order.amount)
            revert InsufficientBuyerPayment(_orderNo);
    }

    /**
    * @notice Private function to update the status of an order.
    * @dev For order.status == Status.none, it will still revert to
    *  `InsufficientBuyerPayment`.
    * @param _orderNo Order number of the buyer.
    */
    function _updateOrderStatus(uint32 _orderNo) private {
        Order storage order = orders[_orderNo];

        _checkShippedAndBuyerPayment(order, _orderNo);

        if (order.status == Status.cancelled) revert AlreadyCancelled(_orderNo);

        order.status = Status.cancelled;
        
        // Cancelled orders should put back to available stock.
        unchecked {
            totalStock += order.quantity;
        }

        emit OrderCancelled(_orderNo, order.buyerAddr);
    }
    
    /**
    * @notice Refund money to the buyer.
    * @param _orderNo Order number of the buyer.
    */
    function setCancelAndRefund(uint32 _orderNo) external isAdmin {
        _updateOrderStatus(_orderNo);
    }

    /**
    * @notice Refund money to the multiple buyers.
    * @param _orderNo Array of Order Number of the buyers.
    */
    function setCancelAndRefund(
        uint32[20] calldata _orderNo
    ) external isAdmin {
        for (uint8 i = 0; i < _orderNo.length; i++) {
            _updateOrderStatus(_orderNo[i]);
        }
    }

    /**
    * @notice Collect refund buy the buyer.
    * @param _orderNo Order Number of the buyer.
    */
    function collectRefund(uint32 _orderNo) external nonReentrant isPaused {
        Order storage order = orders[_orderNo];

        _checkShippedAndBuyerPayment(order, _orderNo);

        if(msg.sender != order.buyerAddr) revert InValidCollector(msg.sender);

        if(order.status != Status.cancelled) revert OrderNotCancelled(_orderNo);

        uint256 refundAmount = order.amount;
        
        unchecked {
            // Underflow not possible, payments[order.buyerAddr] < order.amount already checked.
            payments[msg.sender] -= refundAmount;
            
            // Underflow not possible, order.amount is always less that totalPayment.
            totalPayment -= refundAmount;
        }

        order.amount = 0;
        order.status = Status.refund;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
    
        if (!success) revert TransferFailed(msg.sender, refundAmount); // Handle failure explicitly

        emit RefundCollected(_orderNo, msg.sender, refundAmount);
    }

    /**
    * @notice Buyer will be able to withdraw incase contract has bugs or hacked.
    * @dev `paused` needs to be set to true;
    */
    function emergency_withdraw() external nonReentrant {
        if(!paused) revert ContractNotPaused();

        uint256 withdrawAmount = payments[msg.sender];

        if (withdrawAmount < 0) revert InsufficientBuyerPayment(0);

        payments[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: withdrawAmount}("");

        if (!success) revert TransferFailed(msg.sender, withdrawAmount); // Handle failure explicitly

        emit Withdraw(withdrawAmount, msg.sender);
    }

    /**
    * @notice Retreive order number of the buyer.
    * @param buyer Buyer address.
    */
    function getOrder(address buyer) external view returns (uint32[] memory) {
        return buyersOrder[buyer];
    }

    /**
    * @notice Retreive order details.
    * @param _orderNo Order Number of the buyer.
    */
    function getOrderDetails(uint32 _orderNo) external view returns (Order memory) {
        Order memory order = orders[_orderNo];
        return order;
    }

    // get buyers order length
    function getBuyersOrderLength(address buyer) external view returns (uint256) {
        return buyersOrder[buyer].length;
    }   
}

