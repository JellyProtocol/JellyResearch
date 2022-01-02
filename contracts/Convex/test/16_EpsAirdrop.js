const { BN, constants, expectEvent, expectRevert, time } = require('openzeppelin-test-helpers');
const fs = require('fs');
const MerkleTree = require('./helpers/merkleTree');
var jsonfile = require('jsonfile');

var droplist = jsonfile.readFileSync('../airdrop/eps/2021_9_16/drop_proofs.json');
var contractList = jsonfile.readFileSync('./contracts.json');

const IERC20 = artifacts.require("IERC20");
const MerkleAirdrop = artifacts.require("MerkleAirdrop");
const MerkleAirdropFactory = artifacts.require("MerkleAirdropFactory");

const Multicaller = artifacts.require("Multicaller");
const MulticallerView = artifacts.require("MulticallerView");

const progressFile = "drop_progress.json";
if (fs.existsSync(progressFile)) {
    drop_progress = jsonfile.readFileSync(progressFile);
} else {
    drop_progress = {
        progress: 0
    };
}

contract("Airdrop Test", async accounts => {
  it("should claim airdrop for all users", async () => {

    let deployer = "0x947B7742C403f20e5FaCcDAc5E092C943E7D0277";
    var dropAddresses = Object.keys(droplist.users);
    //system    
    let eps = await IERC20.at("0xA7f552078dcC247C2684336020c03648500C6d9F");
    let factory = await MerkleAirdropFactory.at("0xF403C135812408BFbE8713b5A23a04b3D48AAE31");
    //await factory.CreateMerkleAirdrop();
    //return;

    // let airdrop = await MerkleAirdrop.at("0x5F863EDFB62575fe3A838C2afB4919dEd7b511D9");//week 1
    // let airdrop = await MerkleAirdrop.at("0x48389D205Ae9B345C34B1048407fEfa848DfC06F");//week 2
    // let airdrop = await MerkleAirdrop.at("0x43144b4Fc9539DEe891127B8A608d2090C92caa7");//week 3
    // let airdrop = await MerkleAirdrop.at("0x23377628Cb549cbfeb9138d4aE70751cF67C44F4");//week 4
    // let airdrop = await MerkleAirdrop.at("0xE09ebF1Cb830D6c334b7Ab973e04Ba2d84B77043");//week 5
    // let airdrop = await MerkleAirdrop.at("0x58e330559998e93De19032066be8DbAB3E1e8c4a");//week 6
    // let airdrop = await MerkleAirdrop.at("0xf140b370Ae1238Add424d3F9B7ED409dAdB7E238");//week 7
    // let airdrop = await MerkleAirdrop.at("0x81E47381aA927ffA2138263e50716B1C573B0Eb5");//week 8
    // let airdrop = await MerkleAirdrop.at("0xc789F8fc2dD7D14DFFEA9e3D7e78BDe43ea9F439");//week 9
    // let airdrop = await MerkleAirdrop.at("0xA0f7B26ccDc490ef9E5CedB7e956351aA4bE5B1B");//week 10
    // let airdrop = await MerkleAirdrop.at("0xcbCa4Cd79aF621184DDc14CDC6C43E37Db780470");//week 11
    // let airdrop = await MerkleAirdrop.at("0xA988E0B94F0b187474ff45D7ca9F1ecbe80824E7");//week 12
    // let airdrop = await MerkleAirdrop.at("0x4BF0172272470125486CEaD15718f9B7B5185E02");//week 13
    // let airdrop = await MerkleAirdrop.at("0x37a0f7cac3b4AaDFc4347cCd4c890604AC3DAfDa");//week 14
    // let airdrop = await MerkleAirdrop.at("0x3d7F3140aCc4176cf510008A5773a7Be7cDe0fBA");//week 15
    // let airdrop = await MerkleAirdrop.at("0x0d59D439a4466Ef2b22d50d11eABcCbd54f42052");//week 16
    // let airdrop = await MerkleAirdrop.at("0x37E18aaB177E169dAA33D24F26b8ab3A6ccf0c0e");//week 17
    let airdrop = await MerkleAirdrop.at("0x1639f30b195d25b254Cc128Ac9d864707D30Df00");//week 18
    console.log("airdrop at: " +airdrop.address);

    // //set reward token
    await airdrop.setRewardToken(eps.address,{from:deployer});

    // //transfer eps
    var epsbalance = await eps.balanceOf(deployer);
    await eps.transfer(airdrop.address,epsbalance,{from:deployer});
    epsbalance = await eps.balanceOf(airdrop.address);
    console.log("eps drop total: " +epsbalance);
    var total = new BN(0);
    for(var i = 0; i < dropAddresses.length; i++){
        var userAmount = droplist.users[dropAddresses[i]].amount;
        total = total.add(new BN(userAmount.toString()));
    }
    console.log("total from drop data: " +total.toString());
    assert.equal(epsbalance.toString(),total.toString(),"address balance and drop data balance dont match");
    
    //set merkle root
    await airdrop.setRoot(droplist.root,{from:deployer})
    let mroot = await airdrop.merkleRoot();
    console.log("airdrop root: " +mroot);

    return;

    let multicaller = await Multicaller.at("0x1Ee38d535d541c55C9dae27B12edf090C608E6Fb");
    let multicallerview = await MulticallerView.at("0x1Ee38d535d541c55C9dae27B12edf090C608E6Fb");

    //get balances
    

    //claiming
    console.log("claiming for " +dropAddresses.length +" users");
    var beforecallDataList = [];
    var callDataList = [];
    var aftercallDataList = [];
    var claimcount = 0;
    var claimsize = 20;
    for(var i = drop_progress.progress; i < dropAddresses.length; i++){
        var info = droplist.users[dropAddresses[i]];
        var amount = info.amount;
        var proof = info.proof;
        proof = proof.map(e=>Buffer.from(e,'hex'));

       // console.log("claiming " +i +" amount: " +amount +"  user: " +dropAddresses[i]);
        // await airdrop.claim(proof,dropAddresses[i],amount);
        // console.log("claimed " +i);
        var balancecalldata = eps.contract.methods.balanceOf(dropAddresses[i]).encodeABI();
        var calldata = airdrop.contract.methods.claim(proof,dropAddresses[i],amount).encodeABI();
        beforecallDataList.push([eps.address,balancecalldata]);
        callDataList.push([airdrop.address,calldata]);
        aftercallDataList.push([eps.address,balancecalldata]);

        if(callDataList.length == claimsize){
            claimcount++;
            console.log("call multi claim " +(i-claimsize+1) +"~" +(i));

            var beforeUserbalances = [];
            var afterUserbalances = [];
            let retData = await multicallerview.aggregate(beforecallDataList);
            
            for(var d = 0; d < retData[1].length; d++){
                //console.log("add balance bn2: " +web3.utils.toBN(retData[1][d]).toString());
                beforeUserbalances.push(web3.utils.toBN(retData[1][d]).toString());
            }
            await multicaller.aggregate(callDataList);
            let retDataAfter = await multicallerview.aggregate(aftercallDataList);
            for(var d = 0; d < retDataAfter[1].length; d++){
                //console.log("add balance bn2: " +web3.utils.toBN(retDataAfter[1][d]).toString());
                afterUserbalances.push(web3.utils.toBN(retDataAfter[1][d]).toString());
            }
            for(var x = 0; x < beforeUserbalances.length; x++){
                var claimedAmount = new BN(afterUserbalances[x]).sub(new BN(beforeUserbalances[x]))
                var info = droplist.users[dropAddresses[i-claimsize+1+x]];
                var amount = info.amount;
                //console.log("assert: " +claimedAmount.toString() +" == " +amount.toString())
                assert.equal(claimedAmount.toString(),amount.toString(),"claimed amount doesnt match");
            }

            drop_progress.progress = i+1;
            jsonfile.writeFileSync(progressFile, drop_progress, { spaces: 4 });
            beforecallDataList = [];
            callDataList = [];
            aftercallDataList = [];
        }
    }
    if(callDataList.length > 0){
        console.log("call multi claim final " +(dropAddresses.length-callDataList.length) +"~" +(dropAddresses.length) );
        // await multicaller.aggregate(callDataList);

        var beforeUserbalances = [];
        var afterUserbalances = [];
        let retData = await multicallerview.aggregate(beforecallDataList);
        for(var d = 0; d < retData[1].length; d++){
            //console.log("add balance bn2: " +web3.utils.toBN(retData[1][d]).toString());
            beforeUserbalances.push(web3.utils.toBN(retData[1][d]).toString());
        }
        await multicaller.aggregate(callDataList);
        let retDataAfter = await multicallerview.aggregate(aftercallDataList);
        for(var d = 0; d < retDataAfter[1].length; d++){
            //console.log("add balance bn2: " +web3.utils.toBN(retDataAfter[1][d]).toString());
            afterUserbalances.push(web3.utils.toBN(retDataAfter[1][d]).toString());
        }
        for(var x = 0; x < beforeUserbalances.length; x++){
            var claimedAmount = new BN(afterUserbalances[x]).sub(new BN(beforeUserbalances[x]))
            var info = droplist.users[dropAddresses[ dropAddresses.length-callDataList.length+x]];
            var amount = info.amount;
            // console.log("assert: " +claimedAmount.toString() +" == " +amount.toString())
            assert.equal(claimedAmount.toString(),amount.toString(),"claimed amount doesnt match");
        }
        beforecallDataList = [];
        callDataList = [];
        aftercallDataList = [];
    }


  });
});


