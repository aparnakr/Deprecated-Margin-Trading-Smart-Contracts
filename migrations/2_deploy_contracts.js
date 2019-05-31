var FactoryStorage = artifacts.require("./FactoryStorage.sol");

module.exports = function(deployer) {
    deployer.deploy(FactoryStorage);
}