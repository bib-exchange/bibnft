// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ISoccerStarNft} from "../../interfaces/ISoccerStarNft.sol";

interface IERC20MintableBurnable is IERC20 {
    function mint(address, uint256) external;

    function burnFrom(address, uint256) external;
}

interface IERC721MintableBurnable is IERC721 {
    function safeMint(address, uint256) external;

    function burn(uint256) external;
}

contract SoccerStarNft is ERC721A, Ownable, Initializable, ISoccerStarNft {
    using Strings for uint;
    uint256 public constant maxMintSupply = 29930;
    uint256 public mintPresalePrice;
    uint256 public mintSale1Price;
    uint256 public mintSale2Price;
    uint256 public mintSale3Price;
    uint256 public mintSale4Price;
    uint256 public mintSale5Price;

    uint256 public refundPeriod;
    //URI of the NFTs when revealed
    string public baseURI;
    //URI of the NFTs when not revealed
    string public notRevealedURI;
    //The extension of the file containing the Metadatas of the NFTs
    string public baseExtension = ".json";

    //Are the NFTs revealed yet ?
    bool public revealed = false;
    IERC20MintableBurnable public paymentToken;

    uint private constant MAX_PRESALE = 4800;
    uint private constant MAX_PUBLIC_ROUND1_NORMAL = 1300;
    uint private constant MAX_PUBLIC_ROUND1_SUPERS = 460;
    uint private constant MAX_PUBLIC_ROUND1_LEGEND = 160;
    uint private constant MAX_PUBLIC_ROUND2_NORMAL = 1950;
    uint private constant MAX_PUBLIC_ROUND2_SUPERS = 690;
    uint private constant MAX_PUBLIC_ROUND2_LEGEND = 240;
    uint private constant MAX_PUBLIC_ROUND3_NORMAL = 2600;
    uint private constant MAX_PUBLIC_ROUND3_SUPERS = 920;
    uint private constant MAX_PUBLIC_ROUND3_LEGEND = 320;
    uint private constant MAX_PUBLIC_ROUND4_NORMAL = 3250;
    uint private constant MAX_PUBLIC_ROUND4_SUPERS = 1150;
    uint private constant MAX_PUBLIC_ROUND4_LEGEND = 400;
    uint private constant MAX_PUBLIC_ROUND5_NORMAL = 3900;
    uint private constant MAX_PUBLIC_ROUND5_SUPERS = 1380;
    uint private constant MAX_PUBLIC_ROUND5_LEGEND = 480;

    uint256 public    preSaleStartTime = 1662739200;//9月10日0时0分0秒
    uint256 public    saleStartTimeRound1 = 1663603200;//9月20日0时0分0秒
    uint256 public    saleStartTimeRound2 = 1664208000;//9月27日0时0分0秒
    uint256 public    saleStartTimeRound3 = 1664812800;//10月4日0时0分0秒
    uint256 public    saleStartTimeRound4 = 1665417600;//10月11日0时0分0秒
    uint256 public    saleStartTimeRound5 = 1666022400;//10月18日0时0分0秒
    uint256 public    revealTime = 1666022422;//10月18日0时0分0秒

    uint256 public    preSaleEndTime;
    uint256 public    saleEndTimeRound1;
    uint256 public    saleEndTimeRound2;
    uint256 public    saleEndTimeRound3;
    uint256 public    saleEndTimeRound4;
    uint256 public    saleEndTimeRound5;

    address public deadwallet = 0x0000000000000000000000000000000000000000;//将代币打进这个地址就是销毁
    //Keep a track of the number of tokens per address
    mapping(address => uint) nftsPerWallet;

    // _paused is used to pause the contract in case of an emergency
    bool public _paused;

    enum Step {
        preSaleMint,
        publicSaleMintRound1,
        publicSaleMintRound2,
        publicSaleMintRound3,
        publicSaleMintRound4,
        publicSaleMintRound5,
        Reveal
    }

    Step public sellingStep;
    Step constant defaultStep = Step.preSaleMint;

    enum BlindBoxesType {
        presale,
        normal,
        supers,
        legend
    }
    BlindBoxesType public blindBoxes;
    BlindBoxesType constant defaultType = BlindBoxesType.presale;

    SoccerStar[] public soccerStars;

    modifier onlyWhenNotPaused {
        require(!_paused, "Contract currently paused");
        _;
    }

    // Sale Status
    bool public publicSaleActive;
    bool public presaleActive;
    uint256 public refundEndTime;

    address public refundAddress;
    uint256 public remainingMint;
    uint256 public alreadyMint;
    uint256 public constant maxPresaleUserMintAmount = 2;
    uint256 public constant maxPubicsaleUserMintAmount = 1;
    bytes32 public merkleRoot;

    mapping(uint256 => bool) public hasRefunded; // users can search if the NFT has been refunded
    mapping(uint256 => bool) public isOwnerMint; // if the NFT was freely minted by owner
    mapping(uint256 => SoccerStar) public cardProperty;
    mapping(address => SoccerStar[]) public userCardWallet;

    event UpdatesSaleStep(address newAddress, BlindBoxesType blindBoxes, uint256 tokenId, uint256 quantity);

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function initialize(string memory _theBaseURI, string memory _notRevealedURI, bytes32 _merkleRoot) initializer public {
           merkleRoot = _merkleRoot;
           baseURI = _theBaseURI;
           notRevealedURI = _notRevealedURI;
    }


    constructor() ERC721A("SoccerStarNft", "SS") {
        refundAddress = msg.sender;
        toggleRefundCountdown();
        alreadyMint = totalSupply();
    }

    function getCardProperty(uint256 tokenId) public view override
    returns(SoccerStar memory){
        return cardProperty[tokenId];
    }

    function reveal(uint[] memory tokenIds, SoccerStar[] memory _soccerStars)
        external
        onlyOwner
    {
        require(tokenIds.length == _soccerStars.length, "NEED_SAME_LENGTH");
        for(uint i = 0; i < _soccerStars.length; i++){
            require(cardProperty[tokenIds[i]].starLevel == 0, "TOKEN_REVEALED");
            cardProperty[tokenIds[i]] = _soccerStars[i];
        }
    }

    /**
    * @dev setPaused makes the contract paused or unpaused
     */
    function setPaused(bool val) public onlyOwner {
        _paused = val;
    }

    function setPreSaleTime(uint _preSaleStartTime, uint _preSaleEndTime, uint _revealTime) external onlyOwner {
        preSaleStartTime = _preSaleStartTime;
        preSaleEndTime = _preSaleEndTime;
        revealTime = _revealTime;
    }

    function setSaleTime1(uint _saleStartTime,uint _saleEndTimeRound1,uint _revealTime) external onlyOwner {
        saleStartTimeRound1 = _saleStartTime;
        saleEndTimeRound1 = _saleEndTimeRound1;
        revealTime = _revealTime;
    }

    function setSaleTime2(uint _saleStartTime,uint _saleEndTimeRound2,uint _revealTime) external onlyOwner {
        saleStartTimeRound2 = _saleStartTime;
        saleEndTimeRound2 = _saleEndTimeRound2;
        revealTime = _revealTime;
    }

    function setSaleTime3(uint _saleStartTime, uint _saleEndTimeRound2,uint _revealTime) external onlyOwner {
        saleStartTimeRound3 = _saleStartTime;
        saleEndTimeRound3 = _saleEndTimeRound2;
        revealTime = _revealTime;
    }

    function setSaleTime4(uint _saleStartTime, uint _saleEndTimeRound4,uint _revealTime) external onlyOwner {
        saleStartTimeRound4 = _saleStartTime;
         saleEndTimeRound4 = _saleEndTimeRound4;
        revealTime = _revealTime;
    }

    function setSaleTime5(uint _saleEndTime, uint _saleEndTimeRound5,uint _revealTime) external onlyOwner {
        saleStartTimeRound5 = _saleEndTime;
        saleEndTimeRound5 = _saleEndTimeRound5;
        revealTime = _revealTime;
    }

    function setMintPrePrice(uint256 _mintPrice, BlindBoxesType _blindBoxes) public onlyOwner {
        mintPresalePrice = _mintPrice;
    }

    function setMintSale1Price(uint256 _mintPrice1, BlindBoxesType _blindBoxes) public onlyOwner {
         if (_blindBoxes == BlindBoxesType.normal) {

            mintSale1Price = _mintPrice1;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
            mintSale1Price = _mintPrice1;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale1Price = _mintPrice1;
        }
    }

    function setMintSale2Price(uint256 _mintPrice, BlindBoxesType _blindBoxes) public onlyOwner {
        

        if (_blindBoxes == BlindBoxesType.normal) {

            mintSale2Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
            mintSale2Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale2Price = _mintPrice;
        }
    }

    function setMintSale3Price(uint256 _mintPrice, BlindBoxesType _blindBoxes) public onlyOwner {
          if (_blindBoxes == BlindBoxesType.normal) {

            mintSale3Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
            mintSale3Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale3Price = _mintPrice;
        }
    }

    function setMintSale4Price(uint256 _mintPrice, BlindBoxesType _blindBoxes) public onlyOwner {
        

          if (_blindBoxes == BlindBoxesType.normal) {

            mintSale4Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
            mintSale4Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale4Price = _mintPrice;
        }
    }

    function setMintSale5Price(uint256 _mintPrice, BlindBoxesType _blindBoxes) public onlyOwner {
        

         if (_blindBoxes == BlindBoxesType.normal) {

            mintSale4Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.supers) {
           
             mintSale4Price = _mintPrice;
        } else if (_blindBoxes == BlindBoxesType.legend){
            
            mintSale4Price = _mintPrice;
        }
    }


     /**
    * @notice Allows to set the revealed variable to true
    **/
    function reveal() external onlyOwner{

        // require(currentTime() >= revealTime, "Whitelist reveal not start");
        revealed = true;
    }

    //计算剩余mint的数量
    function caculatePreRemaining() view public returns (uint256) {
            return MAX_PRESALE - totalSupply();
    }

    function caculateRound1NormalRemaining() view public returns (uint256) {
            return MAX_PUBLIC_ROUND1_NORMAL - totalSupply();
    }

    function setRefundPeriod(uint256 _refundPeriod) public onlyOwner {
        refundPeriod = _refundPeriod;
    }

    function getUserCardWallet(address _user) public returns (SoccerStar[] memory) {
        return userCardWallet[_user];
    }

    function preSaleMint(uint256 quantity, bytes32[] calldata proof)
        external
        payable
        onlyWhenNotPaused
        callerIsUser
    {
        require(presaleActive, "Presale is not active");
        require(msg.value >= quantity * mintPresalePrice, "Not enough eth sent");
        require(currentTime() >= preSaleStartTime, "Whitelist Sale has not started yet");
        require(currentTime() < preSaleEndTime, "Whitelist Sale is finished");
        require(sellingStep == Step.preSaleMint, "Whitelist sale is not activated");
        require(
            _isAllowlisted(msg.sender, proof, merkleRoot),
            "Not on allow list"
        );
        require(
            _numberMinted(msg.sender) + quantity <= maxPresaleUserMintAmount,
            "Max Presale User Mint amount"
        );
        require(_totalMinted() + quantity <= MAX_PRESALE, "Max PRESALE mint supply");

        _safeMint(msg.sender, quantity);

        emit UpdatesSaleStep(msg.sender, BlindBoxesType.presale, _currentIndex - quantity, quantity);

        //_currentIndex - quantity is tokenid for

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        // EVENT：sender,presale,_currentIndex - quantity,quantitty，ramdomseed
         paymentToken.burnFrom(deadwallet, quantity * mintPresalePrice);
    }


    function publicSaleMint(BlindBoxesType _blindBoxes, uint256 quantity, uint round) external payable onlyWhenNotPaused callerIsUser {
        require(publicSaleActive, "Public sale is not active");

         if (round == 1) {
        require(msg.value >= quantity * mintSale1Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound1, "public Sale round1 has not started yet");
        require(currentTime() < saleEndTimeRound1, "public Sale round1 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound1, "publicSaleMintRound1 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );
        
        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale1Price);
            
        } else if (round == 2) {
              require(msg.value >= quantity * mintSale2Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound2, "public Sale round2 has not started yet");
        require(currentTime() < saleEndTimeRound2, "public Sale round2 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound2, "publicSaleMintRound2 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );

         if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND2_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND2_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND2_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

          for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale2Price);

           
        } else if (round == 3){
        require(msg.value >= quantity * mintSale3Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound3, "public Sale round1 has not started yet");
        require(currentTime() < saleEndTimeRound3, "public Sale round1 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound3, "publicSaleMintRound1 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );
        
        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND1_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale3Price);
            
        } else if (round == 4) {
             require(msg.value >= quantity * mintSale4Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound4, "public Sale round4 has not started yet");
        require(currentTime() < saleEndTimeRound4, "public Sale round4 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound4, "publicSaleMintRound4 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );

        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND4_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND4_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND4_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale4Price);


        } else if (round == 5) {
            require(msg.value >= quantity * mintSale5Price, "Not enough eth sent");
        require(currentTime() >= saleStartTimeRound5, "public Sale round5 has not started yet");
        require(currentTime() < saleEndTimeRound5, "public Sale round5 Sale is finished");
        require(sellingStep == Step.publicSaleMintRound5, "publicSaleMintRound5 sale is not activated");
        require(
            _numberMinted(msg.sender) + quantity <= maxPubicsaleUserMintAmount,
            "Over mint limit"
        );

        if (_blindBoxes == BlindBoxesType.normal) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND5_NORMAL, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.supers) {
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND5_SUPERS,"Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        } else if (_blindBoxes == BlindBoxesType.legend){
            require(_totalMinted() + quantity <= MAX_PUBLIC_ROUND5_LEGEND, "Max mint supply reached");
            return _safeMint(msg.sender, quantity);
        }

        emit UpdatesSaleStep(msg.sender, _blindBoxes, _currentIndex - quantity, quantity);
        
        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        paymentToken.burnFrom(deadwallet, quantity * mintSale5Price);
        
         }

     }



    function ownerMint(uint256 quantity) external onlyOwner onlyWhenNotPaused {
        require(
            _totalMinted() + quantity <= maxMintSupply,
            "Max mint supply reached"
        );
        _safeMint(msg.sender, quantity);

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            cardProperty[i] = soccerStars[_currentIndex];
        }

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) {
            isOwnerMint[i] = true;
        }
    }

    function setStep(uint _step) external onlyOwner {
        sellingStep = Step(_step);
    }
// 需要识别用户付款但没有收到NFT的情况，自动回退Mint失败资金。
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

        uint256 refundAmount = tokenIds.length * mintPresalePrice;
        Address.sendValue(payable(msg.sender), refundAmount);
    }

    function getRefundGuaranteeEndTime() public view returns (uint256) {
        return refundEndTime;
    }

    function isRefundGuaranteeActive() public view returns (bool) {
        return (block.timestamp <= refundEndTime);
    }

    function currentTime() internal view returns(uint) {
        return block.timestamp;
    }

    function withdraw() external onlyOwner {
        require(block.timestamp > refundEndTime, "Refund period not over");
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(uint _nftId) public view override(ERC721A) returns (string memory) {
        require(_exists(_nftId), "This NFT doesn't exist.");
        if(revealed == false) {
            return notRevealedURI;
        }
        
        string memory currentBaseURI = _baseURI();
        return 
            bytes(currentBaseURI).length > 0 
            ? string(abi.encodePacked(currentBaseURI, _nftId.toString(), baseExtension))
            : "";
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

    function setNotRevealURI(string memory _notRevealedURI) external onlyOwner {
        notRevealedURI = _notRevealedURI;
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