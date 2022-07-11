// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IERC20MintableBurnable is IERC20 {
    function mint(address, uint256) external;

    function burnFrom(address, uint256) external;
}

interface IERC721MintableBurnable is IERC721 {
    function safeMint(address, uint256) external;

    function burn(uint256) external;
}

contract SoccerStarNft is ERC721A, Ownable, Initializable {
    uint256 public constant maxMintSupply = 29930;
    uint256 public mintPrice;
    uint256 public refundPeriod;
    IERC20MintableBurnable public paymentToken;

    address public deadwallet = 0x0000000000000000000000000000000000000000;//将代币打进这个地址就是销毁

    uint256 public constant BATCH_SIZE = 150;
    uint256 public constant MAX_SUPPLY = 1000000;

    // _paused is used to pause the contract in case of an emergency
    bool public _paused;

     struct SoccerStar {
        string name;
        string country;
        string position;
        uint256 starLevel;//0=1star, 1=2star, 2=3star, 3=4star
        uint256 gradient;//梯度，T0=0, T1=1, T2=2, T3=3
    }

    SoccerStar soccerStars;

    modifier onlyWhenNotPaused {
        require(!_paused, "Contract currently paused");
        _;
    }

    // Sale Status
    bool public publicSaleActive;
    bool public presaleActive;
    uint256 public refundEndTime;

    address public refundAddress;
    uint256 public constant maxUserMintAmount = 5;
    bytes32 public merkleRoot;

    mapping(uint256 => bool) public hasRefunded; // users can search if the NFT has been refunded
    mapping(uint256 => bool) public isOwnerMint; // if the NFT was freely minted by owner

    string private baseURI;

    function initialize(uint256 _mintPrice,uint256 _refundPeriod,address _paymentToken) initializer public {

           mintPrice = _mintPrice;
           refundPeriod = _refundPeriod;
           paymentToken = IERC20MintableBurnable(_paymentToken);
    }

    constructor() ERC721A("SoccerStar", "SS") {
        refundAddress = msg.sender;
        toggleRefundCountdown();
    }

    /**
    * @dev setPaused makes the contract paused or unpaused
     */
    function setPaused(bool val) public onlyOwner {
        _paused = val;
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function setSoccerStars(string memory _name,string memory _country,string memory _position, uint256 _starLevel, uint256 _gradient) public onlyOwner {
        soccerStars.name = _name;
        soccerStars.country = _country;
        soccerStars.position = _position;
        soccerStars.starLevel = _starLevel;
        soccerStars.gradient = _gradient;
    }

    function setRefundPeriod(uint256 _refundPeriod) public onlyOwner {
        refundPeriod = _refundPeriod;
    }

    function preSaleMint(uint256 quantity, bytes32[] calldata proof)
        external
        payable
        onlyWhenNotPaused
    {
        require(presaleActive, "Presale is not active");
        require(msg.value == quantity * mintPrice, "Value");
        require(
            _isAllowlisted(msg.sender, proof, merkleRoot),
            "Not on allow list"
        );
        require(
            _numberMinted(msg.sender) + quantity <= maxUserMintAmount,
            "Max amount"
        );
        require(_totalMinted() + quantity <= maxMintSupply, "Max mint supply");

        _safeMint(msg.sender, quantity);
        
         paymentToken.burnFrom(deadwallet, quantity);
    }

    function publicSaleMint(uint256 quantity) external payable onlyWhenNotPaused {
        require(publicSaleActive, "Public sale is not active");
        require(msg.value >= quantity * mintPrice, "Not enough eth sent");
        require(
            _numberMinted(msg.sender) + quantity <= maxUserMintAmount,
            "Over mint limit"
        );
        require(
            _totalMinted() + quantity <= maxMintSupply,
            "Max mint supply reached"
        );

        _safeMint(msg.sender, quantity);
        paymentToken.burnFrom(deadwallet, quantity);
    }

    function ownerMint(uint256 quantity) external onlyOwner onlyWhenNotPaused {
        require(
            _totalMinted() + quantity <= maxMintSupply,
            "Max mint supply reached"
        );
        _safeMint(msg.sender, quantity);
        paymentToken.burnFrom(deadwallet, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            isOwnerMint[i] = true;
        }
    }

    function refund(uint256[] calldata tokenIds) external {
        require(isRefundGuaranteeActive(), "Refund expired");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(msg.sender == ownerOf(tokenId), "Not token owner");
            require(!hasRefunded[tokenId], "Already refunded");
            require(!isOwnerMint[tokenId], "Freely minted NFTs cannot be refunded");
            hasRefunded[tokenId] = true;
            transferFrom(msg.sender, refundAddress, tokenId);
        }

        uint256 refundAmount = tokenIds.length * mintPrice;
        Address.sendValue(payable(msg.sender), refundAmount);
    }

    function getRefundGuaranteeEndTime() public view returns (uint256) {
        return refundEndTime;
    }

    function isRefundGuaranteeActive() public view returns (bool) {
        return (block.timestamp <= refundEndTime);
    }

    function withdraw() external onlyOwner {
        require(block.timestamp > refundEndTime, "Refund period not over");
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setRefundAddress(address _refundAddress) external onlyOwner {
        refundAddress = _refundAddress;
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function toggleRefundCountdown() public onlyOwner {
        refundEndTime = block.timestamp + refundPeriod;
    }

    function togglePresaleStatus() external onlyOwner {
        presaleActive = !presaleActive;
    }

    function togglePublicSaleStatus() external onlyOwner {
        publicSaleActive = !publicSaleActive;
    }

    function _leaf(address _account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account));
    }

    function _isAllowlisted(
        address _account,
        bytes32[] calldata _proof,
        bytes32 _root
    ) internal pure returns (bool) {
        return MerkleProof.verify(_proof, _root, _leaf(_account));
    }
}