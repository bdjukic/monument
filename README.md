1. Creating Ethereum account with some Ether. Make sure password.txt file is created. 

geth --datadir ~/Projects/monument/blockchain --password ~/Projects/monument/blockchain/password.txt account new > account1.txt

geth --datadir ~/Projects/monument/blockchain --password ~/Projects/monument/blockchain/password.txt account new > account2.txt

2. Copy account IDs from account1.txt and account2.txt into genesis.json

3. Inititate blockchain

geth --datadir ~/Projects/monument/blockchain init ~/Projects/monument/blockchain/genesis.json

4. Run ether node

geth --datadir ~/Projects/monument/blockchain/ --ipcpath /home/bogdan/Projects/monument/blockchain/geth.ipc --rpc --rpcapi "eth,net,web3,personal" --rpcaddr="127.0.0.1" --rpcport="8545" --rpccorsdomain="*" --unlock 0xe6fc6e050b39706a40d2d89e15bcd9129fd2b93a --password '/home/bogdan/Projects/monument/blockchain/password.txt'

4. Run wallet

'/opt/Ethereum Wallet/ethereumwallet' --rpc http://127.0.0.1:8545

5. Mining

geth attach ipc:/home/bogdan/Projects/monument/blockchain/geth.ipc

miner.start()
miner.stop()

6. Setting up IPFS:

ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Origin '["*"]'

7. Running IPFS daemon

ipfs daemon