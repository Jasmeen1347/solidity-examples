// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract Lottery is VRFConsumerBaseV2 {

    bool lock = false;
    address public owner;
    address payable[] public players;
    uint public lotteryId;
    mapping(uint=>address payable) public lotteryHistory;

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    bytes32 keyHash =
        0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint32 callbackGasLimit = 100000;

    uint16 requestConfirmations = 3;
    uint32 numWords = 1;


    constructor( uint64 subscriptionId) VRFConsumerBaseV2(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D) {
        COORDINATOR = VRFCoordinatorV2Interface(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D);
        s_subscriptionId = subscriptionId;

        owner = msg.sender;
        lotteryId = 1;
    }


    modifier onlyOwner() {
        require(owner == msg.sender, "Only Owner can call this function");
        _;
    }

    function enter() public payable {
        require(msg.value > .01 ether, "Minimum amount is 0.01 ethers");

        players.push(payable(msg.sender));
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    function getPlayers() public view returns(address payable[] memory) {
        return players;
    }

    function getWinnerByLotter(uint _lotteryId) public view returns(address payable) {
        return lotteryHistory[_lotteryId];
    }


     function requestRandomWords() internal onlyOwner returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint256 _requestId) internal view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }


    function pickWinner() public onlyOwner{
        require(lock == false, "Concurrent not allowed");
        lock = true;

        uint256 requestId = requestRandomWords();
        (bool fulfilled, uint256[] memory randomWords) = getRequestStatus(requestId);
        require(fulfilled == true, "Try After Few Minutes");
        uint index = randomWords[0] % players.length;
        players[index].transfer(address(this).balance);

        lotteryHistory[lotteryId] = players[index];

        lotteryId++;

        // reset state of contract
        players = new address payable[](0);
        lock = false;
    }


}