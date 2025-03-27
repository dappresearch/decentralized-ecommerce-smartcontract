// SPDX-License-Identifier: No License
pragma solidity ^0.8.20;

// import "./Container.sol";

interface IDeCom {
     event StockUpdated(uint32 indexed newTotalStock);
     event PriceUpdated(uint256 indexed newPrice);
     event ShippingCostUpdated(uint256 indexed newShippingCost);
     event PurchaseOrder(uint32 indexed orderNo, address indexed buyer, uint32 indexed quantity, uint256 amount, string destination);
     event OrderShipped(uint32 indexed orderNo, address indexed buyer);
     event Withdraw(uint256 indexed amount, address indexed owner);
     event OrderCancelled(uint32 indexed orderNo, address indexed buyer);
     event RefundCollected(uint32 indexed orderNo, address indexed buyer, uint256 indexed amount);
     event PublicKeyUpdated(string indexed publicKey);
     event PriceFeedV3Updated(address indexed priceFeed);
     event AdminUpdated(address indexed newAdmin, bool indexed isAdmin);
     event TolarenceValueUpdated(uint8 indexed newToleranceValue);

     function setStock(uint32 newTotalStock) external;
     function setPrice(uint16 newPrice) external;
     function setShippingCost(uint16 newShippingCost) external;
     function setPublicKey(string memory _publicKey) external;
     function setToleranceValue(uint8 _tolerance_value) external;
     function setPriceFeedContract(address newPriceFeed) external;
     function setAdmin(address newAdmin, bool isAdmin) external;
     function totalCost(uint32 quantity) external view returns (uint256);
     function purchase(uint32 quantity, string memory destination) external payable;
     function processShipment(uint32 _orderNo) external;
     function withdraw() external;
     function setCancelAndRefund(uint32 _orderNo) external;
     function setCancelAndRefund(uint32[20] calldata _orderNo) external;
     function collectRefund(uint32 _orderNo) external;
     function getOrder(address buyer) external view returns (uint32[] memory);
     function getOrderDetails(uint32 _orderNo) external view returns(Order memory);
     function orderNo() external view returns (uint32);
     function shippingCost() external view returns (uint16);
     function price() external view returns (uint16);
     function totalStock() external view returns (uint32);
     function totalPayment() external view returns (uint256);
     function totalWithdraw() external view returns (uint256);
     function amountAfterShipping() external view returns( uint256);
     function getBuyersOrderLength(address buyer) external view returns(uint256);
     
     enum Status {
          none,
          pending,
          shipped,
          cancelled,
          refund
     }

     struct Order {
          string shippingAddr;
          uint32 quantity;
          uint256 amount;
          uint256 purchaseDate;
          address buyerAddr;
          Status status;
     }
}
