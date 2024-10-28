// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract RealEstateInvestmentPool {
    enum PoolState { Active, Closed }
    
    struct Investor {
        uint256 contribution;
        uint256 ownershipPercentage;
        bool exists;
        uint256 lastDividendsClaimed;
    }
    
    address public immutable manager;
    mapping(address => Investor) public investors;
    address[] public investorAddresses;
    uint256 public totalContributions;
    uint256 public totalDividends;
    PoolState public state;
    bool private locked;
    
    uint256 public constant MIN_INVESTMENT = 0.01 ether;
    
    event ContributionReceived(address indexed investor, uint256 amount);
    event DividendDistributed(address indexed investor, uint256 amount);
    event DividendsAdded(uint256 amount);
    event PoolClosed();
    
 
    modifier noReentrant() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }
    
    modifier onlyManager() {
        require(msg.sender == manager, "Only manager allowed");
        _;
    }
    
    modifier onlyActive() {
        require(state == PoolState.Active, "Pool not active");
        _;
    }
    
    constructor() {
        manager = msg.sender;
        state = PoolState.Active;
    }
    
    function contribute() external payable onlyActive noReentrant {
        require(msg.value >= MIN_INVESTMENT, "Contribution below minimum");
        
        if (!investors[msg.sender].exists) {
            investors[msg.sender] = Investor({
                contribution: 0,
                ownershipPercentage: 0,
                exists: true,
                lastDividendsClaimed: block.timestamp
            });
            investorAddresses.push(msg.sender);
        }
        
        investors[msg.sender].contribution += msg.value;
        totalContributions += msg.value;
        
      
        updateOwnershipPercentages();
        
        emit ContributionReceived(msg.sender, msg.value);
    }
    
    function updateOwnershipPercentages() internal {
        for (uint i = 0; i < investorAddresses.length; i++) {
            address investor = investorAddresses[i];
            investors[investor].ownershipPercentage = 
                (investors[investor].contribution * 100) / totalContributions;
        }
    }
    
    function distributeDividends() external onlyManager onlyActive noReentrant {
        require(totalDividends > 0, "No dividends to distribute");
        require(address(this).balance >= totalDividends, "Insufficient balance");
        
        uint256 remainingDividends = totalDividends;
        
        for (uint256 i = 0; i < investorAddresses.length; i++) {
            address investor = investorAddresses[i];
            uint256 dividend = (investors[investor].ownershipPercentage * totalDividends) / 100;
            
            if (dividend > 0 && dividend <= remainingDividends) {
                remainingDividends -= dividend;
                investors[investor].lastDividendsClaimed = block.timestamp;
                (bool success, ) = payable(investor).call{value: dividend}("");
                require(success, "Transfer failed");
                emit DividendDistributed(investor, dividend);
            }
        }
        
        totalDividends = remainingDividends;
    }
    
    function addDividends() external payable onlyManager onlyActive {
        require(msg.value > 0, "Amount must be positive");
        totalDividends += msg.value;
        emit DividendsAdded(msg.value);
    }
    
    function closePool() external onlyManager {
        require(totalDividends == 0, "Distribute dividends before closing");
        state = PoolState.Closed;
        emit PoolClosed();
    }
    
    function getInvestorInfo(address investor) external view returns (
        uint256 contribution,
        uint256 ownershipPercentage,
        uint256 lastDividendsClaimed
    ) {
        require(investors[investor].exists, "Investor not found");
        Investor memory inv = investors[investor];
        return (inv.contribution, inv.ownershipPercentage, inv.lastDividendsClaimed);
    }
    
    function getPoolMetrics() external view returns (
        uint256 _totalContributions,
        uint256 _totalDividends,
        uint256 _totalInvestors,
        PoolState _state
    ) {
        return (
            totalContributions,
            totalDividends,
            investorAddresses.length,
            state
        );
    }
    
    function getInvestorAddresses() external view returns (address[] memory) {
        return investorAddresses;
    }
    
  
    
   
    receive() external payable {
        require(msg.sender == manager, "Only manager can send ETH directly");
    }
}