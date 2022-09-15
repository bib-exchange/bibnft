// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTAuction {

    struct Auction {
        address token;
        uint256 tokenId;
        address payable seller;
        PayMethod payMethod;
        address payable bidder;
        uint256 price;
        bool finished;
        uint256 expiration;
    }

    enum PayMethod {
        PAY_BNB,
        PAY_BUSD,
        PAY_BIB
    }

    event CreateAuction(uint256 auctionId, address seller, address token, uint256 tokenId, PayMethod payMethod, uint256 minPrice, uint256 expiration);
    event Bid(uint256 auctionId, address bidder, uint256 price);
    event FinishAuction(uint256 auctionId, address operator);
    event CancelAuction(uint256 auctionId, address operator);

    function setRoyaltyRatio(uint feeRatio) external;

    function setFeeRatio(uint feeRatio) external;
    function createAuction(address token, uint256 tokenId, PayMethod payMethod, uint256 minPrice, uint256 expiration) external;
    function bid(uint256 auctionId, uint256 price) external payable;

    function finishAuction(uint256 auctionId) external;

    function cancelAuction(uint256 auctionId) external;
}
