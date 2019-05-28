pragma solidity ^0.4.0;

contract FactoryStorage {
    mapping (uint => address) public tokenAddresses;
    mapping (uint => address) public ctokenAddresses;
    mapping (uint => address) public tokenExchangeAddresses;

    // userAddr => shortRepAddr
    mapping (address => address) public REP;
    mapping (address => address) public ZRX;


    function FactoryStorage(){

    }


}
