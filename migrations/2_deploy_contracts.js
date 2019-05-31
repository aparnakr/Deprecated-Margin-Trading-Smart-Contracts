var FactoryStorage = artifacts.require("./FactoryStorage.sol");
require('web3')

module.exports = function(deployer, network, accounts) {
    deployer.deploy(FactoryStorage, accounts[1],accounts[2]);
    deployer.link(FactoryStorage, FactoryLogic);
    deployer.deploy(FactoryLogic(FactoryStorage));
}