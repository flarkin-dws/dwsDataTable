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

  @AuraEnabled(cacheable=true)
  public static List<OpportunityLineItem> getOpportunityLineItemsByOrder(String orderId) {
    if (String.isBlank(orderId)) {
      throw new AuraHandledException('Order ID cannot be blank.');
    }

    try {
      System.debug('getOpportunityLineItemsByOrder called with orderId: ' + orderId);
      
      // Query the Order to get the OpportunityId
      List<Order> orders = [
        SELECT Id, OpportunityId 
        FROM Order 
        WHERE Id = :orderId 
        LIMIT 1
      ];

      System.debug('Orders found: ' + orders.size());

      if (orders.isEmpty()) {
        throw new AuraHandledException('Order not found with ID: ' + orderId);
      }

      Order order = orders[0];
      System.debug('Order OpportunityId: ' + order.OpportunityId);
      
      if (order.OpportunityId == null) {
        System.debug('Order does not have an associated Opportunity, returning empty list');
        return new List<OpportunityLineItem>();
      }

      // Query OpportunityLineItems related to the Order's Opportunity
      List<OpportunityLineItem> lineItems = [
        SELECT
          Id,
          Product_Name__c,
          ProductCode,
          Quantity,
          UnitPrice,
          Cost_Plus_Terms__c,
          Unit__c,
          TotalPrice,
          Resource_Grouping__c
        FROM OpportunityLineItem
        WHERE OpportunityId = :order.OpportunityId
        ORDER BY TotalPrice DESC
      ];

      System.debug('Number of OpportunityLineItems found: ' + lineItems.size());
      System.debug('OpportunityLineItems retrieved: ' + lineItems);
      
      return lineItems;
    } catch (Exception e) {
      System.debug('Error occurred in getOpportunityLineItemsByOrder: ' + e.getMessage());
      System.debug('Stack trace: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Error retrieving opportunity line items: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getOpportunityLineItemsByOrderWithDetails(String orderId) {
    Map<String, Object> result = new Map<String, Object>();
    
    if (String.isBlank(orderId)) {
      throw new AuraHandledException('Order ID cannot be blank.');
    }

    try {
      System.debug('getOpportunityLineItemsByOrderWithDetails called with orderId: ' + orderId);
      
      // Query the Order to get the OpportunityId
      List<Order> orders = [
        SELECT Id, OpportunityId, Opportunity.Name, Opportunity.Account.Name
        FROM Order 
        WHERE Id = :orderId 
        LIMIT 1
      ];

      System.debug('Orders found: ' + orders.size());

      if (orders.isEmpty()) {
        result.put('lineItems', new List<OpportunityLineItem>());
        result.put('hasOpportunity', false);
        result.put('message', 'Order not found');
        return result;
      }

      Order order = orders[0];
      System.debug('Order OpportunityId: ' + order.OpportunityId);
      
      if (order.OpportunityId == null) {
        System.debug('Order does not have an associated Opportunity');
        result.put('lineItems', new List<OpportunityLineItem>());
        result.put('hasOpportunity', false);
        result.put('message', 'Order does not have an associated Opportunity');
        return result;
      }

      // Query OpportunityLineItems related to the Order's Opportunity
      List<OpportunityLineItem> lineItems = [
        SELECT
          Id,
          Product_Name__c,
          ProductCode,
          Quantity,
          UnitPrice,
          Cost_Plus_Terms__c,
          Unit__c,
          TotalPrice,
          Resource_Grouping__c
        FROM OpportunityLineItem
        WHERE OpportunityId = :order.OpportunityId
        ORDER BY TotalPrice DESC
      ];

      System.debug('Number of OpportunityLineItems found: ' + lineItems.size());
      
      result.put('lineItems', lineItems);
      result.put('hasOpportunity', true);
      result.put('opportunityId', order.OpportunityId);
      result.put('opportunityName', order.Opportunity?.Name);
      result.put('accountName', order.Opportunity?.Account?.Name);
      
      return result;
    } catch (Exception e) {
      System.debug('Error occurred in getOpportunityLineItemsByOrderWithDetails: ' + e.getMessage());
      System.debug('Stack trace: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Error retrieving opportunity line items: ' + e.getMessage()
      );
    }
  }
}