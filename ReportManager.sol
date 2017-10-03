pragma solidity ^0.4.16;

import "github.com/Arachnid/solidity-stringutils/strings.sol";

contract ReportManager {
    using strings for *;
    
    struct Report {
        string ipfsHash;
        string title;
        string description;
        uint timestamp;
        string tags;
        uint likes;
        uint dislikes;
        uint8 countryId;
    }
    
    uint totalReportsCount;
    Report[] reports;

    function createReport(string ipfsHash, string title, string description, string tags, uint8 countryId) {
        reports.push(Report(ipfsHash, title, description, block.timestamp, tags, 0, 0, countryId));
        totalReportsCount++;
    }
    
    function getReportCount() constant returns (uint) {
        return reports.length;
    }
    
    function getReport(uint index) constant returns (string ipfsHash, string title, string description, string tags, uint likes, uint dislikes) {
        return (reports[index].ipfsHash, reports[index].title, reports[index].description, reports[index].tags, reports[index].likes, reports[index].dislikes);
    }
    
    function searchReport(string searchQuery) constant returns (uint[]) {
        uint[] searchResults;
        
        for (uint reportIndex = 0; reportIndex < totalReportsCount; reportIndex++) {
            if (reports[reportIndex].title.toSlice().contains(searchQuery.toSlice()) || 
                reports[reportIndex].description.toSlice().contains(searchQuery.toSlice())) {
                searchResults.push(reportIndex);    
            }
        }
        
        return searchResults;
    }
}