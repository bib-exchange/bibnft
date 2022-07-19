//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error InvalidAddress();

contract ComposableNFT is Ownable {
    IERC721 public _nftToken;

    address constant BLACKHOLE_ADDRESS = address(0);

    event NFTTokenChanged(address indexed _sender, address oldValue, address newValue);
    
    constructor(IERC721 nftToken) public{
        _nftToken = nftToken;
    }

    /**
    * @dev setup new bib token contract address
    */
    function setNFTToken(address nftToken) public onlyOwner {
        if(address(0) == nftToken){
            revert InvalidAddress();
        }
        _nftToken = IERC721(nftToken);
        emit NFTTokenChanged(msg.sender, _nftToken, nftToken);
    }

    /**
    * @dev compose higher start level card via buring low
    * leve card with same soccer and T level
    */
    function composeHighStarlevelCard(uint[5] tokenIds, IECR20 payment) public {
        
        uint tokenCount = 0;
        uint[] memory tokens = new uint256[](tokenIds.length);
        
        for(uint i = 0; i < tokenIds.length; i++){
            if(msg.sender == _nftToken.ownerOf(tokenIds[i])){
                tokens[i] = tokenIds[i];
                tokenCount++;
            }
        }

        // use 2 lower card to compose one higer level card
        if(address(0) == address(payment)){
            require(tokenCount == 5, "INCORECT_CARD_NUM");
            

        } else {

        }
    }
}
