const assert = require('assert')
import {web3, util} from './init.js';
import expect from 'expect.js';
import {NewRep} from './utils/FactoryEvents.js'

const FactoryStorage = artifacts.require('./FactoryStorage.sol')
const FactoryLogic = artifacts.require('./FactoryLogic.sol')

let factoryStorageInstance;
let factoryLogicInstance;

contract('FactoryStorage', (accounts) => {

    beforeEach(async () => {
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
    // it('others shouldn't be able to mess things up', async () => {
    //     var owner1 = await factoryStorageInstance.setFactoryLogicAddress();
    //     var owner2 = await factoryStorageInstance.ownerAddresses(2);
    //     expect(web3.toChecksumAddress(owner1)).to.be(web3.toChecksumAddress(accounts[1]));
    //     expect(web3.toChecksumAddress(owner2)).to.be(web3.toChecksumAddress(accounts[2]));
    // })
});

contract('FactoryLogic', (accounts) => {
    beforeEach(async () => {
        factoryLogicInstance = await FactoryLogic.deployed();
    });

    it('var factoryStorageContract should be correct contract', async () => {
        var contract = await factoryLogicInstance.factoryStorageContract();
        expect(contract).to.be(factoryStorageInstance.address);
    });
});


contract('FactoryStorage2', (accounts) => {
    beforeEach(async () => {
        factoryLogicInstance = await FactoryLogic.deployed();
        factoryStorageInstance = await FactoryStorage.deployed()
    });

    it('setFactoryLogicAddress should work to store correct contract', async () => {
        //TODO: write a function ensuring no one else can call this!
        await factoryStorageInstance.setFactoryLogicAddress(factoryLogicInstance.address);
        var factoryLogicAddress = await factoryStorageInstance.factoryLogicAddress();
        expect(factoryLogicAddress).to.be(factoryLogicInstance.address);
    });

    it('should work if owner1 or owner2 try to setFactoryLogicAddress', async () => {
        await factoryStorageInstance.setFactoryLogicAddress(factoryLogicInstance.address, { from: accounts[1] });
        var factoryLogicAddress = await factoryStorageInstance.factoryLogicAddress();
        expect(factoryLogicAddress).to.be(factoryLogicInstance.address);

        await factoryStorageInstance.setFactoryLogicAddress(factoryLogicInstance.address, { from: accounts[2] });
        var factoryLogicAddress1 = await factoryStorageInstance.factoryLogicAddress();
        expect(factoryLogicAddress1).to.be(factoryLogicInstance.address);
    });

    it('should throw if non owner tries to setFactoryLogicAddress', async () => {
        try {
            await factoryStorageInstance.setFactoryLogicAddress(factoryLogicInstance.address, { from: accounts[3] });
            //TODO: what is the value of the next line?
            expect().fail("should throw error");
        } catch (err) {
            // console.log(err)
            util.assertFailedRequire(err);
        }
    });

    it('adding User should work from accounts[0]', async () => {
        //TODO: write a function ensuring no one else can call this!
        await factoryStorageInstance.addUser(accounts[1]);
        var userAddress0 = await factoryStorageInstance.userAddresses(0);
        expect(userAddress0).to.be(accounts[1]);
    });

    it('should work if owner1 or owner2 try to addUser', async () => {
        await factoryStorageInstance.addUser(accounts[3], { from: accounts[1] });
        var userAddress1 = await factoryStorageInstance.userAddresses(1);
        expect(userAddress1).to.be(accounts[3]);

        await factoryStorageInstance.addUser(accounts[4], { from: accounts[2] });
        var userAddress2 = await factoryStorageInstance.userAddresses(2);
        expect(userAddress2).to.be(accounts[4]);
    });

    it('should throw if non owner tries to addUser', async () => {
        try {
            await factoryStorageInstance.addUser(accounts[0], { from: accounts[3] });
            expect().fail("should throw error");
        } catch (err) {
            // console.log(err)
            util.assertFailedRequire(err);
        }
    });

    it('opencontract functions short should work', async () => {
        const result = await factoryLogicInstance.openERC20Contract('REP', true);
        // console.log(factoryLogicInstance.address)
        // console.log(accounts[0])
        // console.log(await factoryStorageInstance.positionContracts('REP',accounts[0]))


        // const result1 = await factoryLogicInstance.openContractZRX();
        // console.log(factoryLogicInstance.address)
        // console.log(accounts[0])
        // console.log(await factoryStorageInstance.ZRX(accounts[0]))
        // // console.log(factoryLogicInstance.address)
        // var event = await factoryStorageInstance.NewPositionContract({sender});


        // console.log(event)
        // console.log(result)
        // var event = await factoryStorageInstance.NewRep({sender, caller, newPositionContractAddress, factoryLogicAddress});

        // watch for changes
        // event.watch(function(error, result){
        //     if (!error) {
        //         console.log(result);
        //     } else {
        //         console.error(error);
        //     }});

        //TODO: add event listening.
        // var repContract = await factoryStorageInstance.REP(0);
        // console.log(repContract);

        // util.assertEventEquality(event.logs[0], NewRep({
        //     sender: factoryLogicInstance,
        //     caller: accounts[0],
        //     newPositionContractAddress: '0x0',
        //     factoryLogicAddress: factoryLogicInstance,
        // }))
    });
});

contract('FactoryLogic2', (accounts) => {
    // beforeEach(async () => {
    //     factoryLogicInstance = await FactoryLogic.deployed();
    //     factoryStorageInstance = await FactoryStorage.deployed()
    // });
});



