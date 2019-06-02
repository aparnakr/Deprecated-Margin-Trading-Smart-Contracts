pragma solidity ^0.5.8;

contract FactoryStorage {

    event NewPositionContract(
        address userAddress,
        address newPositionContractAddress,
        address factoryLogicAddress
    );

        //ticker => userAddr => shortRepAddr
        //e.g. ticker = 'REP'
        mapping (string => mapping (address => address)) public positionContracts;

//    struct Trade? {
//        address exchangeContract?;
//        address xyz;
//    }
//TODO: think about - using SafeMath for uint;
//TODO: add events
//uint256 public constant DECIMALS = 18;

    address public factoryLogicAddress;

    address[3] public ownerAddresses;
    address[] public userAddresses;
    address[] public tokenAddresses;
    //TODO: figure out camelcase for the following
    address[] public ctokenAddresses;
    address[] public exchangeAddresses;

    constructor(address owner1, address owner2) public {
        ownerAddresses[0] = msg.sender;
        ownerAddresses[1] = owner1;
        ownerAddresses[2] = owner2;

        // DAI addr
        tokenAddresses.push(0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa);
        // BAT
        // no liquidity on this.
        tokenAddresses.push(0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99);
        // ZRX
        tokenAddresses.push(0xddea378A6dDC8AfeC82C36E9b0078826bf9e68B6);
        // REP
        tokenAddresses.push(0x6e894660985207feb7cf89Faf048998c71E8EE89);

        ctokenAddresses.push(0x2ACC448d73e8D53076731fEA2EF3fc38214d0A7d);
        ctokenAddresses.push(0x1Cae2a350AF04cD2525Aee6Cc8397e03f50C1Af4);
        ctokenAddresses.push(0x961aA80B6B44D445387Aa8395c4c6C1a473F4ffD);
        ctokenAddresses.push(0x1c8F7Aca3564c02d1Bf58EbA8571b6fdAfe91f44);
        ctokenAddresses.push(0xbED6D9490a7CD81fF0F06f29189160a9641a358F);

        exchangeAddresses.push(0xaF51BaAA766b65E8B3Ee0C2c33186325ED01eBD5);
        exchangeAddresses.push(0x5cEDbFc1C6041Df417173Aa552040D79f09d631c);
        exchangeAddresses.push(0x4dCF4017ffbffABB4F8f8378d6c53286590d4625);
        exchangeAddresses.push(0x67B67cb021a956D1956884B99cE2FB7dc835a080);
    }

//    //TODO: write explainer on the following mapping
//    mapping(bytes32 => mapping (address => address)) public positionContractAddresses;
//
//    // userAddr => shortRepAddr
//    mapping (address => address) public REP;
//    mapping (address => address) public ZRX;

    function setFactoryLogicAddress(address newAddress) public {
        require(ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        //TODO: better security practices required than the above
        factoryLogicAddress = newAddress;
    }

//    // returns "REP1, "REP2 ..."
//    function getPositionNames () {}
//
//    // All the Set and Add functions can only be called by the factory logic? contract
//    function updateUserAddress(i, val){}

    function addUser(address newAddress) public {
//        TODO: this is correct: require(factoryLogicAddress == msg.sender);
        //TODO: THE FOLLOWING ALSO LEAVES US VULNERABLE: THE WHOLE SYSTEM GOES DOWN IF EVEN ONE KEY IS TAKEN
        require(ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        userAddresses.push(newAddress);
    }

    function addTokenAddress(address newAddress) public {
        require(factoryLogicAddress == msg.sender);
        tokenAddresses.push(newAddress);
    }

//    function updateTokenAddress(uint256 index, address newAddress) public {
//        require(factoryLogicAddress == msg.sender);
//        tokenAddresses[index] = newAddress;
//    }
//
//    function addcTokenAddress(address newAddress) public {
//        require(factoryLogicAddress == msg.sender);
//        ctokenAddresses.push(newAddress);
//    }
//
//    function updatecTokenAddress(uint256 index, address newAddress) public {
//        require(factoryLogicAddress == msg.sender);
//        ctokenAddresses[index] = newAddress;
//    }
//
//    function addExchangeAddress(address newAddress) public {
//        require(factoryLogicAddress == msg.sender);
//        exchangeAddresses.push(newAddress);
//    }
//
//    function updateExchangeAddress(uint256 index, address newAddress) public {
//        require(factoryLogicAddress == msg.sender);
//        exchangeAddresses[index] = newAddress;
//    }
//
////    function addPositionName(newKey) {
////        require(factoryLogicAddress == msg.sender);
////        exchangeAddresses[index] = newAddress;
////    }
//
//    function addNewTokenToPositionContracts (address tokenAddr, address cTokenAddr, address exchangeAddr, bytes32 positionKey) public {
//    }
//

//    function addNewREPPosContAddress(address caller, address newPositionContractAddress) public {
//        //        require(caller == msg.sender);
//
//    }

    function addNewPositionContract(string memory ticker, address userAddress, address newContractAddress) public {
        //TODO: ensure userAddress has been added and ticker is valid.
        require(factoryLogicAddress == msg.sender);
        positionContracts[ticker][userAddress] = newContractAddress;
        emit NewPositionContract(userAddress, newContractAddress, msg.sender);
    }
}