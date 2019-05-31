var FactoryStorage = artifacts.require("./FactoryStorage.sol");
var FactoryLogic = artifacts.require("./FactoryLogic.sol");

require('web3');

module.exports = function(deployer, network, accounts) {
    deployer.deploy(FactoryStorage, accounts[1], accounts[2]).then(function () {
        return deployer.link(FactoryStorage, FactoryLogic);
    }).then(function () {
        return deployer.deploy(FactoryLogic, FactoryStorage.address);
    });
};