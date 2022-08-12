pragma solidity 0.8.9;

contract NFTCardMock {
    struct SoccerStar {
        string name;
        string country;
        string position;
        // range [1,4]
        uint256 starLevel;
        // range [1,4]
        uint256 gradient;
    }
    
    function getCardProperty(uint256 tokenId) external view returns(SoccerStar memory){
        if (tokenId > 2) return SoccerStar({name:"1", country:"",position:"",starLevel: 4,gradient:1});
        return SoccerStar({name:"1", country:"",position:"",starLevel: 3,gradient:1});
    }
    
    function ownerOf(uint256 tokenId) external view returns (address) {
        if(tokenId == 1) return 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        if (tokenId == 2) return 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        if(tokenId==3) return 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        if(tokenId==4) return 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    }
}