import { Provider, Wallet, Contract, BaseAssetId } from "fuels";
import abi from "./abi.json" with { type: "json" };
 
const provider = await Provider.create('https://beta-5.fuel.network/graphql');
const wallet = Wallet.fromPrivateKey('PRIVATE_KEY', provider); // private key with coins
const contractId = "CONTRACT_ADDRESS";
const contract = new Contract(contractId, abi, wallet);

const amountToForward = 10;
 
// All contract methods are available under functions
// const result = await contract.functions
//   .constructor({
//     "Address": {
//         "value": "ADMIN_WALLET"
//     }
// }, 3600)
//   .callParams({
//     forward: [amountToForward, BaseAssetId],
//   })
//   .call();

const result = await contract.functions
  .claim(1, {
    "Address": {
        "value": "WALLET_THAT_CLAIMS_AIRDROP"
    }
})	
  .call();

// const result = await contract.functions
//   .clawback()
//   .call();
 
console.log(result);
