/** Author: Frank Larkin, DWS
* 
* This class contains the methods for the Opportunity Controller.
*/
public with sharing class OpportunityController {

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getOpportunities(String recordId) {
    List<ProcessInstanceWorkitem> workItems = [
      SELECT ProcessInstance.TargetObjectId 
      FROM ProcessInstanceWorkitem 
      WHERE Id = :recordId
      LIMIT 1
    ];
    
    if (workItems.isEmpty()) {
      return new Map<String, Object>{
        'lineItems' => new List<OpportunityLineItem>(),
        'targetObjectId' => null
      };
    }
    
    String targetObjectId = workItems[0].ProcessInstance.TargetObjectId;
    
    List<OpportunityLineItem> opportunityLineItems = [
      SELECT Id, Product2Id, Product2.Name, ProductCode, Quantity, Unit__c, UnitPrice, TotalPrice, Cost_Plus_Terms__c, Resource_Grouping__c, Product_Name__c
      FROM OpportunityLineItem 
      WHERE OpportunityId = :targetObjectId
    ];
    
    Map<String, Object> result = new Map<String, Object>();
    result.put('lineItems', opportunityLineItems);
    result.put('targetObjectId', targetObjectId);
    
    return result;
  }
    


}