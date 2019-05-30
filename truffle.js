require("babel-register");
require("babel-polyfill");
require("web3")

module.exports = {
    networks: {
        development: {
            host: "localhost",
            port: 8545,
            network_id: "*" // Match any network id
        },
        rinkeby: {
            host: "localhost",
            port: 8546,
            //from: '0xdbe43ce89c6317c7e64357aef6fc57318c3af0e2',
            network_id: "*",
            gas: 3000000,

        } ,
        mainnet: {
            host: "localhost",
            port: 8546,
            //from: '0xdbe43ce89c6317c7e64357aef6fc57318c3af0e2',
            from: web3.eth.accounts[0],
            network_id: "*",//ensure it's the right network!
            gas: 3000000,

        }
    }
};
