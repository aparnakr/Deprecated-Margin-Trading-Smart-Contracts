pragma solidity ^0.5.2;
import {positionContract} from "./positionContract.sol";
import {CErc20, ComptrollerInterface, CToken} from "./CERC20.sol";
import {CEther} from "./CEther.sol";
import {UniswapExchangeInterface} from "./uniswap.sol";
import {ERC20Interface} from "./ERC20.sol";

contract Factory{
    mapping (uint => address) public tokenAddresses;
    mapping (uint => address) public ctokenAddresses;
    mapping (uint => address) public tokenExchangeAddresses;
    
    // userAddr => shortRepAddr
    mapping (address => address) public REP;
    mapping (address => address) public ZRX;
    
    constructor() public {
    // DAI    
    tokenAddresses[0] = 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa;
    // BAT
    // no liquidity on this. 
    tokenAddresses[1] = 0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99;
    // ZRX
    tokenAddresses[2] = 0xddea378A6dDC8AfeC82C36E9b0078826bf9e68B6;
    // REP
    tokenAddresses[3] = 0x6e894660985207feb7cf89Faf048998c71E8EE89;
        
    ctokenAddresses[0] = 0x2ACC448d73e8D53076731fEA2EF3fc38214d0A7d;
    ctokenAddresses[1] = 0x1Cae2a350AF04cD2525Aee6Cc8397e03f50C1Af4;
    ctokenAddresses[2] = 0x961aA80B6B44D445387Aa8395c4c6C1a473F4ffD;
    ctokenAddresses[3] = 0x1c8F7Aca3564c02d1Bf58EbA8571b6fdAfe91f44;
    ctokenAddresses[4] = 0xbED6D9490a7CD81fF0F06f29189160a9641a358F;
    
    tokenExchangeAddresses[0] = 0xaF51BaAA766b65E8B3Ee0C2c33186325ED01eBD5;
    tokenExchangeAddresses[1] = 0x5cEDbFc1C6041Df417173Aa552040D79f09d631c;
    tokenExchangeAddresses[2] = 0x4dCF4017ffbffABB4F8f8378d6c53286590d4625;
    tokenExchangeAddresses[3] = 0x67B67cb021a956D1956884B99cE2FB7dc835a080;
     
    }
    
    function openShortREP() public {
        if(REP[msg.sender] == address(0x0)) {
            positionContract s = new positionContract(msg.sender, "REP", tokenAddresses[0], ctokenAddresses[0], tokenExchangeAddresses[0], tokenAddresses[3],  ctokenAddresses[3], tokenExchangeAddresses[3], "s");
            REP[msg.sender] = address(s);
        }
        
    }
    
    function openShortZRX() public {
        if(ZRX[msg.sender] == address(0x0)) {
            positionContract s = new positionContract(msg.sender, "ZRX", tokenAddresses[0], ctokenAddresses[0], tokenExchangeAddresses[0], tokenAddresses[2],  ctokenAddresses[2], tokenExchangeAddresses[2], "s");
            ZRX[msg.sender] = address(s);
        }
        
    }
    
    function openLongREP() public {
        if(REP[msg.sender] == address(0x0)) {
            positionContract s = new positionContract(msg.sender, "REP", tokenAddresses[3], ctokenAddresses[3], tokenExchangeAddresses[3], tokenAddresses[0],  ctokenAddresses[0], tokenExchangeAddresses[0], "l");
            REP[msg.sender] = address(s);
        }
    }
    
    function openLongZRX() public {
        if(ZRX[msg.sender] == address(0x0)) {
            positionContract s = new positionContract(msg.sender, "ZRX", tokenAddresses[2], ctokenAddresses[2], tokenExchangeAddresses[2], tokenAddresses[0],  ctokenAddresses[0], tokenExchangeAddresses[0], "l");
            ZRX[msg.sender] = address(s);
        }
    }
    
}
