//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {SafeMath} from "../libs/SafeMath.sol";
import {SafeCast} from "../libs/SafeCast.sol";
import {ISoccerStarNft} from "../interfaces/ISoccerStarNft.sol";
import {ISoccerStarNftMarket} from "../interfaces/ISoccerStarNftMarket.sol";
import {IBIBOracle} from "../interfaces/IBIBOracle.sol";

contract SoccerStarNftMarket is ISoccerStarNftMarket, Ownable{
    using SafeMath for uint;

    IERC20 public bibContract;
    IERC20 public busdContract;
    ISoccerStarNft public tokenContract;

    event TokenContractChanged(address sender, address oldValue, address newValue);
    event BIBContractChanged(address sender, address oldValue, address newValue);
    event BUSDContractChanged(address sender, address oldValue, address newValue);
    event FeeRatioChanged(address sender, uint oldValue, uint newValue);

    uint public nextOrderIndex;
    uint public nextOfferIndex;

    uint public feeRatio;
    uint public constant FEE_RATIO_DIV = 1000;

    // orders in the market
    uint[] public orders;
    // fast index from order id to order
    mapping(uint=>Order) public orderTb;
    // orders belong to the specfic owner
    mapping(address=>uint[]) public userOrderTb;
    //  offers of the order
    mapping(uint=>uint[]) public orderOfferTb;
    // fast index from offer id to offer
    mapping(uint=>Offer) public offerTb;

    constructor(
    address _tokenContract,
    address _bibContract,
    address _busdContract
    ){
        tokenContract = ISoccerStarNft(_tokenContract);
        bibContract = IERC20(_bibContract);
        busdContract = IERC20(_busdContract);
    }

    function setTokenContract(address _tokenContract) public onlyOwner{
        require(address(0) != _tokenContract, "INVALID_ADDRESS");
        emit TokenContractChanged(msg.sender, address(tokenContract), _tokenContract);
        tokenContract = ISoccerStarNft(_tokenContract);
    }

    function setBIBContract(address _bibContract) public onlyOwner{
        require(address(0) != _bibContract, "INVALID_ADDRESS");
        emit BIBContractChanged(msg.sender, address(bibContract), _bibContract);
        bibContract = IERC20(_bibContract);
    }

    function setBUSDContract(address _busdContract) public onlyOwner{
        require(address(0) != _busdContract, "INVALID_ADDRESS");
        emit BUSDContractChanged(msg.sender, address(busdContract), _busdContract);
        busdContract = IERC20(_busdContract);
    }

    function setFeeRatio(uint _feeRatio) public onlyOwner{
        require(_feeRatio <= FEE_RATIO_DIV, "INVALID_RATIO");
        emit FeeRatioChanged(msg.sender,feeRatio, _feeRatio);
        feeRatio = _feeRatio;
    }


    // user create a order
    function openOrder(uint tokenId, PayMethod payMethod, uint price) public override payable{
        require(price > 0, "PRICE_NOT_BE_ZEROR");
        require(msg.sender == IERC721(address(tokenContract)).ownerOf(tokenId), 
        "TOKEN_NOT_BELLOW_TO_SENDER");
   
        // delegate token to protocol
        IERC721(address(tokenContract)).transferFrom(msg.sender, address(this), tokenId);

        // record order
        Order memory order = Order({
            orderId: nextOrderIndex++,
            tokenId: tokenId,
            owner: msg.sender,
            payMethod: payMethod,
            price: price,
            timeStamp: block.timestamp
        });

        orders.push(order.orderId);
        userOrderTb[msg.sender].push(order.orderId);
        orderTb[order.orderId] = order;

        emit OpenOrder(msg.sender,order.orderId, tokenId, payMethod, price);
    }

    // get orders by page
    function getUserOrdersByPage(address user, uint pageSt, uint pageSz) 
    public view override returns(Order[] memory){
        uint[] storage _orders= userOrderTb[user];
        Order[] memory ret;

        if(pageSt < _orders.length){
            uint end = pageSt + pageSz;
            end = end > _orders.length ? _orders.length : end;
            ret =  new Order[](end - pageSt);
            for(uint i = 0;pageSt < end; i++){
                ret[i] = orderTb[_orders[pageSt]];
                pageSt++;
            } 
        }

        return ret;
    }

    function getOrdersByPage(uint pageSt, uint pageSz) 
    public view override returns(Order[] memory){
        Order[] memory ret;

        if(pageSt < orders.length){
            uint end = pageSt + pageSz;
            end = end > orders.length ? orders.length : end;
            ret =  new Order[](end - pageSt);
            for(uint i = 0;pageSt < end; i++){
                ret[i] = orderTb[orders[pageSt]];
                pageSt++;
            } 
        }

        return ret;
    }

    function getOrderOffersByPage(uint orderId, uint pageSt, uint pageSz) 
    public view  override returns(Offer[] memory){
        uint[] storage offers = orderOfferTb[orderId];
        Offer[] memory ret;

        if(pageSt < offers.length){
            uint end = pageSt + pageSz;
            end = end > offers.length ? offers.length : end;
            ret =  new Offer[](end - pageSt);
            for(uint i = 0;pageSt < end; i++){
                ret[i] = offerTb[offers[pageSt]];
                pageSt++;
            } 
        }

        return ret;
    }

    function caculateFees(uint amount) view public returns(uint){
        // caculate owner fee + taker fee
        return amount.mul(feeRatio).div(FEE_RATIO_DIV);
    }

    // Buyer accept the price and makes a deal with the sepcific order
    function acceptOffer(uint orderId) public  override payable {
        Order storage order = orderTb[orderId];
        require(order.timeStamp > 0,"INVALID_ORDER");
        require(msg.sender != order.owner, "SHOULD_NOT_BE_ORDER_OWNER");

        // aculate sales
        uint fee = caculateFees(order.price);
        uint amount = order.price.sub(fee);
        if(order.payMethod == PayMethod.PAY_BNB){
            require(msg.value == order.price, "INSUFFICIENT_FUNDS");
            payable(address(order.owner)).transfer(amount);
        } else if(order.payMethod == PayMethod.PAY_BUSD){
            busdContract.transferFrom(msg.sender, order.owner, amount);
        } else {
            bibContract.transferFrom(msg.sender, order.owner, amount);
        }

        // send token 
        IERC721(address(tokenContract)).transferFrom(address(this), msg.sender, order.tokenId);

        emit AcceptOffer(
                msg.sender, 
                order.owner,
                msg.sender,
                fee,
                orderId,
                0,
                order.payMethod, 
                order.price);

        // refund commodity and currency
        acceptAndRefundOffer(order, orderOfferTb[orderId], orderOfferTb[orderId].length);

        // close order
        _closeOrder(orderId);
    }

    // Owner accept the offer and make a deal
    function acceptOffer(uint orderId, uint offerId) public  override payable{
        Order storage order = orderTb[orderId];
        require(order.timeStamp > 0,"INVALID_ORDER");
        require(msg.sender == order.owner, "SHOULD_BE_ORDER_OWNER");

        Offer storage offer = offerTb[offerId];
        require(address(0) != offer.buyer, "INVALID_OFFER_ID");

        // aculate sales
        uint fee = caculateFees(offer.bid);
        uint amount = offer.bid.sub(fee);
        if(order.payMethod == PayMethod.PAY_BNB){
            payable(address(order.owner)).transfer(amount);
        } else if(order.payMethod == PayMethod.PAY_BUSD){
            busdContract.transfer(order.owner, amount);
        } else {
            bibContract.transfer(order.owner, amount);
        }

        // send token 
        IERC721(address(tokenContract)).transferFrom(address(this), offer.buyer, order.tokenId);

        emit AcceptOffer(
                msg.sender, 
                offer.buyer,
                order.owner,
                fee,
                orderId,
                offerId,
                order.payMethod, 
                offer.bid);
        
        // refund commodity and currency
        acceptAndRefundOffer(order, orderOfferTb[orderId], offerId);
        
        // close order
        _closeOrder(orderId);
    }
    
    // Owner updates order price
    function updateOrderPrice(uint orderId, uint price) public override payable{
        Order storage order = orderTb[orderId];
        require(order.timeStamp > 0,"INVALID_ORDER");
        require(price > 0, "PRICE_LE_ZERO");
        require(msg.sender == order.owner, "SHOULD_BE_ORDER_OWNER");

        emit UpdateOrderPrice(msg.sender, order.price, price);
        order.price = price;
        order.timeStamp = block.timestamp;
    }

    function _closeOrder(uint orderId) internal {
        Order storage order = orderTb[orderId];
        require(order.timeStamp > 0,"INVALID_ORDER");

        uint indexToRm = orders.length;
        for(uint i = 0; i < orders.length; i++){
           if(orderTb[orders[i]].orderId == orderId){
                indexToRm = i;
           }
        }
        require(indexToRm < orders.length, "ORDER_NOT_EXIST");
        for(uint i = indexToRm; i < orders.length - 1; i++){
            orders[i] = orders[i+1];
        }
        orders.pop();


        uint[] storage userOrders = userOrderTb[order.owner];
        indexToRm = userOrders.length;
        for(uint i = 0; i < userOrders.length; i++){
           if(orderTb[userOrders[i]].orderId == orderId){
                indexToRm = i;
           }
        }
        require(indexToRm < userOrders.length, "ORDER_NOT_EXIST");
        for(uint i = indexToRm; i < userOrders.length - 1; i++){
            userOrders[i] = userOrders[i+1];
        }
        userOrders.pop();

        delete orderOfferTb[orderId];
        delete orderTb[orderId];

        emit CloseOrder(msg.sender, orderId);
    }

    function acceptAndRefundOffer(Order storage order, uint[] storage offers, uint acceptOfferId) internal {
        for(uint i = 0; i < offers.length; i++){
            Offer storage offer = offerTb[offers[i]];

            if(acceptOfferId == offer.offerId) {
                continue;
            }

            if(order.payMethod == PayMethod.PAY_BNB){
                payable(address(offer.buyer)).transfer(offer.bid);
            } else if(order.payMethod == PayMethod.PAY_BUSD){
                busdContract.transfer(offer.buyer, offer.bid);
            } else {
                bibContract.transfer(offer.buyer, offer.bid);
            }
        }
    }

    // Owner close the specific order if not dealed
    function closeOrder(uint orderId) public override{
        Order storage order = orderTb[orderId];
        require(order.timeStamp > 0,"INVALID_ORDER");
        require(msg.sender == order.owner, "SHOULD_BE_ORDER_OWNER");

        // refund commodity and currency
        acceptAndRefundOffer(order, orderOfferTb[orderId], orderOfferTb[orderId].length);

        IERC721(address(tokenContract)).transferFrom(address(this), order.owner, order.tokenId);
        
        _closeOrder(orderId);
    }

    // Buyer make a offer to the specific order
    function makeOffer(uint orderId, uint price) public override payable{
        Order storage order = orderTb[orderId];
        require(order.timeStamp > 0,"INVALID_ORDER");
        require(price > 0, "PRICE_NOT_BE_ZEROR");

        // check if has made offer before
        uint[] storage offers = orderOfferTb[orderId];
        for(uint i = 0; i < offers.length; i++){
            if(offerTb[offers[i]].buyer == msg.sender){
                revert("HAS_MADE_OFFER");
            }
        }

        if(order.payMethod == PayMethod.PAY_BNB){
            require(msg.value >= price, "INSUFFICIENT_FUNDS");
        } else if(order.payMethod == PayMethod.PAY_BUSD){
            busdContract.transferFrom(msg.sender, address(this), price);
        } else {
            bibContract.transferFrom(msg.sender, address(this), price);
        }

        Offer memory offer = Offer({
            offerId: nextOfferIndex,
            buyer: msg.sender,
            bid: price,
            timeStamp: block.timestamp
        });

        orderOfferTb[orderId].push(offer.offerId);
        offerTb[nextOfferIndex] = offer;

        emit MakeOffer(msg.sender,  order.owner, orderId, nextOfferIndex++, price);
    }

    // Buyer udpate offer bid price
    function updateOffer(uint orderId, uint offerId, uint price) public override payable{
        Order storage order = orderTb[orderId];
        require(order.timeStamp > 0,"INVALID_ORDER");

        Offer storage offer = offerTb[offerId];
        require(msg.sender != offer.buyer, "INVALID_OFFER_ID");
        require(price > 0, "PRICE_NOT_BE_ZEROR");
        
        uint delt  = 0;
        if(offer.bid > price){
            delt = offer.bid.sub(price);
            if(order.payMethod == PayMethod.PAY_BNB){
                payable(address(offer.buyer)).transfer(delt);
            } else if(order.payMethod == PayMethod.PAY_BUSD){
                busdContract.transfer(offer.buyer, delt);
            } else {
                bibContract.transfer(offer.buyer, delt);
            }
        } else {
            delt = price.sub(offer.bid);
            if(order.payMethod == PayMethod.PAY_BNB){
                require(msg.value >= delt, "INSUFFICIENT_FUNDS");
            } else if(order.payMethod == PayMethod.PAY_BUSD){
                busdContract.transferFrom(msg.sender, address(this), delt);
            } else {
                bibContract.transferFrom(msg.sender, address(this), delt);
            }
        }

        emit UpdateOfferPrice(msg.sender, offer.bid, price);

        offer.bid = price;
        offer.timeStamp = block.timestamp;
    }

    // Buyer cancle the specific order
    function cancelOffer(uint orderId, uint offerId) public override{
        Order storage order = orderTb[orderId];
        require(order.timeStamp > 0,"INVALID_ORDER");

        Offer storage offer = offerTb[offerId];
        require(msg.sender == offer.buyer, "SHOULD_BE_BUYER");

        if(order.payMethod == PayMethod.PAY_BNB){
            payable(address(offer.buyer)).transfer(offer.bid);
        } else if(order.payMethod == PayMethod.PAY_BUSD){
            busdContract.transfer(offer.buyer, offer.bid);
        } else {
            bibContract.transfer(offer.buyer, offer.bid);
        }

        uint[] storage offers = orderOfferTb[orderId];
        uint indexToRm = offers.length;
        for(uint i = 0; i < offers.length; i++){
           if(offerTb[offers[i]].offerId == offerId){
                indexToRm = i;
           }
        }
        require(indexToRm < offers.length, "OFFER_NOT_EXIST");
        for(uint i = indexToRm; i < offers.length - 1; i++){
            offers[i] = offers[i+1];
        }
        offers.pop();
        delete offerTb[offerId];

        emit CancelOffer(msg.sender, offerId);
    }
}