// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.0;

import {Ownable} from "../deps/Ownable.sol";
import {SafeMath} from "../lib/SafeMath.sol";
import {SafeCast} from "../lib/SafeCast.sol";
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFeeReceiver} from "../interfaces/IFeeReceiver.sol";
import {VersionedInitializable} from "../deps/VersionedInitializable.sol";

contract FeeCollector is Ownable,VersionedInitializable {
    using SafeMath for uint;
    using SafeCast for uint;

    uint totalBNBRecieved;
    uint totalBUSDRecieved;
    uint totalBIBRecieved;

    mapping(address=>bool) allowCall;

    uint public constant VERSION = 0x01;
    uint public vaultRatio = 150;
    uint public stakedRatio = 400;
    uint public kolRatio = 50;
    uint public poolRatio = 550;
    uint public minBUSDToSwap = 100;
    uint public minBNBToSwap = 0.01 ether;

    uint public constant FEE_RATIO_DIV = 1000;
    
    IFeeReceiver stakedReceiver;
    IFeeReceiver kolReceiver;
    IFeeReceiver poolReceiver;
    IUniswapV2Router02 public uniswapV2Router;

    address vault;

    IERC20 bibToken;
    IERC20 busdToken;

    enum TokenType{
        TOKEN_TYPE_BNB,
        TOKEN_TYPE_BIB,
        TOKEN_TYPE_BUSD
    } 

    event VaultChanged(address sender, address oldValue, address newValue);
    event BIBContractChanged(address sender, address oldValue, address newValue);
    event BUSDContractChanged(address sender, address oldValue, address newValue);
    event RouterContractChanged(address sender, address oldValue, address newValue);
    event HandleCollect(address sender, TokenType tokenType, uint amount);

    function getRevision() internal pure override returns (uint256){
        return VERSION;
    }

    function initialize(
        address _vault,
        address _bibToken,
        address _busdToken,
        address _stakedReceiver,
        address _kolReceiver,
        address _poolReceiver
        ) public initializer {
            
        vault = _vault;
        bibToken = IERC20(_bibToken);
        busdToken = IERC20(_busdToken);

        stakedReceiver = IFeeReceiver(_stakedReceiver);
        kolReceiver = IFeeReceiver(_kolReceiver);
        poolReceiver = IFeeReceiver(_poolReceiver);
        _owner = msg.sender;
    }

    function setDistributeRatio(
        uint _vaultRatio,
        uint _stakedRatio,
        uint _kolRatio,
        uint _poolRatio
        ) public onlyOwner{
         vaultRatio = _vaultRatio;
         kolRatio = _kolRatio;
         poolRatio = _poolRatio;
         stakedRatio = _stakedRatio;

        require(vaultRatio <= FEE_RATIO_DIV, "INVALID_VAULT_RATIO");
        require(kolRatio.add(poolRatio).add(stakedRatio) <= FEE_RATIO_DIV, "INVALID_DIVEND_RATIO");
    }

    function setSwapThreshHold(uint _minBUSDToSwap, uint _minBNBToSwap) public onlyOwner{
        minBUSDToSwap = _minBUSDToSwap;
        minBNBToSwap = _minBNBToSwap;
    }

    function setFeeReceiver(
        address _stakedReceiver,
        address _kolReceiver,
        address _poolReceiver) public onlyOwner{
        stakedReceiver = IFeeReceiver(_stakedReceiver);
        kolReceiver = IFeeReceiver(_kolReceiver);
        poolReceiver = IFeeReceiver(_poolReceiver);
    }

    function setBIBContract(address _bibToken) public onlyOwner{
        require(address(0) != _bibToken, "INVALID_ADDRESS");
        emit BIBContractChanged(msg.sender, address(bibToken), _bibToken);
        bibToken = IERC20(_bibToken);
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

   function setSwapRouter(address _uniswapV2Router) public onlyOwner{
        require(address(0) != _uniswapV2Router, "INVALID_ADDRESS");
        emit RouterContractChanged(msg.sender, address(uniswapV2Router), _uniswapV2Router);
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
    }

    function setAllowCall(address caller, bool value) public onlyOwner{
        allowCall[caller] = value;
    }

    function isAllowCall(address caller) public view returns(bool){
        return allowCall[caller];
    }

    modifier onlyCaller(){
        require(allowCall[msg.sender], "ONLY_PROTOCOL_ADDRESS_CAN_CALL");
        _;
    }

    function caculateFees(uint amount, uint feeRatio) public pure  returns(uint, uint){
        uint firstPart =  amount.mul(feeRatio).div(FEE_RATIO_DIV);
        return (firstPart, amount.sub(firstPart));
    }

    function distributeFees() public onlyOwner{
        handleCollectBIB(bibToken.balanceOf(address(this)));
        handleCollectBUSD(busdToken.balanceOf(address(this)));
        handleCollectBNB(address(this).balance);
    }

    function distribute(uint amount) internal {
        (uint vaultPart,uint remain) = caculateFees(amount, vaultRatio);
        // to vault
        if(address(0) != vault){
            bibToken.transfer(vault, vaultPart);
        }
        // stake part
        (uint stakedPart, ) = caculateFees(remain, stakedRatio);
        if(address(0) != address(stakedReceiver)){
            bibToken.transfer(address(stakedReceiver), stakedPart);
            stakedReceiver.handleReceive(stakedPart);
        }
        // kol part
        (uint kolPart, ) = caculateFees(remain, kolRatio);
        if(address(0) != address(kolReceiver)){
            bibToken.transfer(address(kolReceiver), kolPart);
            kolReceiver.handleReceive(kolPart);
        }
        // kol part
        (uint poolPart, ) = caculateFees(remain, poolRatio);
        if(address(0) != address(poolReceiver)){
            bibToken.transfer(address(poolReceiver), poolPart);
            poolReceiver.handleReceive(poolPart);
        }
    }
   
    function handleCollectBIB(uint amount) public onlyCaller{
        distribute(amount);
        emit HandleCollect(msg.sender, TokenType.TOKEN_TYPE_BIB, amount);
    }

    function handleCollectBUSD(uint amount) public onlyCaller{
        if(busdToken.balanceOf(address(this)) >= minBUSDToSwap){
            // swap BIB
            address[] memory path = new address[](2);
            path[0] = address(busdToken);
            path[1] = address(bibToken);

            bibToken.approve(address(uniswapV2Router), amount);

            uint balanceBefore = bibToken.balanceOf(address(this));

            // make the swap
            uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amount,
                0,
                path,
                address(this),
                block.timestamp
            );
            uint swapped = bibToken.balanceOf(address(this)).sub(balanceBefore);

            distribute(swapped);
        }

        emit HandleCollect(msg.sender, TokenType.TOKEN_TYPE_BUSD, amount);
    }

    function handleCollectBNB(uint amount) public onlyCaller{
        if(address(this).balance >= minBNBToSwap){
            // swap BIB
            address[] memory path = new address[](2);
            path[0] = uniswapV2Router.WETH();
            path[1] = address(bibToken);

            uint balanceBefore = bibToken.balanceOf(address(this));

            // make the swap
            uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
                0, 
                path,
                address(this),
                block.timestamp
            );

            uint swapped = bibToken.balanceOf(address(this)).sub(balanceBefore);
            distribute(swapped);
        }
        
        emit HandleCollect(msg.sender, TokenType.TOKEN_TYPE_BNB, amount);
    }
}