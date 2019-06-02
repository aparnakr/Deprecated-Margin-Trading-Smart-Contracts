module.exports = {
    NewRep(params) {
        return {
            event: 'NewRep',
            args: {
                sender: params.sender,
                caller: params.caller,
                newPositionContractAddress: params.newPositionContractAddress,
                factoryLogicAddress: params.factoryLogicAddress,
            }
        }
    },
};
