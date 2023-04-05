// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DAO is ReentrancyGuard, AccessControl {
    bytes32 private immutable CONTRIBUTOR_ROLE=keccak256("CONTRIBUTOR");
    bytes32 private immutable STACKHOLDER_ROLE=keccak256("STACKHOLDER");

    uint256 immutable MIN_STACKHOLDER_CONTRIBUTION = 1 ether;
    uint32 immutable MIN_VOTE_DURATION = 3 minutes;

    uint32 totalProposal;
    uint256 public daoBalance;

    mapping(uint256 => ProposalStruct) private raisedProposals;
    mapping(address=>uint256[]) private stackholderVotes;
    mapping(uint256=> VotedStruct[]) private votedOn;
    mapping(address => uint256) private contributores;
    mapping(address => uint256) private stackholders;

    struct ProposalStruct {
        uint256 id;
        uint256 amount;
        uint256 duration;
        uint256 upvotes;
        uint256 downvotes;
        string title;
        string description;
        bool passed;
        bool paid;
        address payable beneficiary;
        address proposer;
        address executor;
    }

    struct VotedStruct{
        address voter;
        uint256 timestamp;
        bool chosen;
    }

    event Action(
        address indexed initiator,
        bytes32 role,
        string message,
        address beneficiary,
        uint256 amount
    );

    modifier stackholderOnly(string memory message){
        require(hasRole(STACKHOLDER_ROLE, msg.sender), message);
        _;
    }

    modifier contributorOnly(string memory message){
        require(hasRole(CONTRIBUTOR_ROLE, msg.sender), message);
        _;
    }

    function createProposal(
        string memory title,
        string memory description,
        address beneficiary,
        uint amount
    ) external stackholderOnly("proposal creation allowed for the stackholder only"){
        uint32 proposalID = totalProposal++;
        ProposalStruct storage proposal = raisedProposals[proposalID];
        proposal.id = proposalID;
        proposal.proposer = payable(msg.sender);
        proposal.title = title;
        proposal.description = description;
        proposal.beneficiary = payable(beneficiary);
        proposal.amount = amount;
        proposal.duration = block.timestamp + MIN_VOTE_DURATION;

        emit Action(
            msg.sender,
            STACKHOLDER_ROLE,
            "PROPOSAL RAISED",
            beneficiary,
            amount
        );

    }

    function handleVoting(ProposalStruct storage proposal) private {
        if(proposal.passed || proposal.duration <= block.timestamp) {
            proposal.passed = true;
            revert("Propsal Duration expired");
        }

        uint256[] memory tempVotes = stackholderVotes[msg.sender];

        for(uint256 votes = 0; votes < tempVotes.length; votes++) {
            if(proposal.id == tempVotes[votes]) {
                revert("Double voting not allwoed");
            }
        }   
     }

     function Vote(uint256 proposalID, bool chosen) external stackholderOnly("Unauthorised access: stackholder only access") returns(VotedStruct memory) {
         ProposalStruct storage proposal = raisedProposals[proposalID];
         handleVoting(proposal);

         if(chosen) {
            proposal.upvotes++;
         } else {
            proposal.downvotes++;
         }

         stackholderVotes[msg.sender].push(proposal.id);

         votedOn[proposal.id].push(
            VotedStruct(
                msg.sender,
                block.timestamp,
                chosen
            )
         );

         emit Action(
            msg.sender,
            STACKHOLDER_ROLE,
            "PROPOSAL VOTE",
            proposal.beneficiary,
            proposal.amount
        );

        return VotedStruct(
            msg.sender,
            block.timestamp,
            chosen
        );
     }

    function payTo(address to, uint amount) internal returns(bool){
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Payment Failed");
        return true; 
    }

    function payBeneficiary(uint proposalId) public stackholderOnly("Unauthorized: stackholder only") nonReentrant returns(uint){
        ProposalStruct storage proposal = raisedProposals[proposalId];
        require(daoBalance >= proposal.amount, "Insufficient fund");
        
        if(proposal.paid) revert("payment is already send");
        if(proposal.upvotes <= proposal.downvotes) {
            revert("Insufficient votes");
        }

        
        proposal.paid = true;
        proposal.executor = msg.sender;
        daoBalance -= proposal.amount;

        payTo(proposal.beneficiary, proposal.amount);

        emit Action(
            msg.sender,
            STACKHOLDER_ROLE,
            "PAYMENT TRANSFERD",
            proposal.beneficiary,
            proposal.amount
        );

        return daoBalance;

    }

    function contribute() public payable{
        require(msg.value > 0, "contribution should be more then zero");
        if(!hasRole(STACKHOLDER_ROLE, msg.sender)){
            uint256 totalContribution = contributores[msg.sender] + msg.value;

            if(totalContribution >= MIN_STACKHOLDER_CONTRIBUTION) {
                stackholders[msg.sender] = totalContribution;
                _grantRole(STACKHOLDER_ROLE, msg.sender);
            }

            contributores[msg.sender] += msg.value;
            _grantRole(CONTRIBUTOR_ROLE, msg.sender);
        } else {

            contributores[msg.sender] += msg.value;
            stackholders[msg.sender] += msg.value;
        }

        daoBalance += msg.value;

        emit Action(
            msg.sender,
            STACKHOLDER_ROLE,
            "CONTRIBUTION RECIEVED",
            address(this),
            msg.value
        );
    } 

    function getProposals() external view returns(ProposalStruct[] memory props) {
        props = new ProposalStruct[](totalProposal);
        for(uint256 i=0; i<totalProposal; i++) {
            props[i] = raisedProposals[i];
        }
    }

    function getProposal(uint256 proposalID) public view returns(ProposalStruct memory){
        return raisedProposals[proposalID];
    }

    function getVotesOf(uint256 proposalID) public view returns(VotedStruct[] memory){
        return votedOn[proposalID];
    }

    function getStackholderVotes() external view stackholderOnly("unauthorized: not a stackholder") returns(uint256[] memory) {
        return stackholderVotes[msg.sender];
    }

    function getStackholderBalance() external view stackholderOnly("unauthorized: not a stackholder") returns(uint256) {
        return stackholders[msg.sender];
    }

}


