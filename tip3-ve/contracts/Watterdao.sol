pragma ever-solidity >= 0.61.2;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "tip3/contracts/interfaces/IAcceptTokensTransferCallback.sol";
import "tip3/contracts/interfaces/ITokenRoot.sol";
import "tip3/contracts/interfaces/ITokenWallet.sol";

contract Watterdao {
    uint16  static _nonce; // Some random value to affect on contract address
    address static _owner; // Watterdao owner. Will receive all transfers

    address public _distributedTokenRoot; // TIP3 TokenRoot address for deploying wallet for Watterdao. This token will be distributed
    address public _distributedTokenWallet; // TIP3 wallet for Watterdao for sending purchased tokens
    uint256 public _supply; // How much tokens will be distributed (with decimals)
    uint128 public _rate; // How much tokens buyer will receive for 1 nanovenom (1*10^9)

    constructor(
        address distributedTokenRoot,
        uint256 supply,
        uint128 rate,
        address sendRemainingGasTo
    ) public {
        tvm.accept(); // This action is required to process external messages that bring no value - deploy as we have.
        tvm.rawReserve(1 ever, 0); // we will always reserve 1 venom on this contract
        _distributedTokenRoot = distributedTokenRoot;
        _rate = rate;
        _supply = supply;

        // fundamental mechanic of dapps working with tip3 - deploy it's own wallet to operate with. check tip3 specs for more info
        ITokenRoot(distributedTokenRoot).deployWallet {
            value: 0.2 ever,
            flag: 1,
            callback: Watterdao.onTokenWallet // this callback will be called by TokenRoot after deploying wallet for Watterdao
        } (
            address(this),
            0.1 ever
        );
        // sending remaining gas after setups
        sendRemainingGasTo.transfer({ value: 0, flag: 128, bounce: false });

        function onTokenWallet(address value) external {
            require (
                msg.sender.value != 0 &&
                msg.sender == _distributedTokenRoot, // check, that calling was from TokenRoot we need
                101 // some error code for this require
            );
            tvm.rawReserve(1 ever, 0);
            _distributedTokenWallet = value; // store deployed tip3 wallet address
            _owner.transfer({ value: 0, flag: 128, bounce: false }); // sending remaining gas after setups
        }

        function buyTokens(uint128 deposit) external view {
            tvm.rawReserve(1 ever, 0);
            // 1 venom is a technical value for fee...remaining gas will be returned after tokens transfer (from tip3 wallet)
            if (deposit > msg.value + 1 ever) { // if we using require, we are frozing incoming value in this contract, so just return it 
                msg.sender.transfer({ value: 0, flag: 128, bounce: false });
            } else {
                uint128 purchase = _rate * deposit;
                if (purchase > _supply) {
                    msg.sender.transfer({ value: 0, flag: 128, bounce: false});
                } else {
                    TvmCell empty;
                    // here we just operate with deployed in constructor wallet. owner should provide token supply on this wallet before sales!
                    ITokenWallet(_distributedTokenWallet).transfer{ value: 0, flag: 128 }(
                        purchase,
                        msg.sender,
                        0.1 ever, // this parameter allows to deploy wallet for user, if it's not deployed yet. (fee takes from message so will be payed by user)
                        msg.sender,
                        false,
                        empty
                    );
                }
            }
        }
    }

}