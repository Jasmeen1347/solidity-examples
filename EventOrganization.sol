// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract EventContract {

    struct Event {
        address organizer;
        string name;
        uint date;
        uint price;
        uint ticketCount;
        uint ticketRemain;
    }

    mapping(uint => Event) public events;
    mapping(address=>mapping(uint=>uint)) public tickets;
    uint public nextId;

    function createEvent(string memory name, uint date, uint price, uint ticketCount) external {
        require(date>block.timestamp, "You can organize event for future date");
        require(ticketCount > 0, "You can organize event only if you create more then 0 tickets");
        
        events[nextId] = Event(msg.sender, name, date, price, ticketCount, ticketCount);
        nextId++;
    }

    function buyTicket(uint id, uint quantity) public payable {
        require(events[id].date != 0, "Event does not exist");
        require(block.timestamp < events[id].date, "Event has already occure");

        Event storage _event = events[id];
        require(msg.value == (_event.price*quantity), "Ether is not enough");
        require(_event.ticketRemain >= quantity, "not enough tickets");

        _event.ticketRemain -= quantity;
        tickets[msg.sender][id] += quantity;
    }

    function transferTickets(uint eventId, uint quantity, address to) public {
        require(events[eventId].date != 0, "Event does not exist");
        require(block.timestamp < events[eventId].date, "Event has already occure");
        require(tickets[msg.sender][eventId] >= quantity, "You do not have enough tickets");
        tickets[msg.sender][eventId] -= quantity;
        tickets[to][eventId] += quantity;
    }


}