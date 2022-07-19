// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface ISoccerStarNft {

     struct SoccerStar {
        string name;
        string country;
        string position;
        // range [1,4]
        uint256 starLevel;
        // rage [1,4]
        uint256 gradient;
    }

    function getCardProperty(uint256 tokenId) external view returns(SoccerStar memory);
}
