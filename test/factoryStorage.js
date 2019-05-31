const assert = require('assert')
import {web3, util} from './init.js';
import expect from 'expect.js';

const FactoryStorage = artifacts.require('./FactoryStorage.sol')
let factoryStorageInstance;

contract('FactoryStorage', (accounts) => {

    beforeEach(async () => {
        //TODO: fix this, we don't want to deploy every time!
        factoryStorageInstance = await FactoryStorage.deployed();
    });

    it('should deploy FactoryStorage successfully', async () => {
        // var sender = await factoryStorageInstance.ownerAddresses;
        // console.log(await sender(0))
        // console.log(await sender.call(0))
        // console.log(await sender.call(0))

        var sender = await factoryStorageInstance.getOwner();
        expect(sender).to.be(web3.eth.accounts[0]);
        // const newAddedTodo = await contractInstance.todos(accounts[0], 0)
        // const todoContent = web3.toUtf8(newAddedTodo[1])

    })
});
