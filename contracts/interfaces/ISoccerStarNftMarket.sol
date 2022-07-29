// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface ISoccerStarNftMarket {

    struct Offer {
        uint offerId;
        address buyer;
        uint bid;
        uint timeStamp;
    }

    struct Order {
        uint orderId;
        uint tokenId;
        address owner;
        PayMethod payMethod;
        uint price;
        uint timeStamp;
    }

    enum PayMethod {
        PAY_BNB,
        PAY_BUSD,
        PAY_BIB
    }

    event OpenOrder(address sender, uint orderId, uint tokenId, PayMethod payMethod, uint price);

    event AcceptOffer(
        address sender, 
        address maker,
        address taker,
        uint fee,
        uint orderId,
        uint offerId,
        PayMethod payMethod, 
        uint price
    );

    event UpdateOrderPrice(address sender, uint oldPrice, uint newPrice);
    event UpdateOfferPrice(address sender, uint oldPrice, uint newPrice);

    event CloseOrder(address sender, uint orderId);
    event CancelOffer(address sender, uint offerId);

    event MakeOffer(address buyer, address owner, uint orderId, uint offerId, uint price);

    // user create a order
    function openOrder(uint tokenId, PayMethod payMethod, uint price) payable external;

    // get user orders by page
    function getUserOrdersByPage(address user, uint pageSt, uint pageSz) 
    external view returns(Order[] memory);

    // get orders by page
    function getOrdersByPage(uint pageSt, uint pageSz) 
    external view returns(Order[] memory);

    // Buyer accept the price and makes a deal with the sepcific order
    function acceptOffer(uint orderId) external payable;

    // Owner accept the offer and make a deal
    function acceptOffer(uint orderId, uint offerId) external payable;
    
    // Owner updates order price
    function updateOrderPrice(uint orderId, uint price) external payable;

    // Owner close the specific order if not dealed
    function closeOrder(uint orderId) external;

    // Buyer make a offer to the specific order
    function makeOffer(uint orderId, uint price) external payable;

    // Buyer udpate offer bid price
    function updateOffer(uint orderId, uint offerId, uint price) external payable;

    // Buyer cancle the specific order
    function cancelOffer(uint orderId, uint offerId) external;

     // get offer of the specific order by page
    function getOrderOffersByPage(uint orderId, uint pageSt, uint pageSz) 
    external view returns(Offer[] memory);



}