pragma solidity ^0.5.2;
import {positionContract} from "./positionContract.sol";
import {CErc20, ComptrollerInterface, CToken} from "./CERC20.sol";
import {CEther} from "./CEther.sol";
import {UniswapExchangeInterface} from "./uniswap.sol";
import {ERC20Interface} from "./ERC20.sol";
import {FactoryStorage} from "./FactoryStorage.sol";

contract Factory{
//    mapping (uint => address) public tokenAddresses;
//    mapping (uint => address) public ctokenAddresses;
//    mapping (uint => address) public tokenExchangeAddresses;
    
    // userAddr => shortRepAddr
//    mapping (address => address) public REP;
//    mapping (address => address) public ZRX;

    address owner;

    FactoryStorage factoryStorageContract;

    //TODO: change the constructor for future versions.
    constructor(address factoryStorageContractAddress) public {
        owner = msg.sender;
        factoryStorageContract = FactoryStorage(factoryStorageContractAddress);
    }
    
    function openShortERC20(string token) public {
        //TODO: should be require right not if statement so there's no wasted gas!
        //(get the propper mapping!)
        mapping (address => address) REP;
        REP = factoryStorageContract.REP;
        if(REP[msg.sender] == address(0x0)) {
            positionContract s = new positionContract(
                msg.sender,
                "REP",
                factoryStorageContract.tokenAddresses(0),
                factoryStorageContract.ctokenAddresses(0),
                factoryStorageContract.tokenExchangeAddresses[0],
                factoryStorageContract.tokenAddresses[3],
                factoryStorageContract.ctokenAddresses[3],
                factoryStorageContract.tokenExchangeAddresses[3],
                "s"
            );
            REP[msg.sender] = address(s);
        }
    }
    
    function openShortETH() public {
        if(ZRX[msg.sender] == address(0x0)) {
            positionContract s = new positionContract(msg.sender, "ZRX", tokenAddresses[0], ctokenAddresses[0], tokenExchangeAddresses[0], tokenAddresses[2],  ctokenAddresses[2], tokenExchangeAddresses[2], "s");
            ZRX[msg.sender] = address(s);
        }
    }
    
    function openLongERC20(string token) public {
        if(REP[msg.sender] == address(0x0)) {
            positionContract s = new positionContract(msg.sender, "REP", tokenAddresses[3], ctokenAddresses[3], tokenExchangeAddresses[3], tokenAddresses[0],  ctokenAddresses[0], tokenExchangeAddresses[0], "l");
            REP[msg.sender] = address(s);
        }
    }
    
    function openLongETH(string token) public {
        if(ZRX[msg.sender] == address(0x0)) {
            positionContract s = new positionContract(msg.sender, "ZRX", tokenAddresses[2], ctokenAddresses[2], tokenExchangeAddresses[2], tokenAddresses[0],  ctokenAddresses[0], tokenExchangeAddresses[0], "l");
            ZRX[msg.sender] = address(s);
        }
    }
}