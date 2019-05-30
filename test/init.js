const Util = require('./utils/util.js');
const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8546'))
const util = new Util(web3);

module.exports = { web3, util} ;
