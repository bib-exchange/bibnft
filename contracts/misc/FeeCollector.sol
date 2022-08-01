// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.0;

import {SafeMath} from "../libs/SafeMath.sol";
import {SafeCast} from "../libs/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from  "@openzeppelin/contracts/access/Ownable.sol";
import {IRewardDistributor} from "../interfaces/IRewardDistributor.sol";

contract FeeCollector is  Ownable {
    using SafeMath for uint;
    using SafeCast for uint;

    uint totalBNBRecieved;
    uint totalBUSDRecieved;
    uint totalBIBRecieved;

    mapping(address=>bool) protocolAddress;

    uint public vaultRatio;
    uint public constant FEE_RATIO_DIV = 1000;
    
    IRewardDistributor rewardDistributor;
    address vault;

    IERC20 bibToken;
    IERC20 busdToken;

    enum TokenType{
        TOKEN_TYPE_ETH,
        TOKEN_TYPE_BIB,
        TOKEN_TYPE_BUSD
    } 

    event VaultChanged(address sender, address oldValue, address newValue);
    event BIBContractChanged(address sender, address oldValue, address newValue);
    event BUSDContractChanged(address sender, address oldValue, address newValue);
    event VaultRatioChanged(address sender, uint oldValue, uint newValue);
    event RewardDistributorChanged(address sender, address oldValue, address newValue);
    event HandleCollect(address sender, uint vault, uint reward, TokenType tokenType);

    constructor(
        address _vault,
        address _bibToken,
        address _busdToken,
        address _rewardDistributor
        ){
        vault = _vault;
        bibToken = IERC20(_bibToken);
        busdToken = IERC20(_busdToken);
        rewardDistributor = IRewardDistributor(_rewardDistributor);
    }

    function setBIBContract(address _bibToken) public onlyOwner{
        require(address(0) != _bibToken, "INVALID_ADDRESS");
        emit BIBContractChanged(msg.sender, address(bibToken), _bibToken);
        bibToken = IERC20(_bibToken);
    }

    function setRewardDistributor(address _rewardDistributor) public onlyOwner{
        require(address(0) != _rewardDistributor, "INVALID_ADDRESS");
        emit RewardDistributorChanged(msg.sender, address(rewardDistributor), _rewardDistributor);
        rewardDistributor = IRewardDistributor(_rewardDistributor);
    }

    function setBUSDContract(address _busdToken) public onlyOwner{
        require(address(0) != _busdToken, "INVALID_ADDRESS");
        emit BUSDContractChanged(msg.sender, address(busdToken), _busdToken);
        busdToken = IERC20(_busdToken);
    }

    function setVault(address _vault) public onlyOwner{
        require(address(0) != _vault, "INVALID_ADDRESS");
        emit VaultChanged(msg.sender, address(vault), _vault);
        vault = _vault;
    }

    function setVaultRatio(uint _vaultRatio) public onlyOwner{
        require(_vaultRatio <= FEE_RATIO_DIV, "INVALID_RATIO");
        emit VaultRatioChanged(msg.sender, vaultRatio, _vaultRatio);
        vaultRatio = _vaultRatio;
    }

    function addProtocolAdress(address protocolAddr) public onlyOwner{
        protocolAddress[protocolAddr] = true;
    }

    function removeProtocolAddress(address protocolAddr) public onlyOwner{
        delete protocolAddress[protocolAddr];
    }

    function isProtocolAddress(address protocolAddr) public view returns(bool){
        return protocolAddress[protocolAddr];
    }

    modifier onlyProtocolAddress(){
        require(protocolAddress[msg.sender], "ONLY_PROTOCOL_ADDRESS_CAN_CALL");
        _;
    }

    function caculateFees(uint amount) public pure  returns(uint, uint){
        uint vaultPart =  amount.mul(FEE_RATIO_DIV).div(FEE_RATIO_DIV);
        return (vaultPart, amount.sub(vaultPart));
    }

    function distributeFees() public onlyOwner(){
        handleCollectBIB(bibToken.balanceOf(address(this)));
        handleCollectBUSD(busdToken.balanceOf(address(this)));
        handleCollectBNB(address(this).balance);
    }

    function handleCollectBIB(uint amount) public onlyProtocolAddress{
        if(address(0) != address(rewardDistributor) && address(0) != vault){
            (uint vaultPart, uint rewardPart) = caculateFees(amount);
            bibToken.transfer(vault, vaultPart);
            bibToken.transfer(address(rewardDistributor), rewardPart);
            rewardDistributor.distributeBIBReward(amount);
            emit HandleCollect(msg.sender, vaultPart, rewardPart, TokenType.TOKEN_TYPE_BIB);
        }
    }

    function handleCollectBUSD(uint amount) public onlyProtocolAddress{
        if(address(0) != address(rewardDistributor) && address(0) != vault){
            (uint vaultPart, uint rewardPart) = caculateFees(amount);
            busdToken.transfer(vault, vaultPart);
            busdToken.transfer(address(rewardDistributor), rewardPart);
            rewardDistributor.distributeBUSDReward(amount);
            emit HandleCollect(msg.sender, vaultPart, rewardPart, TokenType.TOKEN_TYPE_BUSD);
        }
    }

    function handleCollectBNB(uint amount) public onlyProtocolAddress{
        if(address(0) != address(rewardDistributor) && address(0) != vault){
            (uint vaultPart, uint rewardPart) = caculateFees(amount);
            payable(vault).transfer(vaultPart);
            rewardDistributor.distributeETHReward{value:rewardPart}(amount);
            emit HandleCollect(msg.sender, vaultPart, rewardPart, TokenType.TOKEN_TYPE_BUSD);
        }
    }
}