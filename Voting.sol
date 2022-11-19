// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Voting {

    address owner;

    struct Participants {
        address participant;
        string name;
        uint voteCount;
    }

    mapping(uint => Participants) public participants; // people who stand in election 
    address[] public voter;
    address[] private listOfParticipants;
    uint private nextId;
    bool private isElectionStarted = false;
    bool private isElectionIsEnd = false;

    constructor() {
        owner = msg.sender;
    }

    modifier IsAlreayAdded() {
        bool isContain = false;
        for (uint i = 0; i < listOfParticipants.length; i++) {
            if(listOfParticipants[i] == msg.sender){
                isContain = true;
            }
        }
        require(!isContain, "You already added to election");
        _;
    }

    function endElection() public {
        isElectionIsEnd = true;
    }

    function startElection() public {
            isElectionStarted = true;
    }

    modifier checkIfElectionIsStarted() {
        require(!isElectionStarted, "Election is started so no more accepting participants");
        _;
    }

    modifier checkIfElectionIsEnd() {
        require(!isElectionIsEnd, "Election is ended");
        _;
    }

    function addParticipant(string memory _name) public checkIfElectionIsEnd checkIfElectionIsStarted IsAlreayAdded{
        require(msg.sender != owner, "Owner can not become participant");
        participants[nextId] = Participants(msg.sender, _name, 0);
        listOfParticipants.push(msg.sender);
        nextId++;
    }

    modifier IsAlreayVoted() {
        bool isContain = false;
        for (uint i = 0; i < voter.length; i++) {
            if(voter[i] == msg.sender){
                isContain = true;
            }
        }
        require(!isContain, "You already voted");
        _;
    }


    function voteSomeOne(uint _id) public IsAlreayVoted checkIfElectionIsEnd{
        require(isElectionStarted, "Election is not started yet");
        participants[_id].voteCount += 1;
        voter.push(msg.sender);
    }

    function getResult(uint _id) public view returns(address, string memory, uint){
        return (participants[_id].participant, participants[_id].name, participants[_id].voteCount);
    }

    function pickTheWinner() public view returns(address, string memory, uint){
        uint256 largest = 0;
        uint256 winnerid;
        uint256 i;

        for(i = 0; i < nextId; i++){
            if(participants[i].voteCount > largest) {
                largest = participants[i].voteCount;
                winnerid = i;
            } 
        }
        return (participants[winnerid].participant, participants[winnerid].name, participants[winnerid].voteCount);
    }

}