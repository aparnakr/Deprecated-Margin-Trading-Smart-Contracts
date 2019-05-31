require("babel-register");
require("babel-polyfill");

module.exports = {
    networks: {
        development: {
            host: "localhost",
            port: 8545,
            network_id: "*", // Match any network id
            gas: 3000000,
        },
        // mainnet: {
        //     host: "localhost",
        //     port: 8545,
        //     //from: '0xdbe43ce89c6317c7e64357aef6fc57318c3af0e2',
        //     network_id: 4,
        //     gas: 3000000,
        // }
    }
};
