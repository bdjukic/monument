## Prerequisites

1.Creating Ethereum accounts with some Ether. Make sure `password.txt` file is created. 

`geth --datadir ~/Projects/monument/blockchain --password ~/Projects/monument/blockchain/password.txt account new > account.txt`


2. Copy account ID from `account.txt` into `genesis.json`

3. Inititate Ethereum blockchain

`geth --datadir ~/Projects/monument/blockchain init ~/Projects/monument/blockchain/genesis.json`

4. Run Ethereum node

```geth --datadir ~/Projects/monument/blockchain/ --ipcpath /home/bogdan/Projects/monument/blockchain/geth.ipc --rpc --rpcapi "eth,net,web3,personal" --rpcaddr="127.0.0.1" --rpcport="8545" --rpccorsdomain="*" --unlock 0xe6fc6e050b39706a40d2d89e15bcd9129fd2b93a --password '/home/bogdan/Projects/monument/blockchain/password.txt'```

4. Run wallet

`'/opt/Ethereum Wallet/ethereumwallet' --rpc http://127.0.0.1:8545`

5. Kick off mining

`geth attach ipc:/home/bogdan/Projects/monument/blockchain/geth.ipc`

`miner.start()`
`miner.stop()`

6. Set up IPFS

`ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'`
`ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Origin '["*"]'`

7. Run IPFS daemon

`ipfs daemon`