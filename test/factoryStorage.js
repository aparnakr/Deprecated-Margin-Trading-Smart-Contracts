const assert = require('assert')
import {web3, util} from './init.js';
import expect from 'expect.js';

const FactoryStorage = artifacts.require('./FactoryStorage.sol')
const FactoryLogic = artifacts.require('./FactoryLogic.sol')

let factoryStorageInstance;
let factoryLogicInstance;

contract('FactoryStorage', (accounts) => {

    beforeEach(async () => {
        //TODO: fix this, we don't want to deploy every time!
        factoryStorageInstance = await FactoryStorage.deployed();
    });

    it('ownerAddress[0] should be msg.sender', async () => {
        var sender = await factoryStorageInstance.ownerAddresses(0);
        expect(web3.toChecksumAddress(sender)).to.be(web3.toChecksumAddress(accounts[0]));
    })

    it('ownerAddress[1] and [2] should be assigned correctly', async () => {
        var owner1 = await factoryStorageInstance.ownerAddresses(1);
        var owner2 = await factoryStorageInstance.ownerAddresses(2);
        expect(web3.toChecksumAddress(owner1)).to.be(web3.toChecksumAddress(accounts[1]));
        expect(web3.toChecksumAddress(owner2)).to.be(web3.toChecksumAddress(accounts[2]));
    })
    //
    // it('ownerAddress[1] and [2] should be assigned correctly', async () => {
    //     var owner1 = await factoryStorageInstance.setFactoryLogicAddress();
    //     var owner2 = await factoryStorageInstance.ownerAddresses(2);
    //     expect(web3.toChecksumAddress(owner1)).to.be(web3.toChecksumAddress(accounts[1]));
    //     expect(web3.toChecksumAddress(owner2)).to.be(web3.toChecksumAddress(accounts[2]));
    // })
});

contract('FactoryLogic', (accounts) => {
    beforeEach(async () => {
        //TODO: fix this, we don't want to deploy every time!
        factoryLogicInstance = await FactoryLogic.deployed(factoryStorageInstance.address());
    });

    // it('owner should be msg.sender', async () => {
    //     var sender = await factoryLogicInstance.owner();
    //     expect(web3.toChecksumAddress(sender)).to.be(web3.toChecksumAddress(accounts[0]));
    // })
});
