public with sharing class OpportunityController {
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getOpportunities(
    String recordId,
    String objectName
  ) {
    Map<String, Object> result = new Map<String, Object>();
    
    if (String.isBlank(recordId) || String.isBlank(objectName)) {
      throw new AuraHandledException('Invalid input: Id and objectName cannot be blank.');
    }

    try {
      // Dynamically construct the query
      String query =
        'SELECT Id, ProcessInstance.TargetObjectId FROM ' +
        objectName +
        ' WHERE Id = :recordId LIMIT 1';
      SObject record = Database.query(query);

      // System.debug('Record: ' + record);
      // System.debug('Checking SObject type: ' + record.getSObjectType());

      String targetObjectId;
      if (objectName == 'ProcessInstanceStep') {
        // casting to ProcessInstanceStep to allow compilation
        ProcessInstanceStep step = (ProcessInstanceStep) record;
        if (
          step.ProcessInstance == null ||
          step.ProcessInstance.TargetObjectId == null
        ) {
          throw new AuraHandledException(
            'The ProcessInstance or TargetObjectId is null.'
          );
        }
        targetObjectId = step.ProcessInstance.TargetObjectId;
      } else if (objectName == 'ProcessInstanceWorkitem') {
        // casting to ProcessInstanceWorkitem to allow compilation
        ProcessInstanceWorkitem workItem = (ProcessInstanceWorkitem) record;
        if (
          workItem.ProcessInstance == null ||
          workItem.ProcessInstance.TargetObjectId == null
        ) {
          throw new AuraHandledException(
            'The ProcessInstance or TargetObjectId is null.'
          );
        }
        targetObjectId = workItem.ProcessInstance.TargetObjectId;
      } else {
        throw new AuraHandledException('Unexpected object type.');
      }

      // System.debug('TargetObjectId: ' + targetObjectId);
      result.put('targetObjectId', targetObjectId);

      // Query OpportunityLineItems based on the TargetObjectId
      List<OpportunityLineItem> lineItems = [
        SELECT
          Product_Name__c,
          ProductCode,
          Quantity,
          UnitPrice,
          Cost_Plus_Terms__c,
          Unit__c,
          TotalPrice,
          Resource_Grouping__c
        FROM OpportunityLineItem
        WHERE OpportunityId = :targetObjectId
        ORDER BY TotalPrice DESC
      ];

      System.debug('Number of OpportunityLineItems: ' + lineItems.size());
      System.debug('OpportunityLineItems retrieved: ' + lineItems);
      result.put('lineItems', lineItems);
    } catch (Exception e) {
      System.debug('Error occurred: ' + e.getMessage());
      System.debug('Stack trace: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Error retrieving opportunity data: ' + e.getMessage()
      );
    }

    // System.debug('Result: ' + result);
    for (String key : result.keySet()) {
      System.debug('Key: ' + key + ', Value: ' + result.get(key));
    }

    // System.debug('Result keys: ' + result.keySet());
    return result;
  }
}