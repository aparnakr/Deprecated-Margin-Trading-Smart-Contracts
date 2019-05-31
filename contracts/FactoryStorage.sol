pragma solidity ^0.5.8;

contract FactoryStorage {

    //     userAddr => shortRepAddr
        mapping (address => address) public REP;
    //    mapping (address => address) public ZRX;

////    struct Trade? {
////        address exchangeContract?;
////        address xyz;
////    }
////TODO: think about - using SafeMath for uint;
////TODO: add events
////uint256 public constant DECIMALS = 18;
//
    address public factoryLogicAddress;
//
//    //TODO: is the following how you declare arrays properly?
    address[3] public ownerAddresses;
    address[] public userAddresses;
//    address[] public tokenAddresses;
//    //TODO: figure out camelcase for the following
//    address[] public ctokenAddresses;
//    address[] public exchangeAddresses;

    constructor(address owner1, address owner2) public {
        ownerAddresses[0] = msg.sender;
        ownerAddresses[1] = owner1;
        ownerAddresses[2] = owner2;
    }
//
//    //TODO: write explainer on the following mapping
//    mapping(bytes32 => mapping (address => address)) public positionContractAddresses;
//
//    // userAddr => shortRepAddr
//    mapping (address => address) public REP;
//    mapping (address => address) public ZRX;
//
    function setFactoryLogicAddress(address newAddress) public {
        require(ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);
        //TODO: better security practices required than the above
        factoryLogicAddress = newAddress;
    }
//
////    // returns "REP1, "REP2 ..."
////    function getPositionNames () {}
////
////    // All the Set and Add functions can only be called by the factory logic? contract
////    function updateUserAddress(i, val){}
//
    function addUser(address newAddress) public {
//        TODO: this is correct: require(factoryLogicAddress == msg.sender);
        require(ownerAddresses[0] == msg.sender || ownerAddresses[1] == msg.sender || ownerAddresses[2] == msg.sender);

        userAddresses.push(newAddress);
    }

    function addNewREPPosContAddress(address caller, address newPositionContractAddress) public {
        require(factoryLogicAddress == msg.sender);
        REP[caller] = newPositionContractAddress;
    }


//
//    function addTokenAddress(address newAddress) public {
//        require(factoryLogicAddress == msg.sender);
//        tokenAddresses.push(newAddress);
//    }
//
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
//    function addNewPositionContract(uint256 positionIndex, address userAddress, address contractAddress) public {
//    // ensure position key Exists first at that index
//    }
}